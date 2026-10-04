function p = t_pvalor(t, df)
% T_PVALOR  p bicaudal da distribuicao t de Student (Octave puro).
  p = betainc(df ./ (df + t .^ 2), df / 2, 0.5);
end
