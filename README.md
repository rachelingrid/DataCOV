# andesedepoisCOV19

**Internações e óbitos no SUS antes e depois da COVID-19, por CID-10 ou procedimento, faixa etária e sexo.**

Este repositório baixa os microdados públicos do DATASUS, os mesmos que alimentam o Tabnet. Com eles, compara as taxas de 2015–2019 com as de 2021 em diante, excluindo 2020. A coleta e o processamento rodam no próprio GitHub, e o resultado é um site estático que funciona também offline.

🔗 **Site:** https://rachelingrid.github.io/andesedepoisCOV19/

---

## O que o site responde

> *Na mesma faixa etária e no mesmo sexo, a taxa de internação (ou de óbito) por uma doença mudou depois da pandemia?*

Você escolhe:

| | Opções |
|---|---|
| **Base** | Internações (SIH/SUS) ou óbitos (SIM) |
| **Critério** | SIH: diagnóstico principal, qualquer diagnóstico da internação ou procedimento realizado (SIGTAP). SIM: causa básica ou qualquer menção no atestado |
| **Contagem** (SIH) | Internações ou óbitos durante a internação |
| **Códigos** | Qualquer CID-10 ou procedimento, digitado ou buscado pelo nome. Prefixos incluem os subcódigos (`I26` = I26.0 + I26.9). Há atalhos prontos: TVP, embolia pulmonar, TVP + embolia, trombose, embolia, amputações |

Ao clicar em **Gerar comparação**, o site mostra:

- **casos ano a ano, antes e depois**, em uma linha por faixa etária (20–29 a 80–89; opcionalmente 0–19 e 90+), com **homens e mulheres** lado a lado;
- **taxa por milhão de habitantes** do mesmo sexo e faixa;
- **razão de taxas** (depois ÷ antes) com intervalo de confiança de 95% e p corrigido para múltiplas comparações;
- **salto em 2021 descontando a tendência** que já existia antes da pandemia;
- **tabela completa**, com download em CSV.

O endereço da página guarda a seleção, então copiar o link reabre a mesma comparação.

---

## Como colocar no ar

1. **Publicar o site:** em *Settings → Pages*, escolha *Branch: `main`* e a pasta `/docs`.
2. **Primeira coleta:** na aba *Actions*, abra **Atualizar dados DATASUS**, clique em **Run workflow** e deixe `anos = todos`.
   - Os anos são processados em paralelo, até 4 por vez.
   - O SIH é o mais pesado (27 UFs × 12 meses por ano), então a primeira carga leva algumas horas.
   - Se um ano falhar (FTP do DATASUS fora do ar, por exemplo), rode de novo só aquele ano: `anos = 2017`.
3. **Atualização automática:** todo dia 5, o workflow reprocessa os três anos mais recentes, que o DATASUS ainda revisa.

**Uso offline:** clone o repositório e abra `docs/index.html` com dois cliques. Não precisa de servidor nem de internet.

> No plano gratuito do GitHub, o GitHub Pages só publica repositórios **públicos**. Os dados usados aqui já são públicos.

---

## Método

### Períodos: comparação simétrica

- **2020 fica de fora** das médias e dos testes. Ele aparece nos gráficos em cinza, como referência.
- **Depois** = anos completos a partir de 2021. **Antes** = o mesmo número de anos imediatamente anteriores a 2020.
- Hoje a comparação é **2015–2019 × 2021–2025** (5 × 5). Quando 2026 estiver completo, ela passa sozinha a **2014–2019 × 2021–2026** (6 × 6).
- Anos incompletos (o ano corrente no SIH) aparecem nos gráficos, mas ficam fora das médias e dos testes.

A regra está em `config/periodos.m` (`P.simetrico`) e em `octave/janela_simetrica.m`.

### Taxas

- **Taxa por milhão** = casos ÷ população residente do mesmo sexo e faixa etária × 1.000.000.
- **População por sexo e idade:** projeção da população do IBGE, revisão 2024 (tabela SIDRA 7358), somada por faixa etária.
- **População total:** estimativas anuais do IBGE (tabela 6579) e Censo 2022 (tabela 4709).
- **Gestantes:** taxa por 100 mil nascidos vivos (SINASC), na mesma base da razão de mortalidade materna.
- **Natimortos:** taxa por mil nascimentos.

### Testes estatísticos

