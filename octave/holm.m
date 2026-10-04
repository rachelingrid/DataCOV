function pa = holm(p)
% HOLM  p-valores ajustados por Holm-Bonferroni (NaN ignorados).
  pa = nan(size(p));
  ok = find(~isnan(p));
  m = numel(ok);
  if m == 0, return; end
  [ps, o] = sort(p(ok));
  adj = min(1, cummax((m - (1:m)' + 1) .* ps(:)));
  pa(ok(o)) = adj;
end
