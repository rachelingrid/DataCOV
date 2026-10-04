function F = glm_poisson(X, y, offset)
% GLM_POISSON  Regressao de Poisson com offset (log-link), ajustada por IRLS,
% com correcao de sobredispersao (quasi-Poisson).
%
%   F = glm_poisson(X, y, offset)
%     X       n x p matriz de desenho (inclua a coluna de 1s)
%     y       n x 1 contagens
%     offset  n x 1 log da exposicao (ex.: log(populacao))
%   F.b     coeficientes            F.V    covariancia (ja x phi)
%   F.phi   dispersao (>= 1)        F.df   graus de liberdade residuais
%   F.ok    false se nao convergiu ou dados insuficientes
% Erros-padrao multiplicados por sqrt(phi): a variacao entre anos maior que
% a de Poisson nao infla falsamente a significancia.
  y = y(:); offset = offset(:);
  [n, p] = size(X);
  F = struct('b', nan(p, 1), 'V', nan(p), 'phi', NaN, 'df', n - p, 'ok', false, 'mu', nan(n, 1));
  if n <= p || sum(y) == 0 || any(~isfinite(offset))
    return;
  end
  mu = y + 0.5;
  eta = log(mu);
  b = zeros(p, 1);
  for it = 1:100
    z = eta - offset + (y - mu) ./ mu;
    W = mu;
    XtW = X' .* W';
    bn = (XtW * X) \ (XtW * z);
    eta = X * bn + offset;
    mu = exp(eta);
    if max(abs(bn - b)) < 1e-10
      b = bn; break;
    end
    b = bn;
  end
  if any(~isfinite(b)), return; end
  I = (X' .* mu') * X;
  if rcond(I) < 1e-12, return; end
  pearson = sum((y - mu) .^ 2 ./ mu);
  F.df = n - p;
  F.phi = max(1, pearson / F.df);
  F.b = b;
  F.V = inv(I) * F.phi;
  F.mu = mu;
  F.ok = true;
end
