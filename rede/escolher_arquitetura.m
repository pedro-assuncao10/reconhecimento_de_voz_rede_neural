%% ========================================================================
%  ESCOLHER_ARQUITETURA.M
%  ------------------------------------------------------------------------
%  Experimentos para JUSTIFICAR, com dados, cada escolha da rede antes do
%  treino final (treinar_mlp.m). Metodo de corte: energia (vales).
%
%  Cada configuracao e treinada com VARIAS SEMENTES (pesos iniciais e ordem
%  das amostras diferentes). O resultado de uma rede varia de uma semente
%  para outra; por isso comparamos a MEDIA +- DESVIO PADRAO: uma diferenca
%  menor que o desvio nao e prova de que uma opcao e melhor.
%
%  Tudo e medido SO na VALIDACAO. O TESTE fica guardado para a nota final.
%
%  REGRA DE ESCOLHA (definida antes de ver os resultados):
%    1) vence quem reconhece mais PALAVRAS de validacao (media das sementes);
%    2) se a diferenca for menor que o desvio, vence a opcao mais SIMPLES;
%    3) desempate: acerto medio das SILABAS na validacao.
%
%  ORDEM DAS ETAPAS: do que a rede "ve" para como ela aprende. Cada etapa
%  usa o que as anteriores escolheram.
%    1 - ENTRADA: sem x com contexto, 32 x 64 faixas
%        (rede de referencia: 1 camada de 64, sigmoide, taxa 0.5, db)
%    2 - NORMALIZACAO: max x db x zscore (com a entrada escolhida)
%    3 - ARQUITETURA: numero de camadas/neuronios, todas em funil
%        (sigmoide, taxa 0.5)
%    4 - ATIVACAO + TAXA DE APRENDIZADO: sigmoide x ReLU, cada uma com 4
%        taxas (assim cada ativacao e comparada na sua melhor taxa)
%    5 - CONFIRMACAO: as melhores arquiteturas com a ativacao/taxa finais
%
%  Uso (as variaveis abaixo podem vir de fora, ex. para rodar sementes em
%  paralelo):  octave --eval "etapa = 1; sementes = 1:5; escolher_arquitetura"
%  Depois:     octave --eval "etapa = 1; resumir_escolha"
%
%  Saida: resultados/escolha/etapa<N>_semente<S>.csv (uma linha por rede)
%  ========================================================================

%% 1. CONFIGURACAO ---------------------------------------------------------
if ~exist('etapa', 'var'),    etapa = 1;       end
if ~exist('sementes', 'var'), sementes = 1:5;  end

% Escolhas das etapas anteriores (atualizar depois de ver cada resumo)
if ~exist('faixas_escolhidas', 'var'),       faixas_escolhidas = 64;              end
if ~exist('contexto_escolhido', 'var'),      contexto_escolhido = [-4 -2 0 2 4];  end
if ~exist('normalizacao_escolhida', 'var'),  normalizacao_escolhida = 'db';       end
if ~exist('ocultas_escolhidas', 'var'),      ocultas_escolhidas = [64];           end
if ~exist('ativacao_escolhida', 'var'),      ativacao_escolhida = 'sigmoide';     end
if ~exist('taxa_escolhida', 'var'),          taxa_escolhida = 0.5;                end
if ~exist('ocultas_finalistas', 'var'),      ocultas_finalistas = {[64]};         end

% Valores de referencia, usados enquanto um fator ainda nao foi testado
ref_ocultas = [64];  ref_ativacao = 'sigmoide';  ref_taxa = 0.5;

