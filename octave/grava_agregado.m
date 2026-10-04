function grava_agregado(fonte, R, arq_saida, preliminar)
% GRAVA_AGREGADO  Agrega registros classificados e acrescenta ao CSV.
  rot_faixa = faixa_rotulos();
  ufs = {'AC','AL','AM','AP','BA','CE','DF','ES','GO','MA','MG','MS','MT','PA', ...
         'PB','PE','PI','PR','RJ','RN','RO','RR','RS','SC','SE','SP','TO','IG'};
  [~, ufi] = ismember(R.uf, ufs);
  ufi(ufi == 0) = numel(ufs);
  sx = 'MFI';
  [~, sxi] = ismember(R.sexo, sx');
  sxi(sxi == 0) = 3;

  chave = ((((R.ano * 13 + R.mes) * 30 + ufi) * 3 + (sxi - 1)) * 12 + (R.faixa - 1));
  novo = exist(arq_saida, 'file') ~= 2;
  fid = fopen(arq_saida, 'a');
  if fid < 0, error('grava_agregado: nao consegui abrir %s', arq_saida); end
  limpa = onCleanup(@() fclose(fid));
  if novo
    fprintf(fid, 'fonte,ano,mes,uf,sexo,faixa,grupo,preliminar,n_qualquer,n_principal,obitos_qualquer,obitos_principal\n');
  end

  grupos = fieldnames(R.q);
  for g = 1:numel(grupos)
    mq = R.q.(grupos{g});
    mp = R.p.(grupos{g});
    usa = mq | mp;
    if ~any(usa), continue; end
    [u, ~, j] = unique(chave(usa));
    nq = accumarray(j, mq(usa));
    np = accumarray(j, mp(usa));
    oq = accumarray(j, mq(usa) & R.obito(usa));
    op = accumarray(j, mp(usa) & R.obito(usa));
    % decodifica chave
    fa = mod(u, 12) + 1;          r = floor(u / 12);
    si = mod(r, 3) + 1;           r = floor(r / 3);
    ui = mod(r, 30);              r = floor(r / 30);
    me = mod(r, 13);              an = floor(r / 13);
    for k = 1:numel(u)
      fprintf(fid, '%s,%d,%d,%s,%s,%s,%s,%d,%d,%d,%d,%d\n', fonte, an(k), me(k), ...
              ufs{ui(k)}, sx(si(k)), rot_faixa{fa(k)}, grupos{g}, preliminar, ...
              nq(k), np(k), oq(k), op(k));
    end
  end
end
