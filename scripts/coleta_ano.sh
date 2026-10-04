#!/usr/bin/env bash
# coleta_ano.sh ANO [FONTES]
# Baixa do FTP do DATASUS os microdados de um ano, descompacta e agrega em
# dados/partes/ANO_FONTE.csv (um arquivo por base, para rodar bases separadas). FONTES (opcional): "SIM DOFET SIH SINASC" (padrao: todas).
# Requer: curl, octave-cli, tools/blast-dbf/blast-dbf compilado.
set -uo pipefail

ANO="${1:?informe o ano}"
FONTES="${2:-SIM DOFET SIH SINASC}"
AA="${ANO:2:2}"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
FTP="${DATASUS_FTP:-ftp://ftp.datasus.gov.br/dissemin/publicos}"
BLAST="${BLAST:-$RAIZ/tools/blast-dbf/blast-dbf}"
TMP="$(mktemp -d)"
UFS="AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$RAIZ/dados/partes" "$RAIZ/dados/cubo"
FALHOU=0

curl_ftp() { curl -sS --fail --retry 6 --retry-delay 20 --retry-all-errors \
                  --connect-timeout 60 --max-time 1800 "$@"; }

# Lista uma pasta do FTP (com cache local)
lista() {
  local pasta="$1" cache="$TMP/lista_$(echo "$1" | tr '/' '_')"
  if [ ! -f "$cache" ]; then
    curl_ftp --list-only "$FTP/$pasta/" > "$cache" 2>/dev/null || : > "$cache"
    [ -s "$cache" ] || echo "AVISO: nao consegui listar $FTP/$pasta/ (pasta inexistente ou FTP fora do ar)" >&2
  fi
  cat "$cache"
}

# processa FONTE PASTA ARQUIVO PRELIM
processa() {
  local fonte="$1" pasta="$2" arq="$3" prelim="$4"
  local dbc="$TMP/$arq" dbf="$TMP/${arq%.*}.dbf"
  if ! curl_ftp -o "$dbc" "$FTP/$pasta/$arq"; then
    echo "$fonte,$arq,$pasta,$prelim,erro_download,0" >> "$LOG"; return
  fi
  if ! "$BLAST" "$dbc" "$dbf"; then
    echo "$fonte,$arq,$pasta,$prelim,erro_descompactar,0" >> "$LOG"; rm -f "$dbc"; return
  fi
  rm -f "$dbc"
  local n
  n=$(octave-cli -q --no-window-system --path "$RAIZ/octave" --path "$RAIZ/config" \
        --eval "printf('%d', processa_arquivo('$fonte','$dbf','$SAIDA',$ANO,$prelim,'$CUBO'))" 2>"$TMP/err.txt" | tail -c 20)
  if [ -z "$n" ]; then
    echo "$fonte,$arq,$pasta,$prelim,erro_octave,0" >> "$LOG"; cat "$TMP/err.txt" >&2
  else
    echo "$fonte,$arq,$pasta,$prelim,ok,$n" >> "$LOG"
  fi
  rm -f "$dbf"
  echo "  $fonte $arq -> $n registros"
}

compacta() {
  [ -f "$1" ] && octave-cli -q --no-window-system --path "$RAIZ/octave" --eval "compacta_cubo('$1')"
}

# Procura ARQ (regex, sem diferenciar maiusculas) nas pastas, na ordem dada.
# A primeira pasta e a definitiva; as seguintes sao preliminares.
procura() {
  local regex="$1"; shift
  local i=0 pasta achou
  for pasta in "$@"; do
    achou=$(lista "$pasta" | tr -d '\r' | grep -iE "^${regex}$" || true)
    if [ -n "$achou" ]; then
      echo "$achou" | while read -r a; do echo "$pasta|$a|$([ $i -gt 0 ] && echo 1 || echo 0)"; done
      return
    fi
    i=$((i+1))
  done
}

