#!/usr/bin/env bash
# coleta_populacao.sh
# Baixa da API SIDRA/IBGE a populacao residente do Brasil e das UFs:
#   tabela 6579 - estimativas anuais da populacao (variavel 9324)
#   tabela 4709 - Censo 2022, populacao residente (variavel 93)
# e monta dados/populacao_uf.csv (uf, ano, populacao, origem) com Octave.
# Depois, a populacao por sexo e idade (tabela 7358, projecao) -> dados/populacao_sexo_faixa.csv.
# Anos sem estimativa publicada sao interpolados/extrapolados (ver monta_populacao.m).
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
SIDRA="${SIDRA_API:-https://apisidra.ibge.gov.br/values}"
DIR="$RAIZ/dados/populacao"
mkdir -p "$DIR"

baixa() {
  local url="$1" saida="$2" tmp="$2.tmp"
  if curl -sS --fail --retry 5 --retry-delay 15 --retry-all-errors --max-time 300 -o "$tmp" "$url" \
     && head -c 1 "$tmp" | grep -q '\['; then
    mv "$tmp" "$saida"; echo "ok: $(basename "$saida")"
  else
    rm -f "$tmp"; echo "AVISO: falha ao baixar $url (mantido arquivo anterior, se houver)" >&2
  fi
}

baixa "$SIDRA/t/6579/n1/all/n3/all/v/9324/p/all" "$DIR/sidra_6579.json"
baixa "$SIDRA/t/4709/n1/all/n3/all/v/93/p/all"   "$DIR/sidra_4709.json"

octave-cli -q --no-window-system --path "$RAIZ/octave" --path "$RAIZ/config" --eval "monta_populacao('$RAIZ')"

# ---------------------------------------------------------------------------
# Populacao por SEXO e IDADE (denominador das taxas por faixa etaria)
# Projecao da populacao IBGE (revisao 2024), por idade simples, Brasil e UFs.
# Usa a API v3 de agregados; os codigos da variavel e das classificacoes sao
# lidos dos metadados da tabela, para nao depender de numeros fixos.
TAB="${TABELA_POP_IDADE:-7358}"
API="${IBGE_API:-https://servicodados.ibge.gov.br/api/v3/agregados}"
META="$DIR/meta_$TAB.json"
CSV="$DIR/pop_sexo_idade.csv"
if curl -sS --fail --retry 5 --retry-delay 15 --retry-all-errors --max-time 120 -o "$META.tmp" "$API/$TAB/metadados"; then
  mv "$META.tmp" "$META"
  VAR=$(jq -r '([.variaveis[] | select(.nome | test("popula"; "i"))][0] // .variaveis[0]).id' "$META")
  CSEXO=$(jq -r '[.classificacoes[] | select(.nome | test("^sexo$"; "i"))][0].id // empty' "$META")
  CIDADE=$(jq -r '([.classificacoes[] | select(.nome | test("^idade$"; "i"))][0] // [.classificacoes[] | select(.nome | test("idade"; "i"))][0]).id // empty' "$META")
  echo "Tabela $TAB: variavel $VAR, sexo c$CSEXO, idade c$CIDADE"
  if [ -n "$CSEXO" ] && [ -n "$CIDADE" ]; then
    echo "cod_local,ano,sexo,idade,populacao" > "$CSV.tmp"
    OKANOS=0
    for ANO in $(octave-cli -q --path "$RAIZ/config" --eval "printf('%d ', periodos().anos)"); do
      URL="$API/$TAB/periodos/$ANO/variaveis/$VAR?localidades=N1%5Ball%5D%7CN3%5Ball%5D&classificacao=$CSEXO%5Ball%5D%7C$CIDADE%5Ball%5D"
      if curl -sS --fail --retry 5 --retry-delay 15 --retry-all-errors --max-time 300 -o "$DIR/v3_$ANO.json" "$URL" \
         && jq -r -f "$RAIZ/scripts/sidra_v3_csv.jq" "$DIR/v3_$ANO.json" >> "$CSV.tmp"; then
        OKANOS=$((OKANOS+1))
      else
        echo "AVISO: populacao por idade de $ANO nao baixada" >&2
      fi
      rm -f "$DIR/v3_$ANO.json"
    done
    [ "$OKANOS" -gt 0 ] && mv "$CSV.tmp" "$CSV" || rm -f "$CSV.tmp"
  else
    echo "AVISO: tabela $TAB sem classificacoes de sexo/idade reconhecidas" >&2
  fi
else
  rm -f "$META.tmp"; echo "AVISO: metadados da tabela $TAB indisponiveis" >&2
fi
octave-cli -q --no-window-system --path "$RAIZ/octave" --path "$RAIZ/config" --eval "monta_populacao_faixa('$RAIZ')"
