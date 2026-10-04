function s = decodifica_cid(v)
% DECODIFICA_CID  Inverso de CODIFICA_CID: inteiro -> cellstr 'I802' / 'I26'.
  v = v(:);
  L = floor(v / 1100); r = v - L * 1100;
  dd = floor(r / 11); q = r - dd * 11;
  s = cell(numel(v), 1);
  for i = 1:numel(v)
    if q(i) == 10
      s{i} = sprintf('%c%02d', char('A' + L(i)), dd(i));
    else
      s{i} = sprintf('%c%02d%d', char('A' + L(i)), dd(i), q(i));
    end
  end
end
