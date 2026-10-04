function nreg = processa_arquivo(fonte, arq_dbf, arq_saida, ano_arquivo, preliminar, arq_cubo)
% PROCESSA_ARQUIVO  Le um DBF do DATASUS, classifica cada registro nos
% grupos do estudo e grava as contagens agregadas (acrescenta ao CSV).
%
%   fonte        'SIM' (obitos nao fetais), 'DOFET' (obitos fetais), 'SIH'
%                (internacoes) ou 'SINASC' (nascidos vivos, denominador)
%   arq_dbf      arquivo DBF ja descompactado
%   arq_saida    CSV de saida (criado com cabecalho se nao existir)
%   ano_arquivo  ano do arquivo (usado se a data do registro faltar)
%   preliminar   1 se o arquivo veio da pasta PRELIM do DATASUS
%   arq_cubo     (opcional) CSV do cubo de todos os CIDs/procedimentos
%                por ano x sexo x faixa (ver GRAVA_CUBO)
%
% Colunas de saida:
%   fonte,ano,mes,uf,sexo,faixa,grupo,preliminar,
%   n_qualquer,n_principal,obitos_qualquer,obitos_principal
% "qualquer"  = codigo em qualquer campo (linhas A-D e II do atestado; todos
%               os diagnosticos da AIH).
% "principal" = causa basica (SIM) ou diagnostico principal (SIH).

  if nargin < 5, preliminar = 0; end
  G = grupos_cid();

  switch upper(fonte)
    case 'SIM'
      [R, nreg] = classifica_sim(arq_dbf, G, ano_arquivo);
    case 'DOFET'
      [R, nreg] = classifica_dofet(arq_dbf, G, ano_arquivo);
    case 'SIH'
      [R, nreg] = classifica_sih(arq_dbf, G, ano_arquivo);
    case 'SINASC'
      [R, nreg] = classifica_sinasc(arq_dbf, ano_arquivo);
    otherwise
      error('processa_arquivo: fonte desconhecida %s', fonte);
  end

  grava_agregado(upper(fonte), R, arq_saida, preliminar);
  if nargin >= 6 && ~isempty(arq_cubo)
    grava_cubo(R, arq_cubo);
  end
end

% ------------------------------------------------------------------------
function [R, n] = classifica_sim(arq, G, ano_arq)
  campos = {'CAUSABAS', 'LINHAA', 'LINHAB', 'LINHAC', 'LINHAD', 'LINHAII', ...
            'CODMUNRES', 'DTOBITO', 'SEXO', 'IDADE', 'OBITOGRAV', 'OBITOPUERP'};
  T = ler_dbf(arq, campos);
  D = T.dados; n = T.n;
  todas = junta_cids(D.CAUSABAS, D.LINHAA, D.LINHAB, D.LINHAC, D.LINHAD, D.LINHAII);
  bas = D.CAUSABAS;

  [ano, mes] = data_registro(D.DTOBITO, T.tipos.DTOBITO, ano_arq);
  R = atributos_base(n, ano, mes, D.CODMUNRES, sexo_padrao(D.SEXO), idade_sim(D.IDADE));

  fem = R.sexo == 'F';
  grav = strtrim(cellstr(D.OBITOGRAV));
  puer = strtrim(cellstr(D.OBITOPUERP));
  morte_grav = strcmp(grav, '1');
  morte_puer = strcmp(puer, '1') | strcmp(puer, '2');

  q.TROMBOSE = cid_mencao(todas, G.TROMBOSE);   p.TROMBOSE = cid_mencao(bas, G.TROMBOSE);
  q.EMBOLIA  = cid_mencao(todas, G.EMBOLIA);    p.EMBOLIA  = cid_mencao(bas, G.EMBOLIA);
  q.TEV      = q.TROMBOSE | q.EMBOLIA;          p.TEV      = p.TROMBOSE | p.EMBOLIA;
  cov = cid_mencao(todas, G.COVID);
  q.TEV_COVID = q.TEV & cov;                    p.TEV_COVID = p.TEV & cov;
  [q, p] = grupos_tvp(q, p, todas, bas, cov, G);

  obst_q = cid_mencao(todas, G.OBSTETRICO);
  obst_p = cid_mencao(bas, G.OBSTETRICO);
  q.GESTANTE = fem & (obst_q | morte_grav | morte_puer);
  p.GESTANTE = fem & obst_p;
  q.GESTANTE_GRAVIDEZ  = q.GESTANTE & morte_grav;   p.GESTANTE_GRAVIDEZ  = p.GESTANTE & morte_grav;
  q.GESTANTE_PUERPERIO = q.GESTANTE & morte_puer;   p.GESTANTE_PUERPERIO = p.GESTANTE & morte_puer;
  t1q = cid_mencao(todas, G.TRI1_PROXY);
  q.GESTANTE_TRI1_PROXY = q.GESTANTE & t1q;         p.GESTANTE_TRI1_PROXY = p.GESTANTE & cid_mencao(bas, G.TRI1_PROXY);
  q.GESTANTE_TEV = q.GESTANTE & q.TEV;              p.GESTANTE_TEV = p.GESTANTE & p.TEV;

  R.q = q; R.p = p;
  R.obito = true(n, 1);                         % todo registro do SIM e obito
  R.cubo = struct('CB', bas, 'CQ', todas);
