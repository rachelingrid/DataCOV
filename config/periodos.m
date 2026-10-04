function P = periodos()
% PERIODOS  Anos analisados e definicao de pre/pos pandemia.
  P.pre        = 2014:2019;     % pre-pandemia
  P.transicao  = 2020;          % ano da pandemia: fora das medias e dos testes
  P.pos        = 2021:2026;     % pos-pandemia
  P.anos       = [P.pre, P.transicao, P.pos];
  % Anos com menos de 12 meses de dados (ex.: 2026 no SIH) entram nas
  % medias apenas se true. Com false, aparecem nas tabelas mas sao
  % excluidos das medias e da razao pos/pre.
  P.incluir_parciais = false;
  % Comparacao simetrica: k anos antes x k anos depois de 2020, onde k =
  % numero de anos completos depois (ver octave/janela_simetrica.m).
  % Hoje: 2015-2019 x 2021-2025. A tendencia usa todos os anos de P.pre.
  P.simetrico = true;
end