switch etapa
    case 1   % ENTRADA
        lista_faixas    = {32, 64};
        lista_contextos = {[0], [-4 -2 0 2 4]};
        lista_norm      = {'db'};
        lista_ocultas   = {ref_ocultas};
        lista_ativ_taxa = {{ref_ativacao, ref_taxa}};
    case 2   % NORMALIZACAO
        lista_faixas    = {faixas_escolhidas};
        lista_contextos = {contexto_escolhido};
        lista_norm      = {'max', 'db', 'zscore'};
        lista_ocultas   = {ref_ocultas};
        lista_ativ_taxa = {{ref_ativacao, ref_taxa}};
    case 3   % ARQUITETURA (todas em funil: cada camada com metade da anterior)
        lista_faixas    = {faixas_escolhidas};
        lista_contextos = {contexto_escolhido};
        lista_norm      = {normalizacao_escolhida};
        lista_ocultas   = {[32], [64], [128], [64 32], [128 64], ...
                           [128 64 32], [256 128 64 32]};
        lista_ativ_taxa = {{ref_ativacao, ref_taxa}};
    case 4   % ATIVACAO + TAXA DE APRENDIZADO
        lista_faixas    = {faixas_escolhidas};
        lista_contextos = {contexto_escolhido};
        lista_norm      = {normalizacao_escolhida};
        lista_ocultas   = {ocultas_escolhidas};
        lista_ativ_taxa = {{'sigmoide', 0.1}, {'sigmoide', 0.3}, {'sigmoide', 0.5}, {'sigmoide', 1.0}, ...
                           {'relu', 0.003},   {'relu', 0.01},    {'relu', 0.03},    {'relu', 0.1}};
    case 5   % CONFIRMACAO
        lista_faixas    = {faixas_escolhidas};
        lista_contextos = {contexto_escolhido};
        lista_norm      = {normalizacao_escolhida};
        lista_ocultas   = ocultas_finalistas;
        lista_ativ_taxa = {{ativacao_escolhida, taxa_escolhida}};
end

% Parametros do treino (os mesmos de treinar_mlp.m)
p.momento    = 0.9;
p.epocas_max = 800;
p.tam_lote   = 32;
p.paciencia  = 200;
p_rec.n_conf       = 1;
p_rec.max_silencio = 0.300;

pasta_script   = fileparts(mfilename('fullpath'));
pasta_entradas = fullfile(pasta_script, 'entradas');
pasta_saida    = fullfile(pasta_script, 'resultados', 'escolha');
pasta_palavras = fullfile(pasta_script, '..', 'segmentacao', 'saida', 'palavras');
if ~exist(pasta_saida, 'dir'), mkdir(pasta_saida); end

%% 2. RODA TODAS AS CONFIGURACOES, PARA CADA SEMENTE ----------------------
pal = [];
for s = sementes
    arq = fullfile(pasta_saida, sprintf('etapa%d_semente%d.csv', etapa, s));
    fid = fopen(arq, 'w');
    fprintf(fid, ['etapa;faixas;contexto;normalizacao;ocultas;ativacao;taxa;semente;acerto_treino;' ...
                  'acerto_validacao;silabas_validacao;di;rei;ta;es;quer;da;' ...
                  'palavras_validacao;melhor_epoca;tempo_s\n']);
    for i_f = 1:numel(lista_faixas)
     for i_c = 1:numel(lista_contextos)
        nb = lista_faixas{i_f};  ctx = lista_contextos{i_c};
        D = load(fullfile(pasta_entradas, sprintf('entradas_energia_%d%s.mat', nb, sufixo_contexto(ctx))));
        if isempty(pal), [pal, fs_pal] = carregar_palavras(pasta_palavras, D); end
        txt_ctx = 'nao';  if ~isequal(ctx, 0), txt_ctx = 'sim'; end
        for i_n = 1:numel(lista_norm)
         for i_o = 1:numel(lista_ocultas)
          for i_a = 1:numel(lista_ativ_taxa)
            nm = lista_norm{i_n};  oc = lista_ocultas{i_o};
            at = lista_ativ_taxa{i_a}{1};  p.taxa = lista_ativ_taxa{i_a}{2};
            r = avaliar_configuracao(D, pal, fs_pal, oc, at, p, p_rec, s, nm);
            txt_oc = strjoin(arrayfun(@num2str, oc, 'UniformOutput', false), '-');
            fprintf(fid, '%d;%d;%s;%s;%s;%s;%g;%d;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%d;%.1f\n', ...
                etapa, nb, txt_ctx, nm, txt_oc, at, p.taxa, s, r.ac_tr, r.ac_va, r.ac_silabas, ...
                r.silabas, r.ac_palavras, r.epoca, r.tempo);
            fflush(fid);
            fprintf('etapa %d semente %d | %2d faixas ctx %-3s %-6s oculta %-14s %-8s taxa %-5g | silabas valid %5.1f%% | palavras valid %5.1f%% | epoca %3d | %5.1f s\n', ...
                etapa, s, nb, txt_ctx, nm, txt_oc, at, p.taxa, 100*r.ac_silabas, 100*r.ac_palavras, r.epoca, r.tempo);
          end
         end
        end
     end
    end
    fclose(fid);
end
