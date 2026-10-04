function G = grupos_cid()
% GRUPOS_CID  Definicoes de CID-10 e procedimentos SIGTAP usadas no projeto.
%
% Edite aqui para mudar o que entra em cada grupo. Codigos sem ponto; o
% casamento e por prefixo (ex.: 'I26' pega I26.0 e I26.9).
% Depois de editar, rode o workflow novamente para reprocessar os anos.

  % 1) Trombose (venosa e arterial)
  G.TROMBOSE = {'I80', 'I81', 'I82', ...   % flebite/tromboflebite, TVP portal, outras TVs
                'I676', ...                % trombose venosa cerebral nao piogenica
                'I74', ...                 % embolia e trombose arteriais (tambem em EMBOLIA)
                'O223', 'O225', ...        % TVP / trombose venosa cerebral na gravidez
                'O871', 'O873'};           % TVP / trombose venosa cerebral no puerperio

  % 1a) TVP - trombose venosa profunda (analise por sexo e faixa etaria)
  %   I80.1 veia femoral, I80.2 outros vasos profundos dos MMII,
  %   I80.3 MMII nao especificada, I82.2 veia cava, O22.3 TVP na gravidez,
  %   O87.1 TVP no puerperio. Fica de fora I80.0 (superficial) e I80.9
  %   (local nao especificado) - acrescente 'I809' aqui se quiser incluir.
  % Derivados: TVP_SEMCOVID (sem mencao de COVID) e TVP_TEP (TVP ou I26).
  G.TVP = {'I801', 'I802', 'I803', 'I822', 'O223', 'O871'};

  % 2) Embolia (qualquer tipo)
  G.EMBOLIA = {'I26', ...                  % embolia pulmonar
               'I74', ...                  % embolia e trombose arteriais
               'O88', ...                  % embolia obstetrica (gasosa, liquido amniotico, coagulo, septica)
               'T790', ...                 % embolia gordurosa traumatica
               'T800', ...                 % embolia gasosa pos infusao/transfusao
               'T817'};                    % complicacoes vasculares pos procedimento

  % Uniao dos dois (sem dupla contagem)
  G.TEV = unique([G.TROMBOSE, G.EMBOLIA]);

  % COVID-19 mencionada (para separar o efeito da pandemia)
  G.COVID = {'U071', 'U072', 'B342'};

  % 3) Gestacao, parto e puerperio (capitulo XV)
  G.OBSTETRICO = {'O'};
  % Proxy de 1o trimestre: gravidez que termina em aborto / ectopica / molar
  G.TRI1_PROXY = {'O00', 'O01', 'O02', 'O03', 'O04', 'O05', 'O06', 'O07', 'O08'};

  % 4) Amputacao - procedimentos SIGTAP (campo PROC_REA do SIH)
  G.AMP_MMII = {'0408050012', ...          % amputacao/desarticulacao de membros inferiores
                '0408050020'};             % amputacao/desarticulacao de pe e tarso
  G.AMP_MMSS = {'0408020024', ...          % amputacao/desarticulacao de membros superiores
                '0408020016'};             % amputacao/desarticulacao de mao e punho
  G.AMP_DEDO = {'0408060042'};             % amputacao/desarticulacao de dedo
  G.AMPUTACAO = [G.AMP_MMII, G.AMP_MMSS, G.AMP_DEDO];

  % Causas associadas a amputacao (qualquer diagnostico da internacao)
  G.DIABETES = {'E10', 'E11', 'E12', 'E13', 'E14'};
  G.VASCULAR = {'I70', 'I73', 'I74'};
  G.TRAUMA   = {'S4', 'S5', 'S6', 'S7', 'S8', 'S9', ...  % lesoes de membros (inclui S48, S58... amputacao traumatica)
                'T05'};                                  % amputacao traumatica de multiplas regioes
end
