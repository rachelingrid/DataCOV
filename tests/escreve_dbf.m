function escreve_dbf(arquivo, S)
% ESCREVE_DBF  Grava um DBF simples (todos os campos tipo 'C') a partir de
% uma struct de cellstr com o mesmo numero de linhas. Usado so nos testes.
  nomes = fieldnames(S);
  n = numel(S.(nomes{1}));
  M = {};
  larg = zeros(1, numel(nomes));
  for i = 1:numel(nomes)
    c = char(S.(nomes{i}));
    if isempty(c), c = repmat(' ', n, 1); end
    larg(i) = max(1, columns(c));
    M{i} = c;
  end
  rlen = 1 + sum(larg);
  hlen = 32 + 32 * numel(nomes) + 1;
  fid = fopen(arquivo, 'w', 'ieee-le');
  cab = zeros(1, 32, 'uint8');
  cab(1) = 3;
  cab(2:4) = uint8([126 1 1]);
  cab(5:8) = typecast(uint32(n), 'uint8');
  cab(9:10) = typecast(uint16(hlen), 'uint8');
  cab(11:12) = typecast(uint16(rlen), 'uint8');
  fwrite(fid, cab, 'uint8');
  for i = 1:numel(nomes)
    fd = zeros(1, 32, 'uint8');
    nm = uint8(nomes{i});
    fd(1:numel(nm)) = nm;
    fd(12) = uint8('C');
    fd(17) = larg(i);
    fwrite(fid, fd, 'uint8');
  end
  fwrite(fid, uint8(13), 'uint8');
  reg = repmat(' ', n, rlen);
  pos = 2;
  for i = 1:numel(nomes)
    c = M{i};
    reg(:, pos:pos+columns(c)-1) = c;
    pos = pos + larg(i);
  end
  fwrite(fid, uint8(reg'), 'uint8');
  fwrite(fid, uint8(26), 'uint8');
  fclose(fid);
end
