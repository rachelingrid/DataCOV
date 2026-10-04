# Converte a resposta de /api/v3/agregados/{tabela}/periodos/.../variaveis/...
# (com classificacoes de sexo e idade) em CSV: cod_local,ano,sexo,idade,valor
.[0].resultados[]
| ([.classificacoes[] | select(.nome | test("sexo"; "i")) | .categoria | to_entries[0].value][0] // "Total") as $sexo
| ([.classificacoes[] | select(.nome | test("idade"; "i")) | .categoria | to_entries[0].value][0] // "Total") as $idade
| .series[]
| .localidade.id as $loc
| .serie | to_entries[]
| [$loc, .key, $sexo, $idade, .value]
| @csv
