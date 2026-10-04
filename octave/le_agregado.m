function A = le_agregado(arquivos)
% LE_AGREGADO  Le um ou mais CSVs gerados por PROCESSA_ARQUIVO.
% Retorna struct de colunas (cellstr para texto, double para numeros).
  if ischar(arquivos), arquivos = {arquivos}; end
  txt = {'fonte', 'uf', 'sexo', 'faixa', 'grupo'};
  num = {'ano', 'mes', 'preliminar', 'n_qualquer', 'n_principal', 'obitos_qualquer', 'obitos_principal'};
  for c = [txt num], A.(c{1}) = []; end
  for c = txt, A.(c{1}) = {}; end
  for i = 1:numel(arquivos)
    fid = fopen(arquivos{i}, 'r');
    if fid < 0, warning('le_agregado: nao abri %s', arquivos{i}); continue; end
    cab = fgetl(fid);
    if ~ischar(cab), fclose(fid); continue; end
    C = textscan(fid, '%s %f %f %s %s %s %s %f %f %f %f %f', 'Delimiter', ',');
    fclose(fid);
    A.fonte = [A.fonte; C{1}];
    A.ano = [A.ano; C{2}];
    A.mes = [A.mes; C{3}];
    A.uf = [A.uf; C{4}];
    A.sexo = [A.sexo; C{5}];
    A.faixa = [A.faixa; C{6}];
    A.grupo = [A.grupo; C{7}];
    A.preliminar = [A.preliminar; C{8}];
    A.n_qualquer = [A.n_qualquer; C{9}];
    A.n_principal = [A.n_principal; C{10}];
    A.obitos_qualquer = [A.obitos_qualquer; C{11}];
    A.obitos_principal = [A.obitos_principal; C{12}];
  end
end