end

% ------------------------------------------------------------------------
function [R, n] = classifica_dofet(arq, G, ano_arq)
  campos = {'CAUSABAS', 'LINHAA', 'LINHAB', 'LINHAC', 'LINHAD', 'LINHAII', ...
            'CODMUNRES', 'DTOBITO', 'SEXO', 'SEMAGESTAC', 'GESTACAO', 'TIPOBITO'};
  T = ler_dbf(arq, campos);
  D = T.dados; n = T.n;
  todas = junta_cids(D.CAUSABAS, D.LINHAA, D.LINHAB, D.LINHAC, D.LINHAD, D.LINHAII);
  bas = D.CAUSABAS;

  [ano, mes] = data_registro(D.DTOBITO, T.tipos.DTOBITO, ano_arq);
  R = atributos_base(n, ano, mes, D.CODMUNRES, sexo_padrao(D.SEXO), nan(n, 1));

  % garante apenas obitos fetais (TIPOBITO = 1) quando o campo existe
  tip = strtrim(cellstr(D.TIPOBITO));
  fetal = strcmp(tip, '1') | strcmp(tip, '');

  % Trimestre: semanas de gestacao; se faltar, usa a faixa GESTACAO
  sem = num_char(D.SEMAGESTAC);
  sem(sem < 4 | sem > 45) = NaN;
  ges = strtrim(cellstr(D.GESTACAO));
  tri = zeros(n, 1);                            % 0 = ignorado
  tri(sem <= 13) = 1;
  tri(sem >= 14 & sem <= 27) = 2;
  tri(sem >= 28) = 3;
  semfalta = isnan(sem);
  tri(semfalta & strcmp(ges, '2')) = 2;                       % 22-27 semanas
  tri(semfalta & ismember(ges, {'3', '4', '5', '6'})) = 3;    % 28 ou mais
  % GESTACAO = '1' (<22 sem) sem semanas exatas: nao separa 1o de 2o -> ignorado

  tevq = cid_mencao(todas, G.TEV);  tevp = cid_mencao(bas, G.TEV);
  q.NATIMORTO = fetal;                     p.NATIMORTO = fetal;
  q.NATIMORTO_TRI1 = fetal & tri == 1;     p.NATIMORTO_TRI1 = q.NATIMORTO_TRI1;
  q.NATIMORTO_TRI2 = fetal & tri == 2;     p.NATIMORTO_TRI2 = q.NATIMORTO_TRI2;
  q.NATIMORTO_TRI3 = fetal & tri == 3;     p.NATIMORTO_TRI3 = q.NATIMORTO_TRI3;
  q.NATIMORTO_TRI_IGN = fetal & tri == 0;  p.NATIMORTO_TRI_IGN = q.NATIMORTO_TRI_IGN;
  q.NATIMORTO_TEV = fetal & tevq;          p.NATIMORTO_TEV = fetal & tevp;

  R.q = q; R.p = p;
  R.obito = true(n, 1);
