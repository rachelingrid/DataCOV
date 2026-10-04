function roda_testes()
% RODA_TESTES  Testes automaticos (rodam no GitHub Actions e localmente).
%   octave-cli --path octave --path config --path tests --eval roda_testes
  raiz = fileparts(fileparts(mfilename('fullpath')));
  tmp = tempname(); mkdir(tmp);
  confirm_recursive_rmdir(false);
  limpa = onCleanup(@() rmdir(tmp, 's'));
  falhas = 0;

  % 1) Leitor DBF contra arquivo real descompactado pelo blast-dbf
  T = ler_dbf(fullfile(raiz, 'tests', 'amostras', 'sids.dbf'));
  falhas += confere('ler_dbf: 100 registros', T.n, 100);
  falhas += confere('ler_dbf: 1o municipio', strtrim(T.dados.NAME(1, :)), 'Ashe');

  % 2) cid_mencao
  M = junta_cids(['I269'; 'J189'; 'C509'], ['    '; 'I802'; 'XI26']);
  falhas += confere('cid_mencao I26', cid_mencao(M, {'I26'})', [true false false]);
  falhas += confere('cid_mencao I80', cid_mencao(M, {'I80'})', [false true false]);
  falhas += confere('cid_mencao linha SIM', cid_mencao('*R570*I269', {'I26'}), true);

  % 3) SIM obitos
  S.CAUSABAS  = {'I269'; 'J189'; 'O880'; 'O034'; 'U071'; 'I219'; 'C509'};
  S.LINHAA    = {''; '*I269'; ''; ''; '*I26X'; ''; ''};
  S.LINHAB    = {''; '*I802'; ''; ''; ''; ''; ''};
  S.LINHAC    = repmat({''}, 7, 1);
  S.LINHAD    = repmat({''}, 7, 1);
  S.LINHAII   = repmat({''}, 7, 1);
  S.CODMUNRES = {'330455'; '355030'; '330455'; '330455'; '330455'; '330455'; '330455'};
  S.DTOBITO   = {'15032019'; '01022019'; '10102019'; '05052019'; '07072019'; '08082019'; '09092019'};
  S.SEXO      = {'2'; '1'; '2'; '2'; '1'; '2'; '1'};
  S.IDADE     = {'450'; '470'; '432'; '425'; '480'; '430'; '460'};
  S.OBITOGRAV = {''; ''; '1'; '2'; ''; '2'; ''};
  S.OBITOPUERP= {''; ''; '3'; '3'; ''; '1'; ''};
  f = fullfile(tmp, 'sim.dbf'); escreve_dbf(f, S);
  out = fullfile(tmp, 'sim.csv');
  processa_arquivo('SIM', f, out, 2019, 0);
  A = le_agregado(out);
  esp = {'EMBOLIA', 4, 2; 'TROMBOSE', 1, 0; 'TEV', 4, 2; 'TEV_COVID', 1, 0; ...
         'GESTANTE', 3, 2; 'GESTANTE_TEV', 1, 1; 'GESTANTE_TRI1_PROXY', 1, 1; ...
         'GESTANTE_PUERPERIO', 1, 0; 'GESTANTE_GRAVIDEZ', 1, 1};
  falhas += confere_grupos('SIM', A, esp);
  falhas += confere('SIM: UF SP', sum(A.n_qualquer(strcmp(A.uf, 'SP') & strcmp(A.grupo, 'TEV'))), 1);

  % 4) Obitos fetais
  F.CAUSABAS   = repmat({'P964'}, 6, 1);
  F.CODMUNRES  = repmat({'330455'}, 6, 1);
  F.DTOBITO    = repmat({'01012019'}, 6, 1);
  F.SEXO       = repmat({'1'}, 6, 1);
  F.SEMAGESTAC = {'10'; '20'; '30'; ''; ''; ''};
  F.GESTACAO   = {''; ''; ''; '2'; '1'; '5'};
  F.TIPOBITO   = repmat({'1'}, 6, 1);
  f = fullfile(tmp, 'fet.dbf'); escreve_dbf(f, F);
  out = fullfile(tmp, 'fet.csv');
  processa_arquivo('DOFET', f, out, 2019, 0);
  A = le_agregado(out);
  esp = {'NATIMORTO', 6, 6; 'NATIMORTO_TRI1', 1, 1; 'NATIMORTO_TRI2', 2, 2; ...
         'NATIMORTO_TRI3', 2, 2; 'NATIMORTO_TRI_IGN', 1, 1};
  falhas += confere_grupos('DOFET', A, esp);

  % 5) SIH internacoes
  H.DIAG_PRINC = {'I802'; 'I702'; 'O800'; 'O001'; 'J189'};
  H.DIAG_SECUN = repmat({''}, 5, 1);
  H.DIAGSEC1   = {''; 'E115'; ''; ''; ''};
  H.DIAGSEC2   = {''; ''; ''; 'O223'; ''};
  H.PROC_REA   = {'0303060000'; '0408050012'; '0310010039'; '0411020000'; '0303140000'};
  H.MUNIC_RES  = repmat({'330455'}, 5, 1);
  H.ANO_CMPT   = repmat({'2019'}, 5, 1);
  H.MES_CMPT   = repmat({'03'}, 5, 1);
  H.SEXO       = {'3'; '1'; '3'; '3'; '1'};
  H.IDADE      = {'55'; '68'; '25'; '30'; '40'};
  H.COD_IDADE  = repmat({'4'}, 5, 1);
  H.MORTE      = {'1'; '1'; '0'; '0'; '0'};
  H.CID_MORTE  = {'I269'; ''; ''; ''; ''};
  f = fullfile(tmp, 'sih.dbf'); escreve_dbf(f, H);
  out = fullfile(tmp, 'sih.csv');
  processa_arquivo('SIH', f, out, 2019, 0);
  A = le_agregado(out);
  esp = {'TROMBOSE', 2, 1; 'EMBOLIA', 1, 0; 'TEV', 2, 1; 'AMPUTACAO', 1, 1; ...
         'AMP_MMII', 1, 1; 'AMP_DIABETES', 1, 0; 'AMP_VASCULAR', 1, 1; ...
         'GESTANTE', 2, 2; 'GESTANTE_TRI1_PROXY', 1, 1; 'GESTANTE_TEV', 1, 0};
  falhas += confere_grupos('SIH', A, esp);
  falhas += confere('SIH: obitos TEV', sum(A.obitos_qualquer(strcmp(A.grupo, 'TEV'))), 1);
  falhas += confere('SIH: obitos amputacao', sum(A.obitos_qualquer(strcmp(A.grupo, 'AMPUTACAO'))), 1);

  % 6) Populacao (SIDRA) + taxas na consolidacao
  r = fullfile(tmp, 'repo'); mkdir(r); mkdir(fullfile(r, 'dados')); mkdir(fullfile(r, 'dados', 'partes'));
  mkdir(fullfile(r, 'dados', 'populacao')); mkdir(fullfile(r, 'docs'));
  cab = '{"NC":"N","NN":"N","MC":"M","MN":"M","V":"Valor","D1C":"Brasil e Unidade da Federa\u00e7\u00e3o (C\u00f3digo)","D1N":"Brasil e UF","D2C":"Vari\u00e1vel (C\u00f3digo)","D2N":"V","D3C":"Ano (C\u00f3digo)","D3N":"Ano"}';
  lin = @(c, a, v) sprintf(',{"NC":"3","NN":"UF","MC":"45","MN":"P","V":"%s","D1C":"%d","D1N":"x","D2C":"9324","D2N":"P","D3C":"%d","D3N":"%d"}', v, c, a, a);
  js = ['[' cab lin(33, 2019, '1000000') lin(33, 2021, '1200000') lin(33, 2020, '...') ']'];
  fid = fopen(fullfile(r, 'dados', 'populacao', 'sidra_6579.json'), 'w'); fputs(fid, js); fclose(fid);
  monta_populacao(r);
  fid = fopen(fullfile(r, 'dados', 'populacao_uf.csv')); fgetl(fid);
  C = textscan(fid, '%s %f %f %s', 'Delimiter', ','); fclose(fid);
  m20 = strcmp(C{1}, 'RJ') & C{2} == 2020;
  falhas += confere('populacao: 2020 interpolado', C{3}(m20), 1100000);
  falhas += confere('populacao: origem', C{4}(m20), {'interpolado'});
  m22 = strcmp(C{1}, 'RJ') & C{2} == 2022;
  falhas += confere('populacao: 2022 extrapolado', C{3}(m22), 1300000);
  fid = fopen(fullfile(r, 'dados', 'partes', '2019_X.csv'), 'w');
  fprintf(fid, 'fonte,ano,mes,uf,sexo,faixa,grupo,preliminar,n_qualquer,n_principal,obitos_qualquer,obitos_principal\n');
  for mes = 1:12
    fprintf(fid, 'SIH,2019,%d,RJ,F,20-29,TEV,0,5,2,1,0\n', mes);
    fprintf(fid, 'SIM,2019,%d,RJ,F,20-29,GESTANTE,0,2,1,2,1\n', mes);
    fprintf(fid, 'SINASC,2019,%d,RJ,F,00-09,NASCIDOS_VIVOS,0,1000,1000,0,0\n', mes);
  end
  fclose(fid);
  consolida(r);
  fid = fopen(fullfile(r, 'dados', 'anual.csv')); h = strsplit(fgetl(fid), ',');
  C = textscan(fid, ['%s %s %s' repmat(' %f', 1, numel(h) - 3)], 'Delimiter', ','); fclose(fid);
  k = @(nome) C{find(strcmp(h, nome))};
  sel = strcmp(C{1}, 'SIH') & strcmp(C{3}, 'RJ');
  tx = k('tx_milhao_n_qualquer');
  falhas += confere('taxa: TEV por milhao (60/1e6*1e6)', tx(sel), 60);
  sel = strcmp(C{1}, 'SIM') & strcmp(C{3}, 'RJ');
  te = k('tx_especifica_n_qualquer');
  falhas += confere('taxa: gestante por 100 mil NV (24/12000)', round(te(sel) * 1e6) / 1e6, 200);

  % 7) Populacao por sexo e idade (resposta da API v3 do IBGE -> faixas)
  r2 = fullfile(tmp, 'repo2'); mkdir(r2); mkdir(fullfile(r2, 'dados')); mkdir(fullfile(r2, 'dados', 'populacao'));
  [st, ~] = system(sprintf('jq -r -f "%s" "%s" > "%s"', fullfile(raiz, 'scripts', 'sidra_v3_csv.jq'), ...
                   fullfile(raiz, 'tests', 'amostras', 'ibge_v3_amostra.json'), fullfile(r2, 'dados', 'populacao', 'corpo.csv')));
  if st ~= 0
    printf('  (jq indisponivel: teste 7 pulado)\n');
  else
    corpo = fileread(fullfile(r2, 'dados', 'populacao', 'corpo.csv'));
    fid = fopen(fullfile(r2, 'dados', 'populacao', 'pop_sexo_idade.csv'), 'w');
    fprintf(fid, 'cod_local,ano,sexo,idade,populacao\n%s', corpo); fclose(fid);
    monta_populacao_faixa(r2);
    fid = fopen(fullfile(r2, 'dados', 'populacao_sexo_faixa.csv')); fgetl(fid);
    C = textscan(fid, '%s %f %s %s %f', 'Delimiter', ','); fclose(fid);
    pega = @(u, sx, fx) C{5}(strcmp(C{1}, u) & strcmp(C{3}, sx) & strcmp(C{4}, fx));
    falhas += confere('pop faixa: BR M 20-29 (sem grupo 20-24)', pega('BR', 'M', '20-29'), 1600000);
    falhas += confere('pop faixa: RJ M 20-29', pega('RJ', 'M', '20-29'), 130000);
    falhas += confere('pop faixa: BR F 90+ (aberta)', pega('BR', 'F', '90+'), 300000);
    falhas += confere('pop faixa: BR F 80-89 (sem 80+)', pega('BR', 'F', '80-89'), 50000);
  end

  % 8) Regressao de Poisson (valores conferidos com statsmodels)
  y = [310 325 298 340 352 349 470 455 498 481 512]';
  pop = [1.00 1.01 1.02 1.03 1.04 1.05 1.07 1.08 1.09 1.10 1.11]' * 1e6;
  pos = [zeros(6, 1); ones(5, 1)];
  F = glm_poisson([ones(11, 1) pos], y, log(pop));
  falhas += confere('glm: b1 = 0.322888', round(F.b(2) * 1e6) / 1e6, 0.322888);
  falhas += confere('t_quantil(0.975, 9)', round(t_quantil(0.975, 9) * 1e5) / 1e5, 2.26216);
  falhas += confere('holm', holm([0.01 0.04 0.03]), [0.03 0.06 0.06]);

  % 9) compara_faixas: efeito deterministico (100/ano pre, 150/ano pos, pop fixa)
  r3 = fullfile(tmp, 'repo3'); mkdir(r3); mkdir(fullfile(r3, 'dados')); mkdir(fullfile(r3, 'dados', 'partes')); mkdir(fullfile(r3, 'docs'));
  fid = fopen(fullfile(r3, 'dados', 'partes', 'x_SIH.csv'), 'w');
  fprintf(fid, 'fonte,ano,mes,uf,sexo,faixa,grupo,preliminar,n_qualquer,n_principal,obitos_qualquer,obitos_principal\n');
  fp = fopen(fullfile(r3, 'dados', 'populacao_sexo_faixa.csv'), 'w');
  fprintf(fp, 'uf,ano,sexo,faixa,populacao\n');
  for ano = 2014:2025
    n = 100 + 50 * (ano >= 2021) + 400 * (ano == 2020) + 300 * (ano == 2014);   % 2014 fora da janela 5x5
    for mes = 1:12
      c = floor(n / 12) + (mes <= mod(n, 12));
      fprintf(fid, 'SIH,%d,%d,RJ,M,50-59,TVP,0,%d,%d,0,0\n', ano, mes, c, c);
    end
    fprintf(fp, 'BR,%d,M,50-59,1000000\n', ano);
  end
  fclose(fid); fclose(fp);
  consolida(r3); compara_faixas(r3);
  fid = fopen(fullfile(r3, 'dados', 'faixas_teste.csv')); h = strsplit(fgetl(fid), ',');
  L = textscan(fid, ['%s %s %s %s %s %s' repmat(' %f', 1, numel(h) - 7) ' %s'], 'Delimiter', ','); fclose(fid);
  k = find(strcmp(L{1}, 'SIH') & strcmp(L{2}, 'TVP') & strcmp(L{3}, 'n_qualquer') & strcmp(L{5}, 'M') & strcmp(L{6}, '50-59'));
  falhas += confere('faixas: RR = 1,5 (2020 e 2014 fora: janela 2015-19 x 2021-25)', round(L{find(strcmp(h, 'rr_pos_pre'))}(k) * 1e4) / 1e4, 1.5);
  falhas += confere('faixas: taxa pre 100/milhao', round(L{find(strcmp(h, 'taxa_pre_milhao'))}(k)), 100);
  falhas += confere('faixas: classificado aumento', L{end}(k), {'aumento'});
  falhas += confere('faixas: 5 anos antes e 5 depois', [L{find(strcmp(h, 'anos_pre')) - 0}(k), L{find(strcmp(h, 'anos_pos'))}(k)], [5 5]);
  P = periodos();
  [a1, a2] = janela_simetrica([2014:2019, 2021:2026], P);
  falhas += confere('janela com 2026 completo: 6x6', [numel(a1), numel(a2), a1(1)], [6 6 2014]);
  [a1, a2] = janela_simetrica([2017:2019, 2021:2025], P);
  falhas += confere('janela com so 3 anos antes: 3x3', [a1, a2], [2017:2019, 2021:2023]);

  % 10) Cubo de todos os CIDs/procedimentos e arquivos do site
  r4 = fullfile(tmp, 'repo4'); mkdir(r4); mkdir(fullfile(r4, 'dados')); mkdir(fullfile(r4, 'dados', 'cubo')); mkdir(fullfile(r4, 'docs'));
  falhas += confere('codifica/decodifica CID', decodifica_cid(codifica_cid(['I802'; 'I26X'; 'J18 ']))', {'I802', 'I26', 'J18'});
  H = struct('DIAG_PRINC', {{'I802'; 'I802'; 'J189'}}, 'DIAG_SECUN', {{''; 'I802'; 'I269'}}, ...
             'PROC_REA', {{'0408050012'; '0303060000'; '0303140000'}}, 'MUNIC_RES', {repmat({'330455'}, 3, 1)}, ...
             'ANO_CMPT', {repmat({'2019'}, 3, 1)}, 'MES_CMPT', {repmat({'03'}, 3, 1)}, 'SEXO', {{'1'; '1'; '3'}}, ...
             'IDADE', {{'55'; '52'; '30'}}, 'COD_IDADE', {repmat({'4'}, 3, 1)}, 'MORTE', {{'1'; '0'; '0'}}, 'CID_MORTE', {{''; ''; ''}});
  f = fullfile(r4, 'h.dbf'); escreve_dbf(f, H);
  cubo = fullfile(r4, 'dados', 'cubo', '2019_SIH_cubo.csv');
  processa_arquivo('SIH', f, fullfile(r4, 'h.csv'), 2019, 0, cubo);
  processa_arquivo('SIH', f, fullfile(r4, 'h.csv'), 2019, 0, cubo);
  compacta_cubo(cubo);
  fid = fopen(cubo); fgetl(fid); C = textscan(fid, '%f %f %f %f %f %f %f', 'Delimiter', ','); fclose(fid);
  i802 = codifica_cid('I802');
  falhas += confere('cubo: I802 diag principal (2 arquivos x 2)', sum(C{6}(C{2} == 1 & C{3} == i802)), 4);
  falhas += confere('cubo: I802 qualquer diag conta 1x por internacao', sum(C{6}(C{2} == 2 & C{3} == i802)), 4);
  falhas += confere('cubo: obitos I802', sum(C{7}(C{2} == 1 & C{3} == i802)), 2);
  falhas += confere('cubo: procedimento amputacao', sum(C{6}(C{2} == 3 & C{3} == 408050012)), 2);
  consolida_cubo(r4);
  js = fileread(fullfile(r4, 'docs', 'cubo', 'SIH_DP_I.js'));
  falhas += confere('site: linha I802 homens 50-59', ~isempty(strfind(js, 'I802,2019,1,6,4,2')), true);
  falhas += confere('site: arquivo de procedimentos', exist(fullfile(r4, 'docs', 'cubo', 'SIH_PR_0408.js'), 'file'), 2);

  if falhas > 0
    error('roda_testes: %d teste(s) falharam', falhas);
  end
  printf('Todos os testes passaram.\n');
end

function f = confere(nome, obtido, esperado)
  if isequal(obtido, esperado)
    printf('  ok    %s\n', nome); f = 0;
  else
    printf('  FALHA %s\n', nome); disp(obtido); disp(esperado); f = 1;
  end
end

function f = confere_grupos(fonte, A, esp)
  f = 0;
  for i = 1:rows(esp)
    m = strcmp(A.grupo, esp{i, 1});
    f += confere(sprintf('%s %s qualquer', fonte, esp{i, 1}), sum(A.n_qualquer(m)), esp{i, 2});
    f += confere(sprintf('%s %s principal', fonte, esp{i, 1}), sum(A.n_principal(m)), esp{i, 3});
  end
end
