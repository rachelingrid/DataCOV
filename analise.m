% ANALISE  Exploracao offline dos dados ja baixados (rode no Octave, na pasta
% do repositorio). Nao precisa de internet.
%
%   >> analise
%
% Edite as tres linhas abaixo para trocar o recorte.
fonte  = 'SIH';          % 'SIM' (obitos), 'SIH' (internacoes), 'DOFET' (natimortos)
grupo  = 'TEV';          % TROMBOSE, EMBOLIA, TEV, GESTANTE, AMPUTACAO, NATIMORTO_TRI3...
uf     = 'BR';           % BR ou sigla da UF
medida = 'n_qualquer';   % n_qualquer, n_principal, obitos_qualquer, obitos_principal

addpath('octave', 'config');
P = periodos();
arq = fullfile('dados', 'anual.csv');
if exist(arq, 'file') ~= 2
  error('Ainda nao ha dados. Rode o workflow no GitHub e faca git pull.');
end
fid = fopen(arq); fgetl(fid);
C = textscan(fid, '%s %s %s %f %f %f %f %f %f %f', 'Delimiter', ',');
fclose(fid);
cols = {'n_qualquer', 'n_principal', 'obitos_qualquer', 'obitos_principal'};
m = strcmp(C{1}, fonte) & strcmp(C{2}, grupo) & strcmp(C{3}, uf);
if ~any(m)
  error('Sem linhas para %s / %s / %s', fonte, grupo, uf);
end
ano = C{4}(m);
v = C{4 + find(strcmp(cols, medida))}(m);
meses = C{9}(m); prel = C{10}(m);
[ano, o] = sort(ano); v = v(o); meses = meses(o); prel = prel(o);

printf('\n%s | %s | %s | %s\n', fonte, grupo, uf, medida);
printf('%6s %10s %6s %s\n', 'ano', 'valor', 'meses', 'obs');
for i = 1:numel(ano)
  obs = '';
  if meses(i) < 12, obs = 'parcial'; end
  if prel(i), obs = [obs ' preliminar']; end
  printf('%6d %10d %6d %s\n', ano(i), v(i), meses(i), obs);
end
ok = meses >= 12 | P.incluir_parciais;
[jpre, jpos] = janela_simetrica(ano(ok & ~ismember(ano, P.transicao)), P);
mpre = mean(v(ismember(ano, jpre)));
mpos = mean(v(ismember(ano, jpos)));
printf('\nMedia antes (%d-%d): %.1f\n', jpre(1), jpre(end), mpre);
printf('Media depois (%d-%d): %.1f\n', jpos(1), jpos(end), mpos);
printf('Variacao: %+.1f%%\n\n', 100 * (mpos / mpre - 1));

if isempty(available_graphics_toolkits())
  return;  % sem interface grafica (ex.: servidor)
end
figure;
cor = repmat([0.16 0.47 0.84], numel(ano), 1);
cor(ismember(ano, P.transicao), :) = repmat([0.6 0.6 0.56], sum(ismember(ano, P.transicao)), 1);
cor(ismember(ano, P.pos), :) = repmat([0.92 0.41 0.20], sum(ismember(ano, P.pos)), 1);
h = bar(ano, v, 0.6, 'FaceColor', 'flat'); h.CData = cor;
title(sprintf('%s - %s - %s', grupo, medida, uf), 'Interpreter', 'none');
xlabel('Ano'); grid on;
