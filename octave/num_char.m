function v = num_char(M)
% NUM_CHAR  Converte matriz char de inteiros (n x w) em vetor double.
% Vetorizado; campos em branco ou nao numericos viram NaN.
  n = rows(M);
  if n == 0
    v = zeros(0, 1);
    return;
  end
  M = strjust(M, 'right');
  dig = M >= '0' & M <= '9';
  esp = M == ' ';
  ok = all(dig | esp, 2) & any(dig, 2);
  d = double(M - '0') .* dig;
  w = columns(M);
  pot = 10 .^ (w-1:-1:0);
  v = d * pot';
  v(~ok) = NaN;
end
