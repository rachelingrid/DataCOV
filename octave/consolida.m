function consolida(raiz)
% CONSOLIDA  Junta todas as partes anuais e gera as tabelas finais.
%
%   consolida()        usa a pasta do repositorio
%   consolida(raiz)
%
% Saidas:
%   dados/anual.csv              fonte, grupo, uf (inclui BR), ano + contagens
%   dados/detalhado.csv          idem, aberto por sexo e faixa etaria
%   dados/comparacao_pre_pos.csv medias pre (2015-19) x pos (2021+), 2020 a parte
%   docs/dados.js                os mesmos dados para o painel (offline)

  if nargin < 1
    raiz = fileparts(fileparts(mfilename('fullpath')));
  end
  P = periodos();
  lst = dir(fullfile(raiz, 'dados', 'partes', '*.csv'));
  lst = lst(cellfun(@isempty, strfind({lst.name}, '_log')));
  if isempty(lst)
    error('consolida: nenhuma parte em dados/partes');
  end
  A = le_agregado(fullfile(raiz, 'dados', 'partes', {lst.name}));
  printf('consolida: %d linhas de %d arquivos\n', numel(A.ano), numel(lst));
  medidas = {'n_qualquer', 'n_principal', 'obitos_qualquer', 'obitos_principal'};
  V = [A.n_qualquer, A.n_principal, A.obitos_qualquer, A.obitos_principal];

  % --- meses com dados por fonte e ano (cobertura) ---
  [fontes, ~, fi] = unique(A.fonte);
  anos = unique(A.ano);
  meses = zeros(numel(fontes), numel(anos));
  for i = 1:numel(fontes)
    for j = 1:numel(anos)
      m = fi == i & A.ano == anos(j) & A.mes > 0;
      meses(i, j) = numel(unique(A.mes(m)));
    end
  end

  % --- tabela detalhada (sem mes) ---
  [D, VD] = agrupa({A.fonte, A.grupo, A.uf, A.sexo, A.faixa}, A.ano, [V, A.preliminar]);
  % acrescenta Brasil
  [DB, VB] = agrupa({A.fonte, A.grupo, repmat({'BR'}, numel(A.ano), 1), A.sexo, A.faixa}, A.ano, [V, A.preliminar]);
  D = juntas(D, DB); VD = [VD; VB];
  pre = VD(:, end) > 0;  VD = VD(:, 1:end-1);
  escreve_csv(fullfile(raiz, 'dados', 'detalhado.csv'), ...
    {'fonte', 'grupo', 'uf', 'sexo', 'faixa', 'ano', medidas{:}, 'preliminar'}, ...
    D.txt, [D.ano, VD, pre]);

  % --- tabela anual (soma sexo e faixa) ---
  [N, VN] = agrupa({D.txt(:, 1), D.txt(:, 2), D.txt(:, 3)}, D.ano, [VD, pre]);
  preN = VN(:, end) > 0;  VN = VN(:, 1:end-1);
  [~, fN] = ismember(N.txt(:, 1), fontes);
  [~, aN] = ismember(N.ano, anos);
  mesesN = reshape(meses(sub2ind(size(meses), fN, aN)), [], 1);   % coluna mesmo com 1 fonte
  % --- denominadores e taxas ---
  [popN, nvN, nascN] = denominadores(raiz, N, VN);
  fator = 12 ./ max(mesesN, 1);                 % anualiza anos parciais
  TXM = VN(:, 1:4) .* fator ./ popN * 1e6;      % por milhao de habitantes
  gest = strncmp(N.txt(:, 2), 'GESTANTE', 8);
  nati = strncmp(N.txt(:, 2), 'NATIMORTO', 9);
  TXE = nan(size(TXM));
  TXE(gest, :) = VN(gest, 1:4) .* fator(gest) ./ nvN(gest) * 1e5;    % por 100 mil nascidos vivos
  TXE(nati, :) = VN(nati, 1:4) .* fator(nati) ./ nascN(nati) * 1e3;  % por mil nascimentos
  sinasc = strcmp(N.txt(:, 1), 'SINASC');
  TXM(sinasc, :) = NaN;
  tx_m = strcat('tx_milhao_', medidas);
  tx_e = strcat('tx_especifica_', medidas);
  escreve_csv(fullfile(raiz, 'dados', 'anual.csv'), ...
    {'fonte', 'grupo', 'uf', 'ano', medidas{:}, 'meses', 'preliminar', ...
     'populacao', 'nascidos_vivos', tx_m{:}, tx_e{:}}, ...
    N.txt, [N.ano, VN, mesesN, preN, popN, nvN, TXM, TXE]);
  VN = [VN, TXM, TXE];                          % comparacao tambem nas taxas
  medidas = [medidas, tx_m, tx_e];

  % --- comparacao pre x pos ---
  % Anos disponiveis por fonte: com dados (e completos, salvo incluir_parciais)
  minimo = 12;
  if P.incluir_parciais, minimo = 1; end
  [chaves, ~, ci] = unique(strcat(N.txt(:, 1), '|', N.txt(:, 2), '|', N.txt(:, 3)));
  nc = numel(chaves);
  C = struct('txt', {cell(nc * numel(medidas), 4)}, 'num', zeros(nc * numel(medidas), 7));
  lin = 0;
  for k = 1:nc
    m = ci == k;
    partes = strsplit(chaves{k}, '|');
    f = find(strcmp(fontes, partes{1}));
    disp_anos = anos(meses(f, :) >= minimo);
    disp_todos = anos(meses(f, :) >= 1);
    for d = 1:numel(medidas)
      [jpre, jpos] = janela_simetrica(disp_anos, P);
      [mpre, npre] = media_periodo(N.ano(m), VN(m, d), jpre);
      [mpos, npos] = media_periodo(N.ano(m), VN(m, d), jpos);
      [m20, ~]     = media_periodo(N.ano(m), VN(m, d), intersect(P.transicao, disp_todos));
      lin = lin + 1;
      C.txt(lin, :) = [partes, medidas(d)];
      razao = mpos / mpre;
      if ~(mpre > 0), razao = NaN; end
      C.num(lin, :) = [mpre, npre, m20, mpos, npos, razao, 100 * (razao - 1)];
    end
  end
  escreve_csv(fullfile(raiz, 'dados', 'comparacao_pre_pos.csv'), ...
    {'fonte', 'grupo', 'uf', 'medida', 'media_pre', 'anos_pre', 'valor_2020', ...
     'media_pos', 'anos_pos', 'razao_pos_pre', 'variacao_pct'}, C.txt(1:lin, :), C.num(1:lin, :));

  % --- painel ---
  escreve_js(fullfile(raiz, 'docs', 'dados.js'), N, VN, mesesN, preN, popN, nvN, P);
  printf('consolida: concluido (%d linhas anuais)\n', rows(VN));
