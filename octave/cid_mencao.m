function hit = cid_mencao(M, prefixos)
% CID_MENCAO  Verdadeiro para cada linha de M que contem algum codigo
% comecando por um dos prefixos.
%
%   M        matriz char (n x w). Pode ser um campo simples ("I269") ou uma
%            linha de atestado do SIM ("*I269*J189"). Use JUNTA_CIDS para
%            combinar varios campos.
%   prefixos cellstr de prefixos sem ponto: {'I26','O223','I80'}
%
% O casamento e ancorado no inicio de cada codigo (apos '*'), entao 'I26'
% nao casa com 'XI26'. Vetorizado: custo ~ n * w * numel(prefixos).

  n = rows(M);
  hit = false(n, 1);
  if n == 0 || isempty(prefixos)
    return;
  end
  M = upper([repmat('*', n, 1), M]);
  M(M == '.') = ' ';                % tolera codigos digitados com ponto
  w = columns(M);
  prefixos = cellstr(prefixos);
  % agrupa prefixos por tamanho para reduzir passadas
  tam = cellfun(@numel, prefixos);
  for L = unique(tam(:))'
    P = [repmat('*', sum(tam == L), 1), char(prefixos(tam == L))];  % k x (L+1)
    for k = 1:(w - L)
      bloco = M(:, k:k+L);
      if ~any(bloco(:, 1) == '*')
        continue;
      end
      for p = 1:rows(P)
        hit = hit | all(bloco == P(p, :), 2);
      end
    end
  end
end
