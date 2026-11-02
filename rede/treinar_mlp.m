%% ========================================================================
%  TREINAR_MLP.M
%  ------------------------------------------------------------------------
%  Treina a MLP (escrita a mao: mlp_criar, mlp_propagar, mlp_treinar) para
%  reconhecer os 7 trechos: di, rei, ta, es, quer, da e silencio.
%
%  TREINO FINAL. A configuracao abaixo foi escolhida com dados, etapa por
%  etapa, em escolher_arquitetura.m (5 sementes por opcao, so validacao);
%  tabelas e justificativas em resultados/escolha/RELATORIO_EXPERIMENTOS.md:
%    - entrada: 32 faixas, com contexto (+-100 ms)        (etapa 1)
%    - normalizacao: max                                   (etapa 2)
%    - camadas ocultas: [128 64]                           (etapas 3 e 5)
%    - ativacao ReLU, taxa de aprendizado 0.03             (etapa 4)
%  Treina a configuracao com as mesmas 5 sementes e guarda a rede com mais
%  palavras de validacao. As listas abaixo continuam aceitando varias
%  opcoes, para quem quiser comparar outras combinacoes.
%
%  Protocolo:
%    - Treino (60%): ajusta os pesos.
%    - Validacao (20%): escolhe quando parar (parada antecipada) e qual
%      combinacao e a melhor.
%    - Teste (20%): mede o desempenho final; NAO e usado em nenhuma
%      escolha, para a nota de teste ser honesta.
%
%  Cada rede e medida de dois jeitos:
%    - por JANELA: fracao das janelas (trechos de 150 ms) classificadas certo;
%    - por PALAVRA: as palavras inteiras de validacao/teste passam pelo
%      reconhecedor do programa 2 (reconhecer_palavra.m) e conta-se quantas
%      sao reconhecidas certo. Esse e o objetivo do trabalho, entao a melhor
%      rede e escolhida pelas PALAVRAS de validacao (desempate: janelas).
%
%  Saidas (pasta resultados/):
%    resultados.csv      - acertos de cada combinacao (abre no Excel)
%    modelo_final.mat    - a melhor rede + tudo que o programa 2 precisa
%    curva_treino.png    - erro por epoca da melhor rede
%    matriz_confusao.png - acertos/erros por classe no teste
%
%  Requisito: rodar antes extrair_entradas.m
%  ========================================================================

clear; clc; close all;

%% 1. CONFIGURACAO ---------------------------------------------------------
pasta_script = fileparts(mfilename('fullpath'));
pasta_entradas = fullfile(pasta_script, 'entradas');
pasta_result   = fullfile(pasta_script, 'resultados');
if ~exist(pasta_result, 'dir'), mkdir(pasta_result); end

% Opcoes comparadas
metodos       = {'energia'};             % (opcoes: 'tercos', 'energia')
lista_bandas  = [32];                    % (opcoes: 32, 64)
normalizacoes = {'max'};                 % (opcoes: 'max', 'db', 'zscore')
arquiteturas  = {[128 64]};              % neuronios por camada oculta:
                                         % [32] = 1 camada de 32;
                                         % [128 64] = 2 camadas (128 e 64)
contextos     = {[-4 -2 0 2 4]};         % [0] = so a janela atual;
                                         % [-4 -2 0 2 4] = atual + vizinhas
                                         % (ver espectro_contexto.m)
ativacoes     = {'relu'};                % funcao das camadas ocultas
                                         % (opcoes: 'sigmoide', 'relu')
taxas         = [0.03];                  % taxa de aprendizado de cada ativacao
                                         % (melhores na etapa 4: sigmoide 0.5,
                                         %  ReLU 0.03)
sementes      = 1:5;                     % sementes dos pesos iniciais (as
                                         % mesmas dos experimentos)

% Parametros do treino (iguais para todas as combinacoes)
% (com o treino por janelas ha ~6x mais amostras; por isso o lote e maior
%  e sao precisas menos epocas - cada epoca ja ve muito mais exemplos)
% p.taxa (taxa de aprendizado) vem de 'taxas', conforme a ativacao
p.momento    = 0.9;    % momento (aproveita parte do passo anterior)
p.epocas_max = 800;    % limite de epocas
p.tam_lote   = 32;     % amostras por atualizacao dos pesos
p.paciencia  = 200;    % para se a validacao nao melhorar em 200 epocas

