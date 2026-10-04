function compara_faixas(raiz)
% COMPARA_FAIXAS  Taxas por sexo e faixa etaria, ano a ano, e testes pre x pos.
%
% Para cada fonte x grupo x medida x UF x sexo x faixa (config/analise_faixas.m):
%   taxa anual por milhao de habitantes da MESMA faixa e sexo;
%   2020 fica fora (P.transicao); anos incompletos ficam fora (salvo
%   P.incluir_parciais, quando entram com exposicao proporcional aos meses).
%
% Modelo A - comparacao de periodos (quasi-Poisson, offset log populacao):
%   log taxa = b0 + b1*pos            RR = exp(b1) = taxa pos / taxa pre
% Modelo B - serie interrompida (controla a tendencia que ja existia):
%   log taxa = b0 + b1*t + b2*pos + b3*pos*t,  t = ano - 2020
%   tendencia pre (%/ano) = exp(b1)-1
%   salto em 2021 alem da tendencia: RR = exp(b2 + b3)
%   mudanca de inclinacao: exp(b3)
% p-valores pela t de Student com df residuais; ajuste de Holm dentro de
% cada familia (fonte x grupo x medida x UF) sobre os estratos sexo x faixa.
%
% Saidas: dados/faixas_anual.csv, dados/faixas_teste.csv,
%         dados/faixas_ano_vs_pre.csv, docs/faixas.js
  if nargin < 1, raiz = fileparts(fileparts(mfilename('fullpath'))); end
  P = periodos(); A = analise_faixas();

  arqpop = fullfile(raiz, 'dados', 'populacao_sexo_faixa.csv');
  if exist(arqpop, 'file') ~= 2
    warning('compara_faixas: %s ausente - analise por faixa nao gerada', arqpop);
    return;
  end
  fid = fopen(arqpop); fgetl(fid);
  Cp = textscan(fid, '%s %f %s %s %f', 'Delimiter', ','); fclose(fid);
  popk = strcat(Cp{1}, '|', num2cellstr(Cp{2}), '|', Cp{3}, '|', Cp{4});
  popv = Cp{5};

  fid = fopen(fullfile(raiz, 'dados', 'detalhado.csv')); fgetl(fid);
  D = textscan(fid, '%s %s %s %s %s %f %f %f %f %f %f', 'Delimiter', ','); fclose(fid);
  medcol = struct('n_qualquer', 7, 'n_principal', 8, 'obitos_qualquer', 9, 'obitos_principal', 10);

  % meses de cobertura por fonte e ano
  fid = fopen(fullfile(raiz, 'dados', 'anual.csv')); h = strsplit(fgetl(fid), ',');
  N = textscan(fid, ['%s %s %s' repmat(' %f', 1, numel(h) - 3)], 'Delimiter', ','); fclose(fid);
  cm = find(strcmp(h, 'meses'));
  mesesde = @(fonte, ano) max([0; N{cm}(strcmp(N{1}, fonte) & N{4} == ano)]);

  anos = P.anos(:);
  q975 = @(df) t_quantil(1 - A.alfa / 2, df);
  fa = fopen(fullfile(raiz, 'dados', 'faixas_anual.csv'), 'w');
  fprintf(fa, 'fonte,grupo,medida,uf,sexo,faixa,ano,periodo,casos,populacao,taxa_milhao,meses,usado,janela\n');
  ft = {}; fy = {};
  testes = struct('chave', {}, 'v', {});

  for f = 1:numel(A.fontes)
    fonte = A.fontes{f};
    meses = arrayfun(@(a) mesesde(fonte, a), anos);
    for g = 1:numel(A.grupos)
      for md = 1:numel(A.medidas)
        col = medcol.(A.medidas{md});
        for u = 1:numel(A.ufs)
          fam = numel(testes) + 1;
          base = strcmp(D{1}, fonte) & strcmp(D{2}, A.grupos{g}) & strcmp(D{3}, A.ufs{u});
          for s = 1:numel(A.sexos)
            for fx = 1:numel(A.faixas)
              m = base & strcmp(D{4}, A.sexos{s}) & strcmp(D{5}, A.faixas{fx});
              y = zeros(numel(anos), 1);
              [ok, ia] = ismember(D{6}(m), anos);
              vv = D{col}(m);
              y = accumarray(ia(ok), vv(ok), [numel(anos), 1]);
              k = strcat(A.ufs{u}, '|', num2cellstr(anos), '|', A.sexos{s}, '|', A.faixas{fx});
              [okp, ip] = ismember(k, popk);
              pop = nan(numel(anos), 1); pop(okp) = popv(ip(okp));
              expo = pop .* min(meses, 12) / 12;
              per = repmat({'pos'}, numel(anos), 1);
              per(ismember(anos, P.pre)) = {'pre'};
              per(ismember(anos, P.transicao)) = {'pandemia'};
              usado = ~ismember(anos, P.transicao) & meses > 0 & pop > 0 & ...
                      (meses >= 12 | P.incluir_parciais);
              taxa = y ./ expo * 1e6;
              [jpre, jpos] = janela_simetrica(anos(usado), P);
              jan = ismember(anos, [jpre, jpos]);
              rotulo = sprintf('%s,%s,%s,%s,%s,%s', fonte, A.grupos{g}, A.medidas{md}, A.ufs{u}, A.sexos{s}, A.faixas{fx});
              for i = 1:numel(anos)
                if meses(i) == 0, continue; end
                fprintf(fa, '%s,%d,%s,%d,%s,%s,%d,%d,%d\n', rotulo, anos(i), per{i}, y(i), ...
                        num2s(pop(i)), num2s(taxa(i)), meses(i), usado(i), jan(i));
              end
              R = testa(anos(usado), y(usado), log(expo(usado)), P, A, q975);
              R.taxa_pre = sum(y(ismember(anos, jpre))) / sum(expo(ismember(anos, jpre))) * 1e6;
              R.taxa_pos = sum(y(ismember(anos, jpos))) / sum(expo(ismember(anos, jpos))) * 1e6;
              testes(end + 1).chave = rotulo; %#ok<AGROW>
              testes(end).v = R;
              testes(end).fam = fam;
              % ano a ano contra a linha de base pre
              pre = ismember(anos, jpre);
              if R.ok
                lb = sum(y(pre)) / sum(expo(pre));
                for i = find(usado & strcmp(per, 'pos'))'
                  rr = (y(i) / expo(i)) / lb;
                  se = sqrt(R.phi * (1 / max(y(i), 0.5) + 1 / sum(y(pre))));
                  qq = q975(R.dfA);
                  fy{end + 1} = sprintf('%s,%d,%s,%s,%s', rotulo, anos(i), num2s(rr), ...
                                        num2s(rr * exp(-qq * se)), num2s(rr * exp(qq * se))); %#ok<AGROW>
                end
              end
            end
          end
          % Holm dentro da familia
          idx = fam:numel(testes);
          pA = arrayfun(@(t) t.v.pA, testes(idx));
          pB = arrayfun(@(t) t.v.pB_salto, testes(idx));
          hA = holm(pA); hB = holm(pB);
          for j = 1:numel(idx)
            testes(idx(j)).v.pA_holm = hA(j);
            testes(idx(j)).v.pB_holm = hB(j);
          end
        end
      end
    end
  end
  fclose(fa);

  cab = ['fonte,grupo,medida,uf,sexo,faixa,anos_pre,anos_pos,casos_pre,casos_pos,' ...
         'taxa_pre_milhao,taxa_pos_milhao,rr_pos_pre,ic95_inf,ic95_sup,p,p_holm,' ...
         'tendencia_pre_pct_ano,tend_ic95_inf,tend_ic95_sup,' ...
         'salto_2021_rr,salto_ic95_inf,salto_ic95_sup,p_salto,p_salto_holm,' ...
         'mudanca_inclinacao_rr,p_inclinacao,dispersao,significativo'];
  fid = fopen(fullfile(raiz, 'dados', 'faixas_teste.csv'), 'w');
  fprintf(fid, '%s\n', cab);
  for i = 1:numel(testes)
    v = testes(i).v;
    sig = '';
    if v.ok
      if v.pA_holm < A.alfa && v.rr > 1, sig = 'aumento';
      elseif v.pA_holm < A.alfa && v.rr < 1, sig = 'queda';
      else, sig = 'ns'; end
    end
    num = [v.npre, v.npos, v.cpre, v.cpos, v.taxa_pre, v.taxa_pos, v.rr, v.rr_inf, v.rr_sup, v.pA, v.pA_holm, ...
           v.tend, v.tend_inf, v.tend_sup, v.salto, v.salto_inf, v.salto_sup, v.pB_salto, v.pB_holm, ...
           v.incl, v.pB_incl, v.phi];
    fprintf(fid, '%s,%s,%s\n', testes(i).chave, strjoin(arrayfun(@num2s, num, 'UniformOutput', false), ','), sig);
  end
  fclose(fid);

  fid = fopen(fullfile(raiz, 'dados', 'faixas_ano_vs_pre.csv'), 'w');
  fprintf(fid, 'fonte,grupo,medida,uf,sexo,faixa,ano,rr_vs_pre,ic95_inf,ic95_sup\n');
  fprintf(fid, '%s\n', fy{:});
  fclose(fid);

  csv_para_js(fullfile(raiz, 'docs', 'faixas.js'), ...
    {fullfile(raiz, 'dados', 'faixas_anual.csv'), fullfile(raiz, 'dados', 'faixas_teste.csv')}, ...
    {'anual', 'teste'}, P);
  printf('compara_faixas: %d estratos testados\n', numel(testes));
