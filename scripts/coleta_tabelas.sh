#!/usr/bin/env bash
# coleta_tabelas.sh - nomes dos codigos para a busca do site (opcional).
#   CID-10: tabela CID10.DBF do SIM no FTP do DATASUS
#   SIGTAP: tb_procedimento.txt do pacote mensal da Tabela Unificada
# Se algo falhar o site continua funcionando, so sem as descricoes.
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
FTP="${DATASUS_FTP:-ftp://ftp.datasus.gov.br/dissemin/publicos}"
SIGTAP="${SIGTAP_FTP:-ftp://ftp2.datasus.gov.br/pub/sistemas/tup/downloads}"
DIR="$RAIZ/dados/tabelas"; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$DIR"
c() { curl -sS --fail --retry 4 --retry-delay 15 --retry-all-errors --max-time 600 "$@"; }

ARQ=$(c --list-only "$FTP/SIM/CID10/TABELAS/" 2>/dev/null | tr -d '\r' | grep -iE '^CID10\.DBF$' | head -1)
if [ -n "$ARQ" ] && c -o "$TMP/cid.dbf" "$FTP/SIM/CID10/TABELAS/$ARQ"; then
  mv "$TMP/cid.dbf" "$DIR/CID10.DBF"; echo "ok: CID10.DBF"
else
  echo "AVISO: tabela CID10 nao baixada" >&2
fi

ZIP=$(c --list-only "$SIGTAP/" 2>/dev/null | tr -d '\r' | grep -iE '^TabelaUnificada_[0-9]{6}.*\.zip$' | sort | tail -1)
if [ -n "$ZIP" ] && c -o "$TMP/s.zip" "$SIGTAP/$ZIP" && unzip -o -q -j "$TMP/s.zip" 'tb_procedimento.txt' -d "$TMP"; then
  mv "$TMP/tb_procedimento.txt" "$DIR/tb_procedimento.txt"; echo "ok: SIGTAP $ZIP"
else
  echo "AVISO: tabela SIGTAP nao baixada" >&2
fi
exit 0
