function v = codifica_cid(C)
% CODIFICA_CID  Codigo CID-10 (matriz char n x >=3, ex. 'I802', 'I26X',
% 'J18 ') -> inteiro, para guardar o cubo em CSV numerico compacto.
%   v = letra*1100 + dois_digitos*11 + quarto
%   letra A=0..Z=25; quarto = 0..9, ou 10 quando nao ha 4o digito ('X',' ').
% Codigos invalidos -> NaN. Inverso: DECODIFICA_CID.
  n = rows(C);
  if columns(C) < 4, C = [C, repmat(' ', n, 4 - columns(C))]; end
  L = double(C(:, 1)) - double('A');
  d1 = double(C(:, 2)) - 48; d2 = double(C(:, 3)) - 48; d4 = double(C(:, 4)) - 48;
  ok = L >= 0 & L <= 25 & d1 >= 0 & d1 <= 9 & d2 >= 0 & d2 <= 9;
  q = d4;
  q(d4 < 0 | d4 > 9) = 10;
  v = L * 1100 + (d1 * 10 + d2) * 11 + q;
  v(~ok) = NaN;
end