end

% ------------------------------------------------------------------------
function R = testa(ano, y, off, P, A, q975)
  [jpre, jpos] = janela_simetrica(ano, P);
  R = struct('ok', false, 'npre', numel(jpre), 'npos', numel(jpos), ...
             'cpre', sum(y(ismember(ano, jpre))), 'cpos', sum(y(ismember(ano, jpos))), ...
             'rr', NaN, 'rr_inf', NaN, 'rr_sup', NaN, 'pA', NaN, 'dfA', NaN, 'phi', NaN, ...
             'tend', NaN, 'tend_inf', NaN, 'tend_sup', NaN, 'salto', NaN, 'salto_inf', NaN, ...
             'salto_sup', NaN, 'pB_salto', NaN, 'incl', NaN, 'pB_incl', NaN, ...
             'pA_holm', NaN, 'pB_holm', NaN);
  if R.npre < A.min_anos || R.npos < A.min_anos || R.cpre == 0
    return;
  end
  pos = double(ismember(ano, P.pos));
  t = ano - P.transicao(1);
  % Modelo A: so a janela simetrica (k anos antes x k anos depois)
  w = ismember(ano, [jpre, jpos]);
  FA = glm_poisson([ones(sum(w), 1), pos(w)], y(w), off(w));
  if ~FA.ok, return; end
  se = sqrt(FA.V(2, 2)); q = q975(FA.df);
  R.ok = true; R.phi = FA.phi; R.dfA = FA.df;
  R.rr = exp(FA.b(2)); R.rr_inf = exp(FA.b(2) - q * se); R.rr_sup = exp(FA.b(2) + q * se);
  R.pA = t_pvalor(FA.b(2) / se, FA.df);
  % serie interrompida: precisa de >= 1 grau de liberdade residual
  X = [ones(size(t)), t, pos, pos .* t];
  FB = glm_poisson(X, y, off);
  if FB.ok && FB.df >= 1
    q = q975(FB.df);
    s1 = sqrt(FB.V(2, 2));
    R.tend = 100 * (exp(FB.b(2)) - 1);
    R.tend_inf = 100 * (exp(FB.b(2) - q * s1) - 1);
    R.tend_sup = 100 * (exp(FB.b(2) + q * s1) - 1);
    c = [0; 0; 1; 1];                              % salto avaliado em 2021 (t = 1)
    est = c' * FB.b; s = sqrt(c' * FB.V * c);
    R.salto = exp(est); R.salto_inf = exp(est - q * s); R.salto_sup = exp(est + q * s);
    R.pB_salto = t_pvalor(est / s, FB.df);
    s4 = sqrt(FB.V(4, 4));
    R.incl = exp(FB.b(4)); R.pB_incl = t_pvalor(FB.b(4) / s4, FB.df);
  end
