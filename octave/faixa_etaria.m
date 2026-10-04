function f = faixa_etaria(idade)
% FAIXA_ETARIA  Indice de faixa etaria (1..12) a partir da idade em anos.
%   1=00-09 2=10-19 ... 9=80-89 10=90+ 11=(reservado) 12=ignorado
% Os rotulos estao em FAIXA_ROTULOS.
  idade = idade(:);
  f = min(floor(idade / 10) + 1, 10);
  f(isnan(idade) | idade < 0) = 12;
end