% Parametros do reconhecimento de palavras (os MESMOS de programa2_reconhecer.m)
p_rec.n_conf       = 1;
p_rec.max_silencio = 0.300;

rng(1);   % semente fixa: pesos iniciais iguais a cada execucao

% Palavras inteiras de validacao e de teste. A divisao e por repeticao e
% e a mesma para todas as combinacoes; le do 1o arquivo de entradas.
% (no modo janelas ha uma entrada por janela, por isso o unique)
pasta_palavras = fullfile(pasta_script, '..', 'segmentacao', 'saida', 'palavras');
nomes_pal = {'direita', 'esquerda'};
D = load(fullfile(pasta_entradas, sprintf('entradas_%s_%d.mat', metodos{1}, lista_bandas(1))));
num_de = @(nome) str2double(regexprep(nome, '^.*_(\d+)\.wav$', '$1'));
pal = struct('audio', {}, 'palavra', {}, 'conj', {});   % uma por palavra
for w = 1:2
    prim = {'di_', 'es_'};                      % 1a silaba de cada palavra
    sel = strncmp(D.arquivos, prim{w}, 3) & D.conj ~= 1;
    nums = unique(cellfun(num_de, D.arquivos(sel)));
    for num = nums(:)'
        [x, fs_pal] = audioread(fullfile(pasta_palavras, sprintf('%s_%03d.wav', nomes_pal{w}, num)));
        cj = D.conj(find(sel & strcmp(D.arquivos, sprintf('%s%03d.wav', prim{w}, num)), 1));
        pal(end+1) = struct('audio', mean(x, 2), 'palavra', nomes_pal{w}, 'conj', cj); %#ok<SAGROW>
    end
end
pal_va = [pal.conj] == 3;  pal_te = [pal.conj] == 2;
fprintf('Palavras inteiras: %d de validacao, %d de teste\n\n', sum(pal_va), sum(pal_te));

%% 2. TREINA TODAS AS COMBINACOES -----------------------------------------
res = {};          % uma linha por combinacao
melhor = [-Inf, -Inf, -Inf];   % [palavras validacao, janelas validacao, -erro validacao]

