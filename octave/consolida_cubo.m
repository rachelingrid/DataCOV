function consolida_cubo(raiz)
% CONSOLIDA_CUBO  Junta dados/cubo/*_cubo.csv e gera os arquivos do site
% de comparacao (docs/comparar.html), que roda offline:
%
%   docs/cubo/meta.js              anos, periodos, meses por base/ano, populacao
%                                  por sexo x faixa (Brasil), lista de arquivos
%   docs/cubo/<FONTE>_<TIPO>_<K>.js  linhas "codigo,ano,sexo,faixa,n,obitos"
%                                  K = letra do CID ou 4 primeiros digitos do
%                                  procedimento (carregados sob demanda)
%   docs/cubo/indice_<FONTE>.js    codigos presentes e total de casos (busca)
%   docs/cubo/nomes.js             descricao de CIDs e procedimentos, se as
%                                  tabelas estiverem em dados/tabelas/
% Os arquivos sao .js (e nao .json) para abrir com duplo clique, sem servidor.
  if nargin < 1, raiz = fileparts(fileparts(mfilename('fullpath'))); end
  P = periodos();
  saida = fullfile(raiz, 'docs', 'cubo');
  if exist(saida, 'dir') ~= 7, mkdir(saida); end
  velhos = dir(fullfile(saida, '*.js'));
  for i = 1:numel(velhos), delete(fullfile(saida, velhos(i).name)); end
  NT = {'DP', 'DQ', 'PR', 'CB', 'CQ'};
  lst = dir(fullfile(raiz, 'dados', 'cubo', '*_cubo.csv'));
  arquivos = {}; tam = [];
  indice = struct();

  for i = 1:numel(lst)
    t = regexp(lst(i).name, '^(\d{4})_([A-Z]+)_cubo\.csv$', 'tokens', 'once');
    if isempty(t), continue; end
    fonte = t{2};
    fid = fopen(fullfile(lst(i).folder, lst(i).name)); fgetl(fid);
    C = textscan(fid, '%f %f %f %f %f %f %f', 'Delimiter', ','); fclose(fid);
    if ~isfield(indice, fonte), indice.(fonte) = zeros(0, 7); end
    indice.(fonte) = [indice.(fonte); [C{:}]];
  end
  fontes = fieldnames(indice);
  for f = 1:numel(fontes)
    X = indice.(fontes{f});
    [k, ~, j] = unique(X(:, 1:5), 'rows');                 % soma anos repetidos
    X = [k, accumarray(j, X(:, 6)), accumarray(j, X(:, 7))];
    cods = cell(rows(X), 1);
    pr = X(:, 2) == 3;
    cods(~pr) = decodifica_cid(X(~pr, 3));
    cods(pr) = arrayfun(@(x) sprintf('%010d', x), X(pr, 3), 'UniformOutput', false);
    chave = cellfun(@(c) c(1), cods, 'UniformOutput', false);
    chave(pr) = cellfun(@(c) c(1:4), cods(pr), 'UniformOutput', false);
    idx_lin = {};
    for tp = unique(X(:, 2))'
      mt = X(:, 2) == tp;
      for kk = unique(chave(mt))'
        m = mt & strcmp(chave, kk{1});
        nome = sprintf('%s_%s_%s', fontes{f}, NT{tp}, kk{1});
        arq = fullfile(saida, [nome '.js']);
        fid = fopen(arq, 'w');
        fprintf(fid, 'CUBO_ADD("%s","', nome);
        L = X(m, :); cm = cods(m);
        for r = 1:rows(L)
          fprintf(fid, '%s,%d,%d,%d,%d,%d\\n', cm{r}, L(r, 1), L(r, 4), L(r, 5), L(r, 6), L(r, 7));
        end
        fprintf(fid, '");\n');
        fclose(fid);
        d = dir(arq); arquivos{end + 1} = nome; tam(end + 1) = d.bytes; %#ok<AGROW>
      end
      % indice: total por codigo neste tipo
      [uc, ~, j] = unique(cods(mt));
      tot = accumarray(j, X(mt, 6));
      idx_lin{end + 1} = sprintf('"%s":{%s}', NT{tp}, strjoin(cellfun(@(c, n) sprintf('"%s":%d', c, n), ...
                          uc, num2cell(tot), 'UniformOutput', false), ',')); %#ok<AGROW>
    end
    fid = fopen(fullfile(saida, sprintf('indice_%s.js', fontes{f})), 'w');
    fprintf(fid, 'INDICE_ADD("%s",{%s});\n', fontes{f}, strjoin(idx_lin, ','));
    fclose(fid);
    printf('consolida_cubo: %s - %d linhas\n', fontes{f}, rows(X));
  end

  escreve_meta(raiz, saida, P, fontes, arquivos, tam);
  escreve_nomes(raiz, saida);
end

% ------------------------------------------------------------------------
function escreve_meta(raiz, saida, P, fontes, arquivos, tam)
  rot = faixa_rotulos();
  fid = fopen(fullfile(saida, 'meta.js'), 'w');
  fprintf(fid, '// Gerado por octave/consolida_cubo.m. Nao editar.\nwindow.META = {\n');
  fprintf(fid, '"gerado":"%s",\n', datestr(now, 'yyyy-mm-dd'));
  fprintf(fid, '"pre":[%s],"transicao":[%s],"pos":[%s],"incluir_parciais":%d,"simetrico":%d,\n', lista(P.pre), lista(P.transicao), lista(P.pos), P.incluir_parciais, P.simetrico);
  fprintf(fid, '"faixas":["%s"],\n', strjoin(rot, '","'));
  fprintf(fid, '"fontes":["%s"],\n', strjoin(fontes', '","'));
  % meses de cobertura por base/ano (de dados/anual.csv)
  fprintf(fid, '"meses":{');
  arq = fullfile(raiz, 'dados', 'anual.csv');
  if exist(arq, 'file') == 2
    f2 = fopen(arq); h = strsplit(fgetl(f2), ',');
    N = textscan(f2, ['%s %s %s' repmat(' %f', 1, numel(h) - 3)], 'Delimiter', ','); fclose(f2);
    cm = find(strcmp(h, 'meses'));
    partes = {};
    for f = 1:numel(fontes)
      m = strcmp(N{1}, fontes{f});
      anos = unique(N{4}(m));
      v = arrayfun(@(a) max(N{cm}(m & N{4} == a)), anos);
      partes{end + 1} = sprintf('"%s":{%s}', fontes{f}, strjoin(arrayfun(@(a, x) sprintf('"%d":%d', a, x), anos, v, 'UniformOutput', false), ',')); %#ok<AGROW>
    end
    fprintf(fid, '%s', strjoin(partes, ','));
  end
  fprintf(fid, '},\n');
  % populacao Brasil por ano -> sexo -> faixas
  fprintf(fid, '"pop":{');
  arq = fullfile(raiz, 'dados', 'populacao_sexo_faixa.csv');
  if exist(arq, 'file') == 2
    f2 = fopen(arq); fgetl(f2);
    C = textscan(f2, '%s %f %s %s %f', 'Delimiter', ','); fclose(f2);
    br = strcmp(C{1}, 'BR');
    partes = {};
    for a = unique(C{2}(br))'
      ps = {};
      for sx = {'M', 'F'}
        v = zeros(1, numel(rot));
        for k = 1:numel(rot)
          x = C{5}(br & C{2} == a & strcmp(C{3}, sx{1}) & strcmp(C{4}, rot{k}));
          if ~isempty(x), v(k) = x(1); end
        end
        ps{end + 1} = sprintf('"%s":[%s]', sx{1}, strjoin(arrayfun(@(x) sprintf('%d', x), v, 'UniformOutput', false), ',')); %#ok<AGROW>
      end
      partes{end + 1} = sprintf('"%d":{%s}', a, strjoin(ps, ',')); %#ok<AGROW>
    end
    fprintf(fid, '%s', strjoin(partes, ','));
  end
  fprintf(fid, '},\n');
  fprintf(fid, '"arquivos":{%s}\n};\n', strjoin(cellfun(@(a, t) sprintf('"%s":%d', a, t), arquivos, num2cell(tam), 'UniformOutput', false), ','));
  fclose(fid);
end

function s = lista(v)
  s = strjoin(arrayfun(@(x) sprintf('%d', x), v, 'UniformOutput', false), ',');
end

% ------------------------------------------------------------------------
function escreve_nomes(raiz, saida)
  dirt = fullfile(raiz, 'dados', 'tabelas');
  nomes = {}; descr = {};
  arq = fullfile(dirt, 'CID10.DBF');
  if exist(arq, 'file') == 2
    try
      T = ler_dbf(arq);
      cmp = fieldnames(T.dados);
      kc = cmp(find(~cellfun(@isempty, regexp(cmp, '^(CID|SUBCAT|COD)', 'once')), 1));
      kd = cmp(find(~cellfun(@isempty, regexp(cmp, '^(DESCR|DESC|NOME)', 'once')), 1));
      if ~isempty(kc) && ~isempty(kd)
        c = strrep(strtrim(cellstr(T.dados.(kc{1}))), '.', '');
        d = cellfun(@latin1, strtrim(cellstr(T.dados.(kd{1}))), 'UniformOutput', false);
        nomes = [nomes; c]; descr = [descr; d];
      end
    catch e
      warning('consolida_cubo: CID10.DBF ilegivel (%s)', e.message);
    end
  end
  arq = fullfile(dirt, 'tb_procedimento.txt');
  if exist(arq, 'file') == 2
    L = strsplit(fileread(arq), "\n");
    L = L(cellfun(@numel, L) > 12);
    c = cellfun(@(x) x(1:10), L, 'UniformOutput', false)';
    d = cellfun(@(x) strtrim(latin1(x(11:min(end, 260)))), L, 'UniformOutput', false)';
    ok = ~cellfun(@isempty, regexp(c, '^\d{10}$', 'once'));
    nomes = [nomes; c(ok)]; descr = [descr; d(ok)];
  end
  fid = fopen(fullfile(saida, 'nomes.js'), 'w');
  fprintf(fid, 'window.NOMES = {');
  for i = 1:numel(nomes)
    d = strrep(strrep(descr{i}, '\', '\\'), '"', '\"');
    if i > 1, fprintf(fid, ','); end
    fprintf(fid, '"%s":"%s"', nomes{i}, d);
  end
  fprintf(fid, '};\n');
  fclose(fid);
  printf('consolida_cubo: %d nomes de codigos\n', numel(nomes));
end

function s = latin1(s)
  % DATASUS grava texto em ISO-8859-1; converte para UTF-8
  if isempty(s), return; end
  try
    s = native2unicode(uint8(s(:)'), 'ISO-8859-1');
  catch
  end
end
