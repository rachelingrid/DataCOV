function monta_populacao(raiz)
% MONTA_POPULACAO  Gera dados/populacao_uf.csv a partir dos JSON do SIDRA.
%
% Prioridade de cada valor (uf, ano):
%   1. config/populacao_manual.csv  (se existir; colunas uf,ano,populacao)
%   2. estimativa anual IBGE (tabela 6579)          origem = estimativa
%   3. Censo 2022 (tabela 4709)                      origem = censo
%   4. interpolacao linear entre anos conhecidos     origem = interpolado
%   5. extrapolacao pela tendencia dos 2 ultimos anos conhecidos
%                                                    origem = extrapolado
  if nargin < 1, raiz = fileparts(fileparts(mfilename('fullpath'))); end
  P = periodos();
  anos = P.anos(:)';
  ufs = {'BR','RO','AC','AM','RR','PA','AP','TO','MA','PI','CE','RN','PB','PE','AL', ...
         'SE','BA','MG','ES','RJ','SP','PR','SC','RS','MS','MT','GO','DF'};
  cods = [1 11 12 13 14 15 16 17 21 22 23 24 25 26 27 28 29 31 32 33 35 41 42 43 50 51 52 53];
  pop = nan(numel(ufs), numel(anos));
  ori = repmat({''}, numel(ufs), numel(anos));

  dirp = fullfile(raiz, 'dados', 'populacao');
  [pop, ori] = aplica(pop, ori, le_sidra(fullfile(dirp, 'sidra_4709.json')), cods, anos, 'censo');
  [pop, ori] = aplica(pop, ori, le_sidra(fullfile(dirp, 'sidra_6579.json')), cods, anos, 'estimativa');
  man = fullfile(raiz, 'config', 'populacao_manual.csv');
  if exist(man, 'file') == 2
    fid = fopen(man); fgetl(fid);
    C = textscan(fid, '%s %f %f', 'Delimiter', ','); fclose(fid);
    [~, iu] = ismember(upper(strtrim(C{1})), ufs);
    [~, ia] = ismember(C{2}, anos);
    for k = find(iu > 0 & ia > 0)'
      pop(iu(k), ia(k)) = C{3}(k); ori{iu(k), ia(k)} = 'manual';
    end
  end

  % preenche lacunas
  for i = 1:numel(ufs)
    ok = ~isnan(pop(i, :));
    if sum(ok) < 2, continue; end
    a = anos(ok); v = pop(i, ok);
    for j = find(~ok)
      if anos(j) > a(1) && anos(j) < a(end)
        pop(i, j) = interp1(a, v, anos(j), 'linear'); ori{i, j} = 'interpolado';
      elseif anos(j) > a(end)
        pop(i, j) = v(end) + (v(end) - v(end-1)) / (a(end) - a(end-1)) * (anos(j) - a(end));
        ori{i, j} = 'extrapolado';
      else
        pop(i, j) = v(1) - (v(2) - v(1)) / (a(2) - a(1)) * (a(1) - anos(j));
        ori{i, j} = 'extrapolado';
      end
    end
  end

  if all(isnan(pop(:)))
    error('monta_populacao: nenhum dado de populacao (JSON ausente e sem populacao_manual.csv)');
  end
  arq = fullfile(raiz, 'dados', 'populacao_uf.csv');
  fid = fopen(arq, 'w');
  fprintf(fid, 'uf,ano,populacao,origem\n');
  for i = 1:numel(ufs)
    for j = 1:numel(anos)
      if ~isnan(pop(i, j))
        fprintf(fid, '%s,%d,%d,%s\n', ufs{i}, anos(j), round(pop(i, j)), ori{i, j});
      end
    end
  end
  fclose(fid);
  printf('monta_populacao: %s\n', arq);
end

function [pop, ori] = aplica(pop, ori, S, cods, anos, origem)
  for k = 1:numel(S.cod)
    i = find(cods == S.cod(k), 1); j = find(anos == S.ano(k), 1);
    if isempty(i) || isempty(j) || isnan(S.val(k)), continue; end
    pop(i, j) = S.val(k); ori{i, j} = origem;
  end
end

function S = le_sidra(arq)
% Le a resposta JSON da API /values do SIDRA. A primeira linha e o
% cabecalho; as colunas de territorio e ano sao achadas pelo nome.
  S = struct('cod', [], 'ano', [], 'val', []);
  if exist(arq, 'file') ~= 2, warning('le_sidra: %s ausente', arq); return; end
  J = jsondecode(fileread(arq));
  if iscell(J), J = [J{:}]; end
  if numel(J) < 2, return; end
  cab = J(1); campos = fieldnames(cab);
  kano = ''; kter = '';
  for c = campos'
    nome = cab.(c{1});
    % cabecalho das colunas de codigo: 'Ano (Codigo)', 'Brasil e Unidade da Federacao (Codigo)'
    if ~ischar(nome) || isempty(regexp(c{1}, '^D\dC$', 'once')), continue; end
    if ~isempty(regexp(nome, '^Ano\>', 'once')), kano = c{1}; end
    if ~isempty(regexpi(nome, 'Unidade da Federa|^Brasil')), kter = c{1}; end
  end
  if isempty(kano) || isempty(kter)
    warning('le_sidra: cabecalho inesperado em %s', arq); return;
  end
  L = J(2:end);
  S.cod = str2double({L.(kter)})';
  S.ano = str2double({L.(kano)})';
  S.val = str2double({L.V})';           % '...' ou '-' viram NaN
end