end

% ------------------------------------------------------------------------
function [R, n] = classifica_sih(arq, G, ano_arq)
  dx = [{'DIAG_PRINC', 'DIAG_SECUN'}, arrayfun(@(k) sprintf('DIAGSEC%d', k), 1:9, 'UniformOutput', false)];
  campos = [dx, {'PROC_REA', 'MUNIC_RES', 'ANO_CMPT', 'MES_CMPT', 'SEXO', ...
                 'IDADE', 'COD_IDADE', 'MORTE', 'CID_MORTE'}];
  T = ler_dbf(arq, campos);
  D = T.dados; n = T.n;
  lista = cellfun(@(c) D.(c), [dx, {'CID_MORTE'}], 'UniformOutput', false);
  todas = junta_cids(lista{:});
  pri = D.DIAG_PRINC;

  ano = num_char(D.ANO_CMPT);  ano(isnan(ano)) = ano_arq;
  mes = num_char(D.MES_CMPT);  mes(isnan(mes) | mes < 1 | mes > 12) = 0;
  R = atributos_base(n, ano, mes, D.MUNIC_RES, sexo_padrao(D.SEXO), idade_sih(D.IDADE, D.COD_IDADE));

  fem = R.sexo == 'F';
  morte = strcmp(strtrim(cellstr(D.MORTE)), '1');

  q.TROMBOSE = cid_mencao(todas, G.TROMBOSE);   p.TROMBOSE = cid_mencao(pri, G.TROMBOSE);
  q.EMBOLIA  = cid_mencao(todas, G.EMBOLIA);    p.EMBOLIA  = cid_mencao(pri, G.EMBOLIA);
  q.TEV      = q.TROMBOSE | q.EMBOLIA;          p.TEV      = p.TROMBOSE | p.EMBOLIA;
  cov = cid_mencao(todas, G.COVID);
  q.TEV_COVID = q.TEV & cov;                    p.TEV_COVID = p.TEV & cov;
  [q, p] = grupos_tvp(q, p, todas, pri, cov, G);

  q.GESTANTE = fem & cid_mencao(todas, G.OBSTETRICO);
  p.GESTANTE = fem & cid_mencao(pri, G.OBSTETRICO);
  q.GESTANTE_TRI1_PROXY = q.GESTANTE & cid_mencao(todas, G.TRI1_PROXY);
  p.GESTANTE_TRI1_PROXY = p.GESTANTE & cid_mencao(pri, G.TRI1_PROXY);
  q.GESTANTE_TEV = q.GESTANTE & q.TEV;          p.GESTANTE_TEV = q.GESTANTE & p.TEV;

  proc = D.PROC_REA;
  amp = cid_mencao(proc, G.AMPUTACAO);
  q.AMPUTACAO = amp;                            p.AMPUTACAO = amp;
  q.AMP_MMII = cid_mencao(proc, G.AMP_MMII);    p.AMP_MMII = q.AMP_MMII;
  q.AMP_MMSS = cid_mencao(proc, G.AMP_MMSS);    p.AMP_MMSS = q.AMP_MMSS;
  q.AMP_DEDO = cid_mencao(proc, G.AMP_DEDO);    p.AMP_DEDO = q.AMP_DEDO;
  q.AMP_DIABETES = amp & cid_mencao(todas, G.DIABETES);  p.AMP_DIABETES = amp & cid_mencao(pri, G.DIABETES);
  q.AMP_VASCULAR = amp & cid_mencao(todas, G.VASCULAR);  p.AMP_VASCULAR = amp & cid_mencao(pri, G.VASCULAR);
  q.AMP_TRAUMA   = amp & cid_mencao(todas, G.TRAUMA);    p.AMP_TRAUMA   = amp & cid_mencao(pri, G.TRAUMA);

  R.q = q; R.p = p;
  R.obito = morte;                              % obito durante a internacao
  R.cubo = struct('DP', pri, 'DQ', todas, 'PR', proc);