end

% ------------------------------------------------------------------------
function [G, S] = agrupa(cols, ano, V)
  % soma V por combinacao de colunas de texto + ano
  nt = numel(cols);
  idx = zeros(numel(ano), nt + 1);
  rot = cell(1, nt);
  for i = 1:nt
    [rot{i}, ~, idx(:, i)] = unique(cols{i});
  end
  idx(:, end) = ano;
  [u, ~, j] = unique(idx, 'rows');
  S = zeros(rows(u), columns(V));
  for c = 1:columns(V)
    S(:, c) = accumarray(j, V(:, c));
  end
  G.txt = cell(rows(u), nt);
  for i = 1:nt
    G.txt(:, i) = rot{i}(u(:, i));
  end
  G.ano = u(:, end);
end

function G = juntas(A, B)
  G.txt = [A.txt; B.txt];
  G.ano = [A.ano; B.ano];
end

function [m, n] = media_periodo(anos, v, periodo)
  % media anual nos anos do periodo; anos sem registro do grupo contam zero
  n = numel(periodo);
  if n == 0
    m = NaN;
  else
    m = sum(v(ismember(anos, periodo))) / n;
  end
end

function escreve_csv(arq, cab, txt, num)
  fid = fopen(arq, 'w');
  fprintf(fid, '%s\n', strjoin(cab, ','));
  nt = columns(txt);
  for i = 1:rows(num)
    fprintf(fid, '%s,', txt{i, :});
    s = sprintf('%.10g,', num(i, :));
    s = strrep(s(1:end-1), 'NaN', '');
    fprintf(fid, '%s\n', s);
  end
  fclose(fid);
