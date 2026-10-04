function monta_populacao_faixa(raiz)
% MONTA_POPULACAO_FAIXA  Gera dados/populacao_sexo_faixa.csv
% (uf, ano, sexo, faixa, populacao) a partir de:
%   1. config/populacao_faixa_manual.csv  (prioridade; mesmas colunas)
%   2. dados/populacao/pop_sexo_idade.csv (IBGE, idade simples; gerado por
%      scripts/coleta_populacao.sh)
% As idades simples sao somadas nas faixas de FAIXA_ETARIA. Categorias
% agrupadas da tabela (ex.: "0 a 4 anos") e totais sao ignorados para nao
% contar duas vezes.
  if nargin < 1, raiz = fileparts(fileparts(mfilename('fullpath'))); end
  rot = faixa_rotulos();
  cods = [1 11 12 13 14 15 16 17 21 22 23 24 25 26 27 28 29 31 32 33 35 41 42 43 50 51 52 53];
  ufs = {'BR','RO','AC','AM','RR','PA','AP','TO','MA','PI','CE','RN','PB','PE','AL', ...
         'SE','BA','MG','ES','RJ','SP','PR','SC','RS','MS','MT','GO','DF'};
  chaves = {}; vals = [];
  M = containers.Map();

  arq = fullfile(raiz, 'dados', 'populacao', 'pop_sexo_idade.csv');
  if exist(arq, 'file') == 2
    txt = strrep(fileread(arq), '"', '');
    C = textscan(txt, '%f %f %s %s %s', 'Delimiter', ',', 'HeaderLines', 1);
    loc = C{1}; ano = C{2}; sexo = C{3}; idade = C{4}; v = str2double(C{5});
    sx = repmat({''}, numel(loc), 1);
    sx(~cellfun(@isempty, regexpi(sexo, '^(homens|masculino)'))) = {'M'};
    sx(~cellfun(@isempty, regexpi(sexo, '^(mulheres|feminino)'))) = {'F'};
    [anos_idade, aberta] = interpreta_idade(idade);
    % categorias "N anos ou mais" so entram acima da maior idade simples
    maxsimples = max([anos_idade(~aberta & ~isnan(anos_idade)); -1]);
    usa = ~isnan(anos_idade) & (~aberta | anos_idade > maxsimples);
    [ok, iu] = ismember(loc, cods);
    sel = usa & ok & ~cellfun(@isempty, sx) & ~isnan(v);
    fx = faixa_etaria(anos_idade);
    for k = find(sel)'
      c = sprintf('%s|%d|%s|%s', ufs{iu(k)}, ano(k), sx{k}, rot{fx(k)});
      if isKey(M, c), M(c) = M(c) + v(k); else, M(c) = v(k); end
    end
    printf('monta_populacao_faixa: %d linhas IBGE usadas (maior idade simples: %d)\n', sum(sel), maxsimples);
  else
    warning('monta_populacao_faixa: %s ausente', arq);
  end

  man = fullfile(raiz, 'config', 'populacao_faixa_manual.csv');
  if exist(man, 'file') == 2
    fid = fopen(man); fgetl(fid);
    C = textscan(fid, '%s %f %s %s %f', 'Delimiter', ','); fclose(fid);
    for k = 1:numel(C{1})
      M(sprintf('%s|%d|%s|%s', upper(strtrim(C{1}{k})), C{2}(k), upper(strtrim(C{3}{k})), strtrim(C{4}{k}))) = C{5}(k);
    end
    printf('monta_populacao_faixa: %d linhas manuais aplicadas\n', numel(C{1}));
  end

  if M.Count == 0
    warning('monta_populacao_faixa: sem dados - taxas por faixa nao serao calculadas');
    return;
  end
  k = sort(keys(M));
  fid = fopen(fullfile(raiz, 'dados', 'populacao_sexo_faixa.csv'), 'w');
  fprintf(fid, 'uf,ano,sexo,faixa,populacao\n');
  for i = 1:numel(k)
    p = strsplit(k{i}, '|');
    fprintf(fid, '%s,%s,%s,%s,%d\n', p{1}, p{2}, p{3}, p{4}, round(M(k{i})));
  end
  fclose(fid);
end

function [a, aberta] = interpreta_idade(nomes)
  n = numel(nomes);
  a = nan(n, 1); aberta = false(n, 1);
  for i = 1:n
    s = lower(strtrim(nomes{i}));
    if ~isempty(regexp(s, '^menos de 1 ano', 'once'))
      a(i) = 0;
    elseif ~isempty(regexp(s, '^\d+ anos? ou mais$', 'once'))
      a(i) = sscanf(s, '%d'); aberta(i) = true;
    elseif ~isempty(regexp(s, '^\d+ anos?$', 'once'))
      a(i) = sscanf(s, '%d');
    end                          % "0 a 4 anos", "Total" etc. ficam NaN
  end
end
