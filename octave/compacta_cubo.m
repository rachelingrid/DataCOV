function compacta_cubo(arq)
% COMPACTA_CUBO  Soma linhas repetidas do cubo (mesmo ano, tipo, codigo,
% sexo e faixa vindos de arquivos diferentes) e regrava ARQ.
  if exist(arq, 'file') ~= 2, return; end
  fid = fopen(arq); fgetl(fid);
  C = textscan(fid, '%f %f %f %f %f %f %f', 'Delimiter', ','); fclose(fid);
  K = [C{1:5}];
  if isempty(K), return; end
  [k, ~, j] = unique(K, 'rows');
  n = accumarray(j, C{6}); ob = accumarray(j, C{7});
  fid = fopen(arq, 'w');
  fprintf(fid, 'ano,tipo,cod,sexo,faixa,n,obitos\n');
  fprintf(fid, '%d,%d,%d,%d,%d,%d,%d\n', [k, n, ob]');
  fclose(fid);
end