for FONTE in $FONTES; do
  FINAL="$RAIZ/dados/partes/${ANO}_${FONTE}.csv"
  SAIDA="$TMP/${ANO}_${FONTE}.csv"
  LOG="$RAIZ/dados/partes/${ANO}_${FONTE}_log.csv"
  CUBO="$TMP/${ANO}_${FONTE}_cubo.csv"          # todos os CIDs/procedimentos (SIM e SIH)
  CUBO_FINAL="$RAIZ/dados/cubo/${ANO}_${FONTE}_cubo.csv"
  rm -f "$CUBO"
  echo "fonte,arquivo,pasta,preliminar,status,registros" > "$LOG"
  case "$FONTE" in
    SIM)
      echo "== SIM obitos $ANO"
      for UF in $UFS; do
        r=$(procura "DO${UF}${ANO}\.dbc" SIM/CID10/DORES SIM/PRELIM/DORES)
        if [ -z "$r" ]; then echo "SIM,DO${UF}${ANO}.dbc,,,nao_encontrado,0" >> "$LOG"; continue; fi
        IFS='|' read -r pasta arq prelim <<< "$r"
        processa SIM "$pasta" "$arq" "$prelim"
      done ;;
    DOFET)
      echo "== SIM obitos fetais $ANO"
      r=$(procura "DOFET([A-Z]{2})?(${ANO}|${AA})\.dbc" SIM/CID10/DOFET SIM/PRELIM/DOFET)
      if [ -z "$r" ]; then echo "DOFET,DOFET${AA}.dbc,,,nao_encontrado,0" >> "$LOG"; fi
      while IFS='|' read -r pasta arq prelim; do
        [ -n "$arq" ] && processa DOFET "$pasta" "$arq" "$prelim"
      done <<< "$r" ;;
    SINASC)
      echo "== SINASC nascidos vivos $ANO"
      for UF in $UFS; do
        r=$(procura "DN${UF}${ANO}\.dbc" SINASC/NOV/DNRES SINASC/PRELIM/DNRES)
        if [ -z "$r" ]; then echo "SINASC,DN${UF}${ANO}.dbc,,,nao_encontrado,0" >> "$LOG"; continue; fi
        IFS='|' read -r pasta arq prelim <<< "$r"
        processa SINASC "$pasta" "$arq" "$prelim"
      done ;;
    SIH)
      echo "== SIH internacoes $ANO"
      for MM in 01 02 03 04 05 06 07 08 09 10 11 12; do
        for UF in $UFS; do
          r=$(procura "RD${UF}${AA}${MM}\.dbc" SIHSUS/200801_/Dados)
          if [ -z "$r" ]; then echo "SIH,RD${UF}${AA}${MM}.dbc,,,nao_encontrado,0" >> "$LOG"; continue; fi
          IFS='|' read -r pasta arq prelim <<< "$r"
          processa SIH "$pasta" "$arq" 0
        done
        compacta "$CUBO"                         # soma as 27 UFs do mes
      done ;;
    *) echo "Fonte desconhecida: $FONTE" >&2; FALHOU=1; continue ;;
  esac
  OK=$(grep -c ",ok," "$LOG" || true)
  ERROS=$(grep -c ",erro_" "$LOG" || true)
  echo "-- $FONTE $ANO: $OK arquivo(s) processado(s), $ERROS erro(s)"
  if [ "$OK" -gt 0 ] && [ -f "$SAIDA" ]; then
    mv "$SAIDA" "$FINAL"
    if [ -f "$CUBO" ]; then compacta "$CUBO"; mv "$CUBO" "$CUBO_FINAL"; fi
  else
    echo "   nada processado; dados anteriores de $FONTE $ANO mantidos" >&2
  fi
  [ "$ERROS" -gt 0 ] && FALHOU=1
done

# Erros parciais: o que deu certo foi gravado, mas o job falha para avisar
[ "$FALHOU" -gt 0 ] && { echo "ATENCAO: houve erros - veja dados/partes/${ANO}_*_log.csv" >&2; exit 1; }
exit 0
