%% TREINAR_RBF.M - treino final da rede RBF e medida no teste
%
% Treina a RBF (feita a mao, em rbf.m) para reconhecer as 7 classes: di,
% rei, ta, es, quer, da e silencio. Usa as mesmas janelas e o mesmo
% reconhecedor de palavras da MLP, com a divisao pedida no enunciado da
% RBF: treino 75%, validacao 15%, teste 10% (rbf('dividir')).
%
% A configuracao foi escolhida nos experimentos (experimentos_rbf.m), uma
% etapa por vez, sempre pela validacao, seguindo o algoritmo da aula:
%   - entrada: 32 faixas, com contexto (160 entradas)               (etapa 1)
%   - normalizacao db                                               (etapa 2)
%   - 200 neuronios escondidos                                      (etapa 3)
%   - centros pelo algoritmo WTA, taxa 0,05                         (etapa 4)
%   - abertura: raio unico, 0,5 x a maior distancia entre centros   (etapa 5)
%   - pesos da saida pela regra delta, saida sigmoide, taxa 0,1 e
%     momento 0,9, como no treino da MLP                            (etapa 6)
% Essa configuracao e treinada com 5 sementes, e fica a rede que reconhece
% mais palavras na validacao.
%
% Saidas (pasta resultados/):
%   resultados.csv      - acertos de cada rede treinada
%   modelo_final.mat    - a rede escolhida e tudo que o programa 2 precisa
%   matriz_confusao.png - acertos e trocas de cada classe no teste
%
% Antes, rodar segmentar_audios.m e extrair_entradas.m.

clear; clc; close all;

%% 1. Configuracao
pasta_script = fileparts(mfilename('fullpath'));
pasta_entradas = fullfile(pasta_script, 'entradas');
pasta_result   = fullfile(pasta_script, 'resultados');
pasta_palavras = fullfile(pasta_script, '..', 'segmentacao', 'saida', 'palavras');
if ~exist(pasta_result, 'dir'), mkdir(pasta_result); end

o.K = 200;                                          % neuronios escondidos
o.centros = 'wta';  o.eta_c = 0.05;                 % centros (WTA)
o.largura = 'unica';  o.k = 0.5;  o.T = 2;          % abertura: s = 0,5 dmax
o.saida = 'delta';  o.ativ_saida = 'sigmoide';      % pesos da saida (regra delta)
o.taxa = 0.1;  o.momento = 0.9;  o.epocas = 5000;
normalizacao = 'db';
sementes = 1:5;

% Reconhecimento de palavras (os mesmos parametros do programa 2)
p_rec.n_conf = 1;  p_rec.max_silencio = 0.300;  p_rec.max_fora = 2;

D = load(fullfile(pasta_entradas, 'entradas_energia_32_contexto.mat'));
D = rbf('dividir', D);                    % treino 75%, validacao 15%, teste 10%
n_classes = numel(D.classes);
tr = D.conj == 1;  te = D.conj == 2;  va = D.conj == 3;
[Xtr, stats] = entrada('normalizar', D.X(tr, :), normalizacao);
Xva = entrada('normalizar', D.X(va, :), normalizacao, stats);
Xte = entrada('normalizar', D.X(te, :), normalizacao, stats);

% Palavras inteiras de validacao e de teste. Uma repeticao e de validacao
% ou de teste se as janelas da 1a silaba (di_ ou es_) estao nesse conjunto.
nomes_pal = {'direita', 'esquerda'};  prim = {'di_', 'es_'};
num_de = @(nome) str2double(regexprep(nome, '^.*_(\d+)\.wav$', '$1'));
pal = struct('audio', {}, 'palavra', {}, 'conj', {});
for w = 1:2
    sel = strncmp(D.arquivos, prim{w}, 3) & D.conj ~= 1;
    for num = unique(cellfun(num_de, D.arquivos(sel)))'
        [x, fs_pal] = audioread(fullfile(pasta_palavras, sprintf('%s_%03d.wav', nomes_pal{w}, num)));
        cj = D.conj(find(sel & strcmp(D.arquivos, sprintf('%s%03d.wav', prim{w}, num)), 1));
        pal(end+1) = struct('audio', mean(x, 2), 'palavra', nomes_pal{w}, 'conj', cj);
    end
end
pal_va = [pal.conj] == 3;  pal_te = [pal.conj] == 2;
fprintf('Palavras inteiras: %d de validacao, %d de teste\n\n', sum(pal_va), sum(pal_te));