end

function escreve_js(arq, N, VN, meses, pre, pop, nv, P)
  fid = fopen(arq, 'w');
  fprintf(fid, '// Gerado por octave/consolida.m em %s. Nao editar.\n', datestr(now, 'yyyy-mm-dd HH:MM'));
  fprintf(fid, 'window.DADOS = {\n');
  fprintf(fid, '"gerado":"%s",\n', datestr(now, 'yyyy-mm-dd'));
  fprintf(fid, '"pre":[%s],"transicao":[%s],"pos":[%s],"incluir_parciais":%d,"simetrico":%d,\n', ...
          num2str_lista(P.pre), num2str_lista(P.transicao), num2str_lista(P.pos), P.incluir_parciais, P.simetrico);
  fprintf(fid, '"colunas":["fonte","grupo","uf","ano","n_qualquer","n_principal","obitos_qualquer","obitos_principal","meses","preliminar","populacao","nascidos_vivos","tx_milhao_n_qualquer","tx_milhao_n_principal","tx_milhao_obitos_qualquer","tx_milhao_obitos_principal","tx_especifica_n_qualquer","tx_especifica_n_principal","tx_especifica_obitos_qualquer","tx_especifica_obitos_principal"],\n');
  fprintf(fid, '"linhas":[\n');
  for i = 1:rows(VN)
    num = [VN(i, 1:4), meses(i), pre(i), pop(i), nv(i), VN(i, 5:12)];
    t = sprintf('%.10g,', num); t = strrep(t(1:end-1), 'NaN', 'null');
    fprintf(fid, '["%s","%s","%s",%d,%s]', N.txt{i, 1}, N.txt{i, 2}, N.txt{i, 3}, N.ano(i), t);
    if i < rows(VN), fprintf(fid, ',\n'); end
  end
  fprintf(fid, '\n]};\n');
  fclose(fid);
end

function [pop, nv, nasc] = denominadores(raiz, N, VN)
  % populacao (dados/populacao_uf.csv), nascidos vivos (SINASC) e
  % nascimentos totais (nascidos vivos + natimortos) para cada linha de N
  n = rows(VN);
  pop = nan(n, 1); nv = nan(n, 1); nasc = nan(n, 1);
  chave = strcat(N.txt(:, 3), '|', arrayfun(@(a) sprintf('%d', a), N.ano, 'UniformOutput', false));
  arq = fullfile(raiz, 'dados', 'populacao_uf.csv');
  if exist(arq, 'file') == 2
    fid = fopen(arq); fgetl(fid);
    C = textscan(fid, '%s %f %f %s', 'Delimiter', ','); fclose(fid);
    kp = strcat(C{1}, '|', arrayfun(@(a) sprintf('%d', a), C{2}, 'UniformOutput', false));
    [ok, j] = ismember(chave, kp);
    pop(ok) = C{3}(j(ok));
  else
    warning('consolida: dados/populacao_uf.csv ausente - taxas por milhao ficam vazias');
  end
  s = strcmp(N.txt(:, 1), 'SINASC') & strcmp(N.txt(:, 2), 'NASCIDOS_VIVOS');
  [ok, j] = ismember(chave, chave(s));
  idx = find(s);
  nv(ok) = VN(idx(j(ok)), 1);
  f = strcmp(N.txt(:, 1), 'DOFET') & strcmp(N.txt(:, 2), 'NATIMORTO');
  [okf, jf] = ismember(chave, chave(f));
  idf = find(f);
  fet = zeros(n, 1); fet(okf) = VN(idf(jf(okf)), 1);
  nasc = nv + fet;
end

function s = num2str_lista(v)
  s = strjoin(arrayfun(@(x) sprintf('%d', x), v, 'UniformOutput', false), ',');
end
