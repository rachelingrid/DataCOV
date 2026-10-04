function q = t_quantil(pr, df)
% T_QUANTIL  Quantil da t de Student para pr em (0.5, 1). Ex.: t_quantil(0.975, 9)
  f = @(x) (1 - 0.5 * betainc(df / (df + x ^ 2), df / 2, 0.5)) - pr;
  q = fzero(f, [0, 1e4]);
end
