function s = uf_sigla(codmun)
% UF_SIGLA  Converte codigo de municipio IBGE (char n x >=2) em sigla da UF.
% Codigos desconhecidos viram 'IG' (ignorado).
  tab = repmat({'IG'}, 1, 99);
  cods = [11 12 13 14 15 16 17 21 22 23 24 25 26 27 28 29 31 32 33 35 41 42 43 50 51 52 53];
  sig = {'RO','AC','AM','RR','PA','AP','TO','MA','PI','CE','RN','PB','PE','AL', ...
         'SE','BA','MG','ES','RJ','SP','PR','SC','RS','MS','MT','GO','DF'};
  tab(cods) = sig;
  n = rows(codmun);
  if columns(codmun) < 2
    s = repmat({'IG'}, n, 1);
    return;
  end
  c = num_char(codmun(:, 1:2));
  c(isnan(c) | c < 1 | c > 99) = 99;
  s = tab(c)';
  s = s(:);
end