end

% ------------------------------------------------------------------------
function [q, p] = grupos_tvp(q, p, todas, pri, cov, G)
  % TVP (trombose venosa profunda) - foco da analise por sexo e faixa etaria
  q.TVP = cid_mencao(todas, G.TVP);             p.TVP = cid_mencao(pri, G.TVP);
  q.TVP_SEMCOVID = q.TVP & ~cov;                p.TVP_SEMCOVID = p.TVP & ~cov;
  q.TVP_TEP = q.TVP | cid_mencao(todas, {'I26'});
  p.TVP_TEP = p.TVP | cid_mencao(pri, {'I26'});
end

% ------------------------------------------------------------------------
function [R, n] = classifica_sinasc(arq, ano_arq)
  % sexo e faixa referem-se a MAE (para taxas maternas por idade da mae)
  T = ler_dbf(arq, {'CODMUNRES', 'DTNASC', 'IDADEMAE'});
  D = T.dados; n = T.n;
  [ano, mes] = data_registro(D.DTNASC, T.tipos.DTNASC, ano_arq);
  idm = num_char(D.IDADEMAE); idm(idm < 8 | idm > 60) = NaN;
  R = atributos_base(n, ano, mes, D.CODMUNRES, repmat('F', n, 1), idm);
  q.NASCIDOS_VIVOS = true(n, 1);  p = q;
  R.q = q; R.p = p;
  R.obito = false(n, 1);
end

% ------------------------------------------------------------------------
function R = atributos_base(n, ano, mes, codmun, sexo, idade)
  R.n = n;
  R.ano = ano(:);
  R.mes = mes(:);
  R.uf = uf_sigla(codmun);
  R.sexo = sexo(:);
  R.faixa = faixa_etaria(idade);
end

function s = sexo_padrao(S)
  % SIM: 1=M 2=F ; SIH: 1=M 3=F ; algumas bases usam M/F
  c = upper(strtrim(cellstr(S)));
  s = repmat('I', numel(c), 1);
  s(ismember(c, {'1', 'M'})) = 'M';
  s(ismember(c, {'2', '3', 'F'})) = 'F';
end

function a = idade_sim(I)
  % SIM: 1o digito = unidade (0 min,1 h,2 dias,3 meses,4 anos,5 = 100+anos)
  n = rows(I);
  a = nan(n, 1);
  if columns(I) < 3, return; end
  I = strjust(I, 'left');
  u = I(:, 1);
  v = num_char(I(:, 2:3));
  a(u >= '0' & u <= '3') = 0;
  a(u == '4') = v(u == '4');
  a(u == '5') = 100 + v(u == '5');
end

function a = idade_sih(I, C)
  v = num_char(I);
  c = strtrim(cellstr(C));
  a = nan(size(v));
  a(ismember(c, {'0', '1', '2', '3'})) = 0;
  a(strcmp(c, '4')) = v(strcmp(c, '4'));
  a(strcmp(c, '5')) = 100 + v(strcmp(c, '5'));
  % sem COD_IDADE: assume anos
  semcod = strcmp(c, '') & ~isnan(v);
  a(semcod) = v(semcod);
end

function [ano, mes] = data_registro(DT, tipo, ano_arq)
  n = rows(DT);
  ano = repmat(ano_arq, n, 1);
  mes = zeros(n, 1);
  if columns(DT) < 8, return; end
  if tipo == 'D'                % DBF data: aaaammdd
    a = num_char(DT(:, 1:4)); m = num_char(DT(:, 5:6));
  else                          % DATASUS texto: ddmmaaaa
    a = num_char(DT(:, 5:8)); m = num_char(DT(:, 3:4));
  end
  ok = ~isnan(a) & a > 1990 & a < 2100;
  ano(ok) = a(ok);
  okm = ~isnan(m) & m >= 1 & m <= 12;
  mes(okm) = m(okm);
end