%% 2. Treina uma rede por semente
res = [];
melhor = [-Inf, -Inf];   % criterio: [palavras de validacao, janelas de validacao]
for sd = sementes
    rng(sd);
    tic;
    rede = rbf('treinar', Xtr, D.y(tr), n_classes, o, Xva, D.y(va));
    t = toc;

    ac_tr = mean(rbf('classificar', rede, Xtr) == D.y(tr));
    ac_va = mean(rbf('classificar', rede, Xva) == D.y(va));
    prev_te = rbf('classificar', rede, Xte);
    ac_te = mean(prev_te == D.y(te));
    yt = D.y(te);
    ac_sil = mean(arrayfun(@(c) mean(prev_te(yt == c) == c), 1:6));

    % Acerto por palavra: cada palavra inteira passa pelo reconhecedor
    m_tmp = struct('tipo', 'rbf', 'rede', rede, 'stats', stats, 'n_bandas', D.n_bandas, ...
        'normalizacao', normalizacao, 'classes', {D.classes}, 'f_min', D.f_min, ...
        'f_max', D.f_max, 'contexto', D.contexto);
    p_rec.janela = D.janela;  p_rec.passo = D.passo;
    certa = false(1, numel(pal));
    for i = 1:numel(pal)
        r = reconhecer_palavra(pal(i).audio, fs_pal, m_tmp, p_rec);
        certa(i) = ~isempty(r) && strcmp(r(1).palavra, pal(i).palavra);
    end
    pa_va = mean(certa(pal_va));  pa_te = mean(certa(pal_te));

    fprintf('semente %d | janelas: treino %5.1f%%  valid %5.1f%%  teste %5.1f%% | silabas teste %5.1f%% | palavras: valid %2d/%d  teste %2d/%d | %4.1f s\n', ...
        sd, 100*ac_tr, 100*ac_va, 100*ac_te, 100*ac_sil, sum(certa(pal_va)), sum(pal_va), ...
        sum(certa(pal_te)), sum(pal_te), t);
    res(end+1, :) = [sd, ac_tr, ac_va, ac_te, ac_sil, pa_va, pa_te, t];

    % A rede que fica e escolhida pela validacao, nunca pelo teste
    criterio = [pa_va, ac_va];
    if criterio(1) > melhor(1) || (criterio(1) == melhor(1) && criterio(2) > melhor(2))
        melhor = criterio;
        modelo = m_tmp;
        modelo.opcoes = o;  modelo.semente = sd;
        modelo.janela = D.janela;  modelo.passo = D.passo;  modelo.metodo = 'energia';
        modelo.acertos = [ac_tr, ac_va, ac_te];
        modelo.acertos_palavras = [pa_va, pa_te];
        modelo.y_teste = yt;  modelo.prev_teste = prev_te;
        modelo.arquivos_teste = D.arquivos(te);
    end
end

%% 3. Tabela e rede escolhida
fid = fopen(fullfile(pasta_result, 'resultados.csv'), 'w');
fprintf(fid, 'semente;acerto_treino;acerto_validacao;acerto_teste;silabas_teste;palavras_validacao;palavras_teste;tempo_s\n');
fprintf(fid, '%d;%.3f;%.3f;%.3f;%.3f;%.3f;%.3f;%.1f\n', res');
fclose(fid);

fprintf('\n=== Rede escolhida (pela validacao): semente %d ===\n', modelo.semente);
fprintf('janelas:  treino %.1f%% | validacao %.1f%% | teste %.1f%%\n', 100 * modelo.acertos);
fprintf('palavras: validacao %.1f%% | teste %.1f%%\n', 100 * modelo.acertos_palavras);
save(fullfile(pasta_result, 'modelo_final.mat'), 'modelo', '-v7');

% Matriz de confusao do teste: linha = classe dita, coluna = resposta da rede
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
ac_classe = diag(MC)' ./ sum(MC, 2)';
fprintf('%9s', 'acerto'); fprintf('%8.0f%%', 100 * ac_classe); fprintf('\n');
fprintf('Acerto medio das 6 silabas (sem o silencio): %.1f%%\n', 100 * mean(ac_classe(1:6)));

fig = figure('Visible', 'off', 'Position', [0 0 1000 800]);
imagesc(MC); colormap(flipud(gray)); colorbar;
set(gca, 'XTick', 1:nc, 'XTickLabel', modelo.classes, 'YTick', 1:nc, 'YTickLabel', modelo.classes);
xlabel('o que a rede respondeu (classe prevista)'); ylabel('o que foi dito (classe correta)');
title(sprintf('RBF - matriz de confusao das janelas de teste (%.1f%% de acerto)', 100 * modelo.acertos(3)));
for i = 1:nc
    for j = 1:nc
        text(j, i, num2str(MC(i, j)), 'HorizontalAlignment', 'center', 'Color', [0.8 0 0]);
    end
end
saveas(fig, fullfile(pasta_result, 'matriz_confusao.png')); close(fig);
fprintf('\nResultados salvos em: %s\n', pasta_result);