end

function c = num2cellstr(v)
  c = arrayfun(@(x) sprintf('%d', x), v(:), 'UniformOutput', false);
end

function s = num2s(x)
  if isnan(x) || isinf(x), s = ''; else, s = sprintf('%.10g', x); end
end

function csv_para_js(arq, csvs, nomes, P)
  fid = fopen(arq, 'w');
  fprintf(fid, '// Gerado por octave/compara_faixas.m em %s. Nao editar.\n', datestr(now, 'yyyy-mm-dd HH:MM'));
  fprintf(fid, 'window.FAIXAS = {"simetrico":%d,"gerado":"%s","pre":[%s],"transicao":[%s],"pos":[%s]', P.simetrico, ...
          datestr(now, 'yyyy-mm-dd'), sprintf('%d,', P.pre)(1:end-1), ...
          sprintf('%d,', P.transicao)(1:end-1), sprintf('%d,', P.pos)(1:end-1));
  for i = 1:numel(csvs)
    L = strsplit(strtrim(fileread(csvs{i})), "\n");
    cab = strsplit(L{1}, ',');
    fprintf(fid, ',\n"%s":{"colunas":["%s"],"linhas":[\n', nomes{i}, strjoin(cab, '","'));
    for j = 2:numel(L)
      c = strsplit(L{j}, ',');
      for k = 1:numel(c)
        x = str2double(c{k});
        if isempty(c{k}), c{k} = 'null';
        elseif isnan(x), c{k} = ['"' c{k} '"'];
        end
      end
      fprintf(fid, '[%s]', strjoin(c, ','));
      if j < numel(L), fprintf(fid, ',\n'); end
    end
    fprintf(fid, ']}');
  end
  fprintf(fid, '\n};\n');
  fclose(fid);
end
