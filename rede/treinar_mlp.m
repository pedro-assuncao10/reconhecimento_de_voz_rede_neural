%% ========================================================================
%  TREINAR_MLP.M
%  ------------------------------------------------------------------------
%  Treina a MLP (escrita a mao: mlp_criar, mlp_propagar, mlp_treinar) para
%  reconhecer os 7 trechos: di, rei, ta, es, quer, da e silencio.
%
%  Compara TODAS as combinacoes das opcoes que o projeto decidiu variar:
%    - metodo de corte das silabas: tercos (A) x energia (B)
%    - numero de entradas (faixas de 0 a 5 kHz): 32 x 64
%    - normalizacao: max x db x zscore
%    - camadas ocultas: varias arquiteturas (lista abaixo)
%
%  Protocolo:
%    - Treino (70%): ajusta os pesos.
%    - Validacao (10%): escolhe quando parar (parada antecipada) e qual
%      combinacao e a melhor.
%    - Teste (20%): mede o desempenho final; NAO e usado em nenhuma
%      escolha, para a nota de teste ser honesta.
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
metodos       = {'tercos', 'energia'};
lista_bandas  = [32 64];
normalizacoes = {'max', 'db', 'zscore'};
arquiteturas  = {[10], [30], [30 15]};   % neuronios por camada oculta:
                                         % [10] = 1 camada de 10, etc.

% Parametros do treino (iguais para todas as combinacoes)
% (com o treino por janelas ha ~6x mais amostras; por isso o lote e maior
%  e sao precisas menos epocas - cada epoca ja ve muito mais exemplos)
p.taxa       = 0.5;    % taxa de aprendizado
p.momento    = 0.9;    % momento (aproveita parte do passo anterior)
p.epocas_max = 800;    % limite de epocas
p.tam_lote   = 32;     % amostras por atualizacao dos pesos
p.paciencia  = 80;     % para se a validacao nao melhorar em 80 epocas

rng(1);   % semente fixa: pesos iniciais iguais a cada execucao

%% 2. TREINA TODAS AS COMBINACOES -----------------------------------------
res = {};          % uma linha por combinacao
melhor_acerto_va = -Inf;  melhor_erro_va = Inf;

for m = 1:numel(metodos)
  for nb = lista_bandas
    % Carrega as entradas desta combinacao (metodo x faixas)
    D = load(fullfile(pasta_entradas, sprintf('entradas_%s_%d.mat', metodos{m}, nb)));
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
        oc = arquiteturas{a};
        rede = mlp_criar(nb, oc, n_classes);
        tic;
        [rede, hist] = mlp_treinar(rede, Xtr, Y(tr, :), Xva, Y(va, :), p);
        t = toc;

        % Acertos em cada conjunto (classe prevista = maior saida)
        ac_tr = mean(mlp_classificar(rede, Xtr) == D.y(tr));
        ac_va = mean(mlp_classificar(rede, Xva) == D.y(va));
        ac_te = mean(mlp_classificar(rede, Xte) == D.y(te));
        erro_va = hist.erro_va(hist.melhor_epoca);

        txt_oc = strjoin(arrayfun(@num2str, oc, 'UniformOutput', false), '-');
        fprintf('%-8s %2d faixas  %-6s  oculta %-6s | treino %5.1f%%  valid %5.1f%%  teste %5.1f%% | epoca %4d | %4.1f s\n', ...
            metodos{m}, nb, normalizacoes{k}, txt_oc, 100*ac_tr, 100*ac_va, 100*ac_te, ...
            hist.melhor_epoca, t);
        res(end+1, :) = {metodos{m}, nb, normalizacoes{k}, txt_oc, ...
                         ac_tr, ac_va, ac_te, hist.melhor_epoca}; %#ok<SAGROW>

        % A melhor combinacao e escolhida pela VALIDACAO (acerto; em caso
        % de empate, menor erro quadratico), nunca pelo teste.
        if ac_va > melhor_acerto_va || (ac_va == melhor_acerto_va && erro_va < melhor_erro_va)
          melhor_acerto_va = ac_va;  melhor_erro_va = erro_va;
          modelo.rede = rede;  modelo.hist = hist;  modelo.stats = stats;
          modelo.metodo = metodos{m};  modelo.n_bandas = nb;
          modelo.normalizacao = normalizacoes{k};  modelo.ocultas = oc;
          modelo.classes = D.classes;  modelo.f_min = D.f_min;  modelo.f_max = D.f_max;
          modelo.modo = D.modo;  modelo.janela = D.janela;  modelo.passo = D.passo;
          modelo.acertos = [ac_tr, ac_va, ac_te];
          modelo.y_teste = D.y(te);
          modelo.prev_teste = mlp_classificar(rede, Xte);
          modelo.arquivos_teste = D.arquivos(te);
        end
      end
    end
  end
end

%% 3. SALVA A TABELA DE RESULTADOS ----------------------------------------
fid = fopen(fullfile(pasta_result, 'resultados.csv'), 'w');
fprintf(fid, 'metodo;faixas;normalizacao;ocultas;acerto_treino;acerto_validacao;acerto_teste;melhor_epoca\n');
for i = 1:size(res, 1)
    fprintf(fid, '%s;%d;%s;%s;%.3f;%.3f;%.3f;%d\n', res{i, :});
end
fclose(fid);

%% 4. MELHOR MODELO --------------------------------------------------------
fprintf('\n=== MELHOR COMBINACAO (escolhida pela validacao) ===\n');
fprintf('metodo %s | %d faixas | normalizacao %s | ocultas [%s]\n', ...
    modelo.metodo, modelo.n_bandas, modelo.normalizacao, num2str(modelo.ocultas));
fprintf('acertos: treino %.1f%% | validacao %.1f%% | teste %.1f%%\n', 100 * modelo.acertos);
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

% Figura: matriz de confusao
fig = figure('Visible', 'off');
imagesc(MC); colormap(flipud(gray)); colorbar;
set(gca, 'XTick', 1:nc, 'XTickLabel', modelo.classes, 'YTick', 1:nc, 'YTickLabel', modelo.classes);
xlabel('classe prevista'); ylabel('classe correta');
title(sprintf('Matriz de confusao (teste): %.1f%% de acerto', 100 * modelo.acertos(3)));
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
