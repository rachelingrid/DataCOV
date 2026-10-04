function [pre, pos] = janela_simetrica(anos_ok, P)
% JANELA_SIMETRICA  Anos da comparacao antes x depois.
%   anos_ok  anos com dados completos (sem 2020)
% Com P.simetrico = true: "depois" = anos completos apos a pandemia (k anos);
% "antes" = os k anos imediatamente anteriores a 2020. Se houver menos anos
% antes do que depois, o "depois" e cortado para ficar com o mesmo tamanho.
%   Ex.: depois 2021-2025 (5) -> antes 2015-2019 (5).
% Com P.simetrico = false: todos os anos de P.pre e de P.pos disponiveis.
% A serie interrompida (tendencia) usa sempre todos os anos disponiveis.
  pre = intersect(P.pre, anos_ok);
  pos = intersect(P.pos, anos_ok);
  if isfield(P, 'simetrico') && P.simetrico
    k = min(numel(pre), numel(pos));
    pre = pre(end - k + 1:end);
    pos = pos(1:k);
  end
  pre = pre(:)'; pos = pos(:)';
end