Para cada estrato de sexo × faixa etária, são feitos dois testes, ambos com **regressão de Poisson** sobre a contagem anual e a população como exposição. Os dois têm **correção para sobredispersão** (quasi-Poisson; o erro-padrão nunca fica abaixo do esperado pela Poisson).

| Teste | Pergunta | Anos usados |
|---|---|---|
| **Depois × antes** | A taxa média depois é diferente da taxa média antes? → razão de taxas (RR), IC 95%, p | janela simétrica |
| **Série interrompida** | Houve um salto em 2021 **acima da tendência** de antes da pandemia? → RR do salto, tendência pré (%/ano) | todos os anos completos desde 2014 |

- O p é corrigido por **Holm-Bonferroni** entre todos os estratos exibidos (por exemplo, 7 faixas × 2 sexos = 14 testes).
- A comparação depois × antes diz **se** a taxa mudou. Só a série interrompida separa o efeito do período pós-pandemia de um aumento que já vinha acontecendo (por exemplo, por envelhecimento da população, maior acesso a diagnóstico ou mudanças de codificação).
- **Validação:** a regressão é implementada em Octave (`octave/glm_poisson.m`) e em JavaScript (`docs/estat.js`). As duas foram conferidas entre si e contra o `statsmodels` (Python), e os coeficientes coincidem até a 6ª casa decimal. Os testes automáticos rodam a cada alteração do código.

---

## Atalhos e definições

| Atalho | Códigos |
|---|---|
| TVP | I80.1, I80.2, I80.3, I82.2, O22.3, O87.1 |
| Embolia pulmonar | I26 |
| TVP + embolia pulmonar | os dois acima |
| Trombose (todas) | I80, I81, I82, I67.6, I74, O22.3, O22.5, O87.1, O87.3 |
| Embolia (qualquer) | I26, I74, O88, T79.0, T80.0, T81.7 |
| Amputação de membros inferiores | SIGTAP 04.08.05.001-2, 04.08.05.002-0 |
| Amputação (todas) | acima + 04.08.02.001-6, 04.08.02.002-4, 04.08.06.004-2 |

A TVP exclui I80.0 (trombose superficial) e I80.9 (local não especificado). Os grupos fixos do estudo (trombose, embolia, gestantes, natimortos por trimestre, amputação por causa, TVP sem COVID-19) estão em `config/grupos_cid.m`.

---

## Páginas

| Página | Conteúdo |
|---|---|
| `docs/index.html` | **Antes e depois**: qualquer CID ou procedimento, por faixa e sexo |
| `docs/faixas.html` | Grupos do estudo (TVP, TEV, embolia, amputação) por sexo e faixa, com gráfico de razões de taxa |
| `docs/painel.html` | Painel dos grupos do estudo por UF, incluindo gestantes e natimortos |

## Arquivos de dados (`dados/`)

| Arquivo | Conteúdo |
|---|---|
| `cubo/AAAA_FONTE_cubo.csv` | Contagem de **todos** os CIDs e procedimentos por ano × sexo × faixa (base do site) |
| `anual.csv` | Grupos do estudo × UF (inclui `BR`) × ano, em contagens e taxas |
| `detalhado.csv` | Idem, aberto por sexo e faixa etária |
| `comparacao_pre_pos.csv` | Médias antes e depois, valor de 2020, razão e variação % |
| `faixas_anual.csv`, `faixas_teste.csv`, `faixas_ano_vs_pre.csv` | Taxas e testes por sexo × faixa para os grupos do estudo |
| `populacao_uf.csv`, `populacao_sexo_faixa.csv` | Denominadores, com a origem de cada valor |
| `partes/*_log.csv` | Registro de cada arquivo baixado do DATASUS (status e número de registros) |

---

## Limitações

- **Por que não há consulta direta ao Tabnet:** o Tabnet é um formulário do DATASUS que não aceita consultas vindas de outros sites. Por isso, o repositório baixa os **mesmos microdados** do FTP do DATASUS e faz a contagem por conta própria.
- **SIH conta internações, não pessoas.** Reinternações e transferências entram mais de uma vez. A contagem é feita pelo ano de processamento (competência) e cobre apenas a rede SUS.
- **"Qualquer diagnóstico" e "qualquer menção":** um registro com dois dos códigos escolhidos é contado duas vezes. No diagnóstico principal e na causa básica, a contagem é exata.
- **Óbitos hospitalares (SIH)** não são o total de óbitos pela doença. Para isso, use o SIM.
- **Mudanças de prática clínica** alteram internações sem alterar a incidência. A TVP, por exemplo, é cada vez mais tratada em casa com anticoagulante oral.
- **Anos recentes:** o SIM dos últimos anos pode ser preliminar, e o ano corrente do SIH está incompleto.
- **População 2023–2026:** usa projeção do IBGE, não contagem.
- **Gestação:** o SIM e o SIH não registram a idade gestacional da mãe. O trimestre só é medido nos natimortos.
- **Escopo geográfico:** o site mostra o Brasil como um todo. Os arquivos `anual.csv` e `painel.html` trazem os grupos do estudo por UF.

