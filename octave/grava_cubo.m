function grava_cubo(R, arq)
% GRAVA_CUBO  Conta registros por (ano, tipo, codigo, sexo, faixa) para
% QUALQUER CID-10 ou procedimento, e acrescenta ao CSV numerico ARQ.
%
% R.cubo.<TIPO> e uma matriz char com os codigos de cada registro:
%   DP  diagnostico principal (SIH)      um codigo por registro
%   DQ  qualquer diagnostico (SIH)        varios campos juntos com '*'
%   PR  procedimento realizado (SIH)      codigo SIGTAP de 10 digitos
%   CB  causa basica (SIM)                um codigo por registro
%   CQ  qualquer mencao no atestado (SIM) linhas A-D e II juntas com '*'
% Em DQ e CQ cada codigo conta no maximo 1 vez por registro.
%
% Colunas: ano,tipo,cod,sexo,faixa,n,obitos
%   tipo: 1=DP 2=DQ 3=PR 4=CB 5=CQ   sexo: 1=M 2=F 3=ignorado
%   cod : CID codificado por CODIFICA_CID; procedimento = numero de 10 digitos
% Use COMPACTA_CUBO para somar linhas repetidas entre arquivos.
  if ~isfield(R, 'cubo'), return; end
  tipos = struct('DP', 1, 'DQ', 2, 'PR', 3, 'CB', 4, 'CQ', 5);
  sx = 3 * ones(R.n, 1); sx(R.sexo == 'M') = 1; sx(R.sexo == 'F') = 2;
  linhas = zeros(0, 7);
  campos = fieldnames(R.cubo);
  for i = 1:numel(campos)
    t = tipos.(campos{i});
    M = R.cubo.(campos{i});
    if t == 3
      reg = (1:R.n)';
      cod = num_char(M(:, 1:min(10, columns(M))));
      ok = ~isnan(cod) & cod > 0;
      reg = reg(ok); cod = cod(ok);
    else
      [reg, cod] = extrai_cids(M);
    end
    if isempty(reg), continue; end
    % um codigo por registro (dedup) e agregacao
    [u, ~] = unique([reg, cod], 'rows');
    reg = u(:, 1); cod = u(:, 2);
    K = [R.ano(reg), repmat(t, numel(reg), 1), cod, sx(reg), R.faixa(reg)];
    [k, ~, j] = unique(K, 'rows');
    n = accumarray(j, 1);
    ob = accumarray(j, double(R.obito(reg)));
    linhas = [linhas; k, n, ob]; %#ok<AGROW>
  end
  novo = exist(arq, 'file') ~= 2;
  fid = fopen(arq, 'a');
  if novo, fprintf(fid, 'ano,tipo,cod,sexo,faixa,n,obitos\n'); end
  fprintf(fid, '%d,%d,%d,%d,%d,%d,%d\n', linhas');
  fclose(fid);
end

function [reg, cod] = extrai_cids(M)
  % todos os codigos que comecam apos '*' (ou no inicio do campo)
  n = rows(M);
  M = upper([repmat('*', n, 1), M, repmat(' ', n, 4)]);
  M(M == '.') = ' ';
  [r, c] = find(M(:, 1:end-4) == '*');
  if isempty(r), reg = []; cod = []; return; end
  C = [M(sub2ind(size(M), r, c + 1)), M(sub2ind(size(M), r, c + 2)), ...
       M(sub2ind(size(M), r, c + 3)), M(sub2ind(size(M), r, c + 4))];
  cod = codifica_cid(C);
  ok = ~isnan(cod);
  reg = r(ok); cod = cod(ok);
end
