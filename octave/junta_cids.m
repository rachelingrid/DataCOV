function M = junta_cids(varargin)
% JUNTA_CIDS  Concatena varios campos de CID (matrizes char n x w) numa unica
% matriz separada por '*', pronta para CID_MENCAO.
%   M = junta_cids(D.DIAG_PRINC, D.DIAG_SECUN, D.DIAGSEC1, ...)
  n = rows(varargin{1});
  partes = cell(1, 2 * nargin);
  for i = 1:nargin
    c = varargin{i};
    if rows(c) ~= n
      c = repmat(' ', n, 1);
    end
    partes{2*i-1} = repmat('*', n, 1);
    partes{2*i} = c;
  end
  M = [partes{:}];
end