---

## Estrutura

```
.github/workflows/   atualizar-dados.yml (coleta mensal), testes.yml
scripts/             coleta no FTP do DATASUS, população IBGE, tabelas de nomes
octave/              leitura dos DBF, classificação, cubo, taxas e testes (Octave puro)
config/              períodos, grupos de CID/procedimentos, estratos
docs/                site estático (GitHub Pages / offline)
dados/               resultados gerados pelo workflow
tests/               testes automáticos (Octave e JavaScript)
tools/blast-dbf/     descompactador dos arquivos .dbc do DATASUS (C)
analise.m            exploração local no Octave
```

**Requisitos para rodar localmente:** GNU Octave (sem pacotes adicionais), `curl`, `jq` e um compilador C. No GitHub, tudo é instalado pelo próprio workflow.

```bash
make -C tools/blast-dbf
bash scripts/coleta_ano.sh 2019 "SIM SIH"
octave-cli --path octave --path config --eval "consolida; compara_faixas; consolida_cubo"
```

---

## Fontes dos dados

- Ministério da Saúde / DATASUS: Sistema de Informações Hospitalares do SUS (SIH/SUS, AIH reduzida), Sistema de Informações sobre Mortalidade (SIM) e Sistema de Informações sobre Nascidos Vivos (SINASC). FTP `ftp.datasus.gov.br/dissemin/publicos`.
- IBGE: projeções da população por sexo e idade (revisão 2024), estimativas anuais da população e Censo Demográfico 2022, via API SIDRA.
- Tabela CID-10 do SIM e Tabela Unificada de Procedimentos do SUS (SIGTAP), usadas apenas para os nomes na busca.

## Como citar

Jannuzzi, Rachel Ingrid Pereira da Rocha. *andesedepoisCOV19: internações e óbitos no SUS antes e depois da COVID-19, por CID-10, faixa etária e sexo*. 2026. Repositório GitHub. ORCID: [0000-0002-0408-6302](https://orcid.org/0000-0002-0408-6302).

## Licença: todos os direitos reservados

© 2026 Rachel Ingrid Pereira da Rocha Jannuzzi. **Todos os direitos reservados.**

Este repositório **não** é de código aberto. O código-fonte, o site, a metodologia de análise, a documentação e os resultados gerados (tabelas, gráficos e textos) são protegidos pela Lei de Direitos Autorais (Lei nº 9.610/1998) e pela Lei de Software (Lei nº 9.609/1998).

**Sem autorização prévia e por escrito da autora, é proibido:**

- copiar ou reproduzir, total ou parcialmente, o código, o site ou a documentação;
- modificar, adaptar ou criar obras derivadas;
- distribuir, publicar, hospedar em outro endereço, sublicenciar ou vender;
- usar este material, no todo ou em parte, em trabalhos acadêmicos, produtos ou serviços, salvo como citação com referência à autora (ver *Como citar*).

O fato de o repositório estar visível publicamente **não concede nenhuma licença** de uso. A visualização do conteúdo e a cópia (*fork*) dentro da própria plataforma decorrem dos Termos de Serviço do GitHub. Elas não autorizam reproduzir, modificar ou usar o material fora dessas condições.

Pedidos de autorização: abra uma *issue* neste repositório ou entre em contato pelo [ORCID da autora](https://orcid.org/0000-0002-0408-6302).

**Exceções (materiais de terceiros, que seguem suas próprias licenças):**

- `tools/blast-dbf/`: descompactador de arquivos `.dbc`, sob licença zlib (Mark Adler; Daniela Petruzalek e Pablo Fonseca). Ver `tools/blast-dbf/ORIGEM.txt`.
- Microdados do DATASUS e dados do IBGE: informações públicas, de titularidade das respectivas instituições.

Veja também o arquivo [`LICENSE`](LICENSE).
