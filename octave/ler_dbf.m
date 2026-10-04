function T = ler_dbf(arquivo, campos)
% LER_DBF  Le um arquivo DBF (dBase III, formato dos microdados DATASUS).
%
%   T = ler_dbf(arquivo)          le todos os campos
%   T = ler_dbf(arquivo, campos)  le apenas os campos pedidos (cellstr)
%
% Retorna struct com:
%   T.n        numero de registros validos (nao apagados)
%   T.tipos    struct campo -> tipo DBF ('C','N','D',...)
%   T.dados    struct campo -> matriz char (n x largura)
% Campos pedidos que nao existem no arquivo voltam como matriz de espacos
% (n x 1) e ficam listados em T.ausentes.
%
% Leitura vetorizada: o arquivo inteiro e lido como uint8 e os campos sao
% recortados por posicao de byte. Roda em Octave puro, sem pacotes.

  fid = fopen(arquivo, 'r', 'ieee-le');
  if fid < 0
    error('ler_dbf: nao consegui abrir %s', arquivo);
  end
  limpa = onCleanup(@() fclose(fid));

  cab = fread(fid, 32, 'uint8=>uint8')';
  if numel(cab) < 32
    error('ler_dbf: cabecalho incompleto em %s', arquivo);
  end
  nreg = double(typecast(cab(5:8),  'uint32'));
  hlen = double(typecast(cab(9:10), 'uint16'));
  rlen = double(typecast(cab(11:12),'uint16'));

  % Descritores de campo (32 bytes cada) ate o terminador 0x0D
  nomes = {}; tipos = {}; larg = []; offs = [];
  pos = 2;                                  % byte 1 = marca de apagado
  while true
    b = fread(fid, 1, 'uint8=>uint8');
    if isempty(b) || b == 13
      break;
    end
    fd = [b; fread(fid, 31, 'uint8=>uint8')]';
    nm = fd(1:11);
    z = find(nm == 0, 1);
    if ~isempty(z), nm = nm(1:z-1); end
    nomes{end+1} = upper(strtrim(char(nm)));  %#ok<AGROW>
    tipos{end+1} = char(fd(12));              %#ok<AGROW>
    larg(end+1)  = double(fd(17));            %#ok<AGROW>
    offs(end+1)  = pos;                       %#ok<AGROW>
    pos = pos + double(fd(17));
  end

  if nargin < 2 || isempty(campos)
    campos = nomes;
  end
  campos = upper(cellstr(campos));

  fseek(fid, hlen, 'bof');
  bruto = fread(fid, [rlen, nreg], 'uint8=>uint8');
  nlido = size(bruto, 2);                   % tolera arquivo truncado
  if nlido < nreg
    warning('ler_dbf: %s tem %d registros no cabecalho, li %d', ...
            arquivo, nreg, nlido);
  end
  validos = bruto(1, :) ~= uint8('*');
  bruto = bruto(:, validos);
  n = size(bruto, 2);

  T.n = n;
  T.tipos = struct();
  T.dados = struct();
  T.ausentes = {};
  for i = 1:numel(campos)
    c = campos{i};
    j = find(strcmp(nomes, c), 1);
    if isempty(j)
      T.dados.(c) = repmat(' ', n, 1);
      T.tipos.(c) = 'C';
      T.ausentes{end+1} = c;                %#ok<AGROW>
    else
      faixa = offs(j):(offs(j) + larg(j) - 1);
      T.dados.(c) = char(bruto(faixa, :)');
      T.tipos.(c) = tipos{j};
    end
  end
end