for m = 1:numel(metodos)
  for nb = lista_bandas
   for ic = 1:numel(contextos)
    % Carrega as entradas desta combinacao (metodo x faixas x contexto)
    D = load(fullfile(pasta_entradas, sprintf('entradas_%s_%d%s.mat', metodos{m}, nb, ...
                                              sufixo_contexto(contextos{ic}))));
    txt_ctx = 'nao';  if ~isequal(D.contexto, 0), txt_ctx = 'sim'; end
    n_classes = numel(D.classes);

    % Saida desejada "uma por classe": linha com 1 na classe certa e 0 nas outras
    Y = zeros(numel(D.y), n_classes);
    Y(sub2ind(size(Y), (1:numel(D.y))', D.y)) = 1;

    tr = D.conj == 1;  te = D.conj == 2;  va = D.conj == 3;

    for k = 1:numel(normalizacoes)
      % Normaliza; no 'zscore' a media/desvio vem SO do treino
      [Xtr, stats] = normalizar(D.X(tr, :), normalizacoes{k});
      Xva = normalizar(D.X(va, :), normalizacoes{k}, stats);
      Xte = normalizar(D.X(te, :), normalizacoes{k}, stats);

      for a = 1:numel(arquiteturas)
       for f = 1:numel(ativacoes)
        for sd = sementes
        oc = arquiteturas{a};
        p.taxa = taxas(f);
        rng(sd);   % mesma semente dos experimentos -> mesma rede
        % entradas = faixas x janelas de contexto (ver extrair_entradas.m)
        rede = mlp_criar(size(D.X, 2), oc, n_classes, ativacoes{f});
        tic;
        [rede, hist] = mlp_treinar(rede, Xtr, Y(tr, :), Xva, Y(va, :), p);
        t = toc;

        % Acertos em cada conjunto (classe prevista = maior saida)
        ac_tr = mean(mlp_classificar(rede, Xtr) == D.y(tr));
        ac_va = mean(mlp_classificar(rede, Xva) == D.y(va));
        prev_te = mlp_classificar(rede, Xte);
        ac_te = mean(prev_te == D.y(te));
        erro_va = hist.erro_va(hist.melhor_epoca);
        % Acerto medio das 6 SILABAS no teste (media do acerto de cada
        % silaba; o silencio fica de fora, ele quase sempre acerta)
        yt = D.y(te);
        ac_sil = mean(arrayfun(@(c) mean(prev_te(yt == c) == c), 1:6));

        % Acerto por PALAVRA: cada palavra inteira passa pelo reconhecedor
        m_tmp = struct('rede', rede, 'stats', stats, 'n_bandas', nb, ...
            'normalizacao', normalizacoes{k}, 'classes', {D.classes}, ...
            'f_min', D.f_min, 'f_max', D.f_max, 'contexto', D.contexto);
        p_rec.janela = D.janela;  p_rec.passo = D.passo;
        certa = false(1, numel(pal));
        for i = 1:numel(pal)
            r = reconhecer_palavra(pal(i).audio, fs_pal, m_tmp, p_rec);
            certa(i) = ~isempty(r) && strcmp(r(1).palavra, pal(i).palavra);
        end
        pa_va = mean(certa(pal_va));  pa_te = mean(certa(pal_te));

        txt_oc = strjoin(arrayfun(@num2str, oc, 'UniformOutput', false), '-');
        fprintf(['%-8s %2d faixas  ctx %-3s  %-6s oculta %-9s %-8s semente %d | janelas: treino %5.1f%%  valid %5.1f%%  teste %5.1f%%' ...
                 ' | silabas teste %5.1f%% | palavras: valid %2d/%d  teste %2d/%d | epoca %4d | %4.1f s\n'], ...
            metodos{m}, nb, txt_ctx, normalizacoes{k}, txt_oc, ativacoes{f}, sd, 100*ac_tr, 100*ac_va, 100*ac_te, ...
            100*ac_sil, sum(certa(pal_va)), sum(pal_va), sum(certa(pal_te)), sum(pal_te), hist.melhor_epoca, t);
        res(end+1, :) = {metodos{m}, nb, txt_ctx, normalizacoes{k}, txt_oc, ativacoes{f}, p.taxa, sd, ...
                         ac_tr, ac_va, ac_te, ac_sil, pa_va, pa_te, hist.melhor_epoca}; %#ok<SAGROW>

        % A melhor combinacao e escolhida pela VALIDACAO, nunca pelo teste:
        % 1o mais palavras de validacao; empate -> mais janelas de
        % validacao; empate -> menor erro quadratico de validacao.
        criterio = [pa_va, ac_va, -erro_va];
        k_dif = find(criterio ~= melhor, 1);
        if ~isempty(k_dif) && criterio(k_dif) > melhor(k_dif)
          melhor = criterio;
          modelo.ac_silabas = ac_sil;
          modelo.rede = rede;  modelo.hist = hist;  modelo.stats = stats;
          modelo.metodo = metodos{m};  modelo.n_bandas = nb;
          modelo.normalizacao = normalizacoes{k};  modelo.ocultas = oc;
          modelo.ativacao = ativacoes{f};  modelo.contexto = D.contexto;
          modelo.taxa = p.taxa;  modelo.semente = sd;
          modelo.classes = D.classes;  modelo.f_min = D.f_min;  modelo.f_max = D.f_max;
          modelo.modo = D.modo;  modelo.janela = D.janela;  modelo.passo = D.passo;
          modelo.acertos = [ac_tr, ac_va, ac_te];
          modelo.acertos_palavras = [pa_va, pa_te];
          modelo.y_teste = D.y(te);
          modelo.prev_teste = mlp_classificar(rede, Xte);
          modelo.arquivos_teste = D.arquivos(te);
        end
        end
       end
      end
    end
   end
  end
end

%% 3. SALVA A TABELA DE RESULTADOS ----------------------------------------
fid = fopen(fullfile(pasta_result, 'resultados.csv'), 'w');
fprintf(fid, ['metodo;faixas;contexto;normalizacao;ocultas;ativacao;taxa;semente;acerto_treino;acerto_validacao;acerto_teste;' ...
              'silabas_teste;palavras_validacao;palavras_teste;melhor_epoca\n']);
for i = 1:size(res, 1)
    fprintf(fid, '%s;%d;%s;%s;%s;%s;%g;%d;%.3f;%.3f;%.3f;%.3f;%.3f;%.3f;%d\n', res{i, :});
end
fclose(fid);

%% 4. MELHOR MODELO --------------------------------------------------------
fprintf('\n=== MELHOR COMBINACAO (escolhida pela validacao) ===\n');
fprintf('metodo %s | %d faixas | normalizacao %s | ocultas [%s] | ativacao %s | taxa %g | contexto [%s] passos | semente %d\n', ...
    modelo.metodo, modelo.n_bandas, modelo.normalizacao, num2str(modelo.ocultas), ...
    modelo.ativacao, modelo.taxa, num2str(modelo.contexto), modelo.semente);
fprintf('janelas:  treino %.1f%% | validacao %.1f%% | teste %.1f%%\n', 100 * modelo.acertos);
fprintf('palavras: validacao %.1f%% | teste %.1f%%\n', 100 * modelo.acertos_palavras);
save(fullfile(pasta_result, 'modelo_final.mat'), 'modelo', '-v7');

% Matriz de confusao do teste: linha = classe certa, coluna = classe prevista
nc = numel(modelo.classes);
MC = zeros(nc);
for i = 1:numel(modelo.y_teste)
    MC(modelo.y_teste(i), modelo.prev_teste(i)) = MC(modelo.y_teste(i), modelo.prev_teste(i)) + 1;
end
fprintf('\nMatriz de confusao (teste) - linhas: certa, colunas: prevista\n');
fprintf('%9s', ''); fprintf('%9s', modelo.classes{:}); fprintf('\n');
for i = 1:nc
    fprintf('%9s', modelo.classes{i}); fprintf('%9d', MC(i, :)); fprintf('\n');
end
% Acerto de cada classe = diagonal / total da linha
ac_classe = diag(MC)' ./ sum(MC, 2)';
fprintf('%9s', 'acerto'); fprintf('%8.0f%%', 100 * ac_classe); fprintf('\n');
fprintf('Acerto medio das 6 silabas (sem o silencio): %.1f%%\n', 100 * mean(ac_classe(1:6)));

% Figura: matriz de confusao
fig = figure('Visible', 'off', 'Position', [0 0 1000 800]);
imagesc(MC); colormap(flipud(gray)); colorbar;
set(gca, 'XTick', 1:nc, 'XTickLabel', modelo.classes, 'YTick', 1:nc, 'YTickLabel', modelo.classes);
xlabel('o que a rede respondeu (classe prevista)'); ylabel('o que foi dito (classe correta)');
title({sprintf('Matriz de confusao - janelas de TESTE: %.1f%% de acerto', 100 * modelo.acertos(3)), ...
       'numero de janelas em cada celula | diagonal = acertos | fora da diagonal = trocas'});
for i = 1:nc
    for j = 1:nc
        text(j, i, num2str(MC(i, j)), 'HorizontalAlignment', 'center', 'Color', [0.8 0 0]);
    end
end
saveas(fig, fullfile(pasta_result, 'matriz_confusao.png')); close(fig);

% Figura: curva de aprendizado da melhor rede
fig = figure('Visible', 'off');
plot(modelo.hist.erro_tr, 'b'); hold on; plot(modelo.hist.erro_va, 'r');
xline_y = ylim; plot([1 1] * modelo.hist.melhor_epoca, xline_y, 'k--');
legend('treino', 'validacao', 'rede escolhida');
xlabel('epoca'); ylabel('erro quadratico medio');
title('Curva de aprendizado da melhor rede');
saveas(fig, fullfile(pasta_result, 'curva_treino.png')); close(fig);

fprintf('\nResultados salvos em: %s\n', pasta_result);
