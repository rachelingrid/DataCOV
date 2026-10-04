function A = analise_faixas()
% ANALISE_FAIXAS  O que entra na comparacao por sexo e faixa etaria.
  A.fontes  = {'SIH', 'SIM'};                 % internacoes e obitos
  A.grupos  = {'TVP', 'TVP_SEMCOVID', 'TVP_TEP', 'TEV', 'EMBOLIA', 'AMPUTACAO'};
  A.medidas = {'n_qualquer', 'n_principal'};  % qualquer mencao / diagnostico principal
  A.ufs     = {'BR'};                          % acrescente 'RJ', 'SP'... se quiser
  A.sexos   = {'M', 'F'};
  A.faixas  = {'20-29', '30-39', '40-49', '50-59', '60-69', '70-79', '80-89'};
  A.alfa    = 0.05;
  A.min_anos = 3;                              % minimo de anos em cada periodo
end
