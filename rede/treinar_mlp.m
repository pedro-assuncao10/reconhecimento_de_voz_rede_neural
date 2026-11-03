%% TREINAR_MLP.M - treino final da rede e medida no teste
%
% Treina a MLP (feita a mao, em mlp.m) para reconhecer as 7 classes: di,
% rei, ta, es, quer, da e silencio.
%
% A configuracao usada foi escolhida nos experimentos (experimentos.m),
% uma etapa por vez, sempre pela validacao:
%   - corte das silabas nos vales de energia
%   - entrada: 32 faixas de frequencia, com contexto (160 entradas)
%   - normalizacao max
%   - camadas ocultas de 64 e 32 neuronios, sigmoide, taxa 0,5
% Essa configuracao e treinada com 5 sementes (5 sorteios diferentes dos
% pesos iniciais), e fica a rede que reconhece mais palavras na
% validacao. As listas da secao 1 aceitam mais de uma opcao, se quiser
% comparar outras combinacoes.
%
% Os dados ja vem divididos por extrair_entradas.m:
%   - treino (60%): ajusta os pesos;
%   - validacao (20%): decide quando parar o treino e qual rede fica;
%   - teste (20%): so mede o resultado final; nao entra em nenhuma escolha.
%
% Cada rede e medida de dois jeitos:
%   - por janela: fracao das janelas de 150 ms classificadas certo;
%   - por palavra: cada palavra inteira passa pelo reconhecedor do
%     programa 2 (reconhecer_palavra.m). E o objetivo do trabalho, por
%     isso a rede e escolhida pelas palavras da validacao.
%
% Saidas (pasta resultados/):
%   resultados.csv      - acertos de cada rede treinada
%   modelo_final.mat    - a rede escolhida e tudo que o programa 2 precisa
%   matriz_confusao.png - acertos e trocas de cada classe no teste
%   curva_treino.png    - erro por epoca da rede escolhida
%
% Antes, rodar extrair_entradas.m.

clear; clc; close all;

%% 1. Configuracao
pasta_script = fileparts(mfilename('fullpath'));
pasta_entradas = fullfile(pasta_script, 'entradas');
pasta_result   = fullfile(pasta_script, 'resultados');
if ~exist(pasta_result, 'dir'), mkdir(pasta_result); end

% Opcoes (uma so de cada, a configuracao escolhida)
metodos       = {'energia'};             % (opcoes: 'tercos', 'energia')
lista_bandas  = [32];                    % (opcoes: 32, 64)
normalizacoes = {'max'};                 % (opcoes: 'max', 'db', 'zscore')
arquiteturas  = {[64 32]};               % neuronios por camada oculta:
                                         % [32] = uma camada de 32;
                                         % [64 32] = duas camadas, de 64 e de 32
contextos     = {[-4 -2 0 2 4]};         % [0] = so a janela atual (sem contexto);
                                         % [-4 -2 0 2 4] = atual e as vizinhas
                                         % a 50 e 100 ms (ver entrada.m)
ativacoes     = {'sigmoide'};            % funcao das camadas ocultas
                                         % (opcoes: 'sigmoide', 'relu')
taxas         = [0.5];                   % taxa de aprendizado de cada ativacao
sementes      = 1:5;                     % sorteios dos pesos iniciais

% Parametros do treino (a taxa de aprendizado p.taxa vem da lista 'taxas')
p.momento    = 0.9;    % momento: aproveita parte do passo anterior
p.epocas_max = 800;    % no maximo 800 epocas
p.tam_lote   = 32;     % amostras por atualizacao dos pesos
p.paciencia  = 200;    % para se a validacao nao melhorar em 200 epocas seguidas

% Parametros do reconhecimento de palavras (os mesmos do programa2_reconhecer.m)
p_rec.n_conf       = 1;
p_rec.max_silencio = 0.300;
p_rec.max_fora     = 2;

% Palavras inteiras de validacao e de teste, para medir o reconhecimento
% de palavras. A divisao e a mesma para todas as combinacoes.
pasta_palavras = fullfile(pasta_script, '..', 'segmentacao', 'saida', 'palavras');
suf = '';  if ~isequal(contextos{1}, 0), suf = '_contexto'; end
D = load(fullfile(pasta_entradas, sprintf('entradas_%s_%d%s.mat', metodos{1}, lista_bandas(1), suf)));
% Uma repeticao e de validacao ou de teste se as janelas da 1a silaba
% (di_ ou es_) estao nesse conjunto. Cada repeticao tem varias janelas,
% por isso o unique.
nomes_pal = {'direita', 'esquerda'};  prim = {'di_', 'es_'};
num_de = @(nome) str2double(regexprep(nome, '^.*_(\d+)\.wav$', '$1'));
pal = struct('audio', {}, 'palavra', {}, 'conj', {});   % uma por palavra
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

%% 2. Treina cada combinacao
res = {};          % uma linha por combinacao
melhor = [-Inf, -Inf, -Inf];   % criterio da melhor rede ate agora (ver abaixo)

for m = 1:numel(metodos)
  for nb = lista_bandas
   for ic = 1:numel(contextos)
    % Entradas desta combinacao (corte x faixas x contexto)
    suf = '';  if ~isequal(contextos{ic}, 0), suf = '_contexto'; end
    D = load(fullfile(pasta_entradas, sprintf('entradas_%s_%d%s.mat', metodos{m}, nb, suf)));
    txt_ctx = 'nao';  if ~isequal(D.contexto, 0), txt_ctx = 'sim'; end
    n_classes = numel(D.classes);

    % Saida desejada: 1 no neuronio da classe certa e 0 nos outros
    Y = zeros(numel(D.y), n_classes);
    Y(sub2ind(size(Y), (1:numel(D.y))', D.y)) = 1;

    tr = D.conj == 1;  te = D.conj == 2;  va = D.conj == 3;

    for k = 1:numel(normalizacoes)
      % Normaliza (no zscore, a media e o desvio vem so do treino)
      [Xtr, stats] = entrada('normalizar', D.X(tr, :), normalizacoes{k});
      Xva = entrada('normalizar', D.X(va, :), normalizacoes{k}, stats);
      Xte = entrada('normalizar', D.X(te, :), normalizacoes{k}, stats);

      for a = 1:numel(arquiteturas)
       for f = 1:numel(ativacoes)
        for sd = sementes
        oc = arquiteturas{a};
        p.taxa = taxas(f);
        rng(sd);   % semente dos pesos iniciais
        rede = mlp('criar', size(D.X, 2), oc, n_classes, ativacoes{f});
        tic;
        [rede, hist] = mlp('treinar', rede, Xtr, Y(tr, :), Xva, Y(va, :), p);
        t = toc;

        % Acerto por janela em cada conjunto
        ac_tr = mean(mlp('classificar', rede, Xtr) == D.y(tr));
        ac_va = mean(mlp('classificar', rede, Xva) == D.y(va));
        prev_te = mlp('classificar', rede, Xte);
        ac_te = mean(prev_te == D.y(te));
        erro_va = hist.erro_va(hist.melhor_epoca);
        % Acerto medio das 6 silabas no teste (o silencio fica de fora,
        % porque ele quase sempre acerta)
        yt = D.y(te);
        ac_sil = mean(arrayfun(@(c) mean(prev_te(yt == c) == c), 1:6));

        % Acerto por palavra: cada palavra inteira passa pelo reconhecedor
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
                         ac_tr, ac_va, ac_te, ac_sil, pa_va, pa_te, hist.melhor_epoca};

        % A rede que fica e escolhida pela validacao, nunca pelo teste:
        % primeiro, mais palavras de validacao; se empatar, mais janelas
        % certas na validacao; se empatar de novo, menor erro.
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
          modelo.prev_teste = mlp('classificar', rede, Xte);
          modelo.arquivos_teste = D.arquivos(te);
        end
        end
       end
      end
    end
   end
  end
end

%% 3. Tabela com o resultado de cada rede
fid = fopen(fullfile(pasta_result, 'resultados.csv'), 'w');
fprintf(fid, ['metodo;faixas;contexto;normalizacao;ocultas;ativacao;taxa;semente;acerto_treino;acerto_validacao;acerto_teste;' ...
              'silabas_teste;palavras_validacao;palavras_teste;melhor_epoca\n']);
for i = 1:size(res, 1)
    fprintf(fid, '%s;%d;%s;%s;%s;%s;%g;%d;%.3f;%.3f;%.3f;%.3f;%.3f;%.3f;%d\n', res{i, :});
end
fclose(fid);

%% 4. Rede escolhida: resultado, matriz de confusao e curva de treino
fprintf('\n=== Rede escolhida (pela validacao) ===\n');
fprintf('metodo %s | %d faixas | normalizacao %s | ocultas [%s] | ativacao %s | taxa %g | contexto [%s] passos | semente %d\n', ...
    modelo.metodo, modelo.n_bandas, modelo.normalizacao, num2str(modelo.ocultas), ...
    modelo.ativacao, modelo.taxa, num2str(modelo.contexto), modelo.semente);
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
% Acerto de cada classe = diagonal / total da linha
ac_classe = diag(MC)' ./ sum(MC, 2)';
fprintf('%9s', 'acerto'); fprintf('%8.0f%%', 100 * ac_classe); fprintf('\n');
fprintf('Acerto medio das 6 silabas (sem o silencio): %.1f%%\n', 100 * mean(ac_classe(1:6)));

% Figura: matriz de confusao
fig = figure('Visible', 'off', 'Position', [0 0 1000 800]);
imagesc(MC); colormap(flipud(gray)); colorbar;
set(gca, 'XTick', 1:nc, 'XTickLabel', modelo.classes, 'YTick', 1:nc, 'YTickLabel', modelo.classes);
xlabel('o que a rede respondeu (classe prevista)'); ylabel('o que foi dito (classe correta)');
title(sprintf('Matriz de confusao - janelas de teste (%.1f%% de acerto). Diagonal = acertos', ...
              100 * modelo.acertos(3)));
for i = 1:nc
    for j = 1:nc
        text(j, i, num2str(MC(i, j)), 'HorizontalAlignment', 'center', 'Color', [0.8 0 0]);
    end
end
saveas(fig, fullfile(pasta_result, 'matriz_confusao.png')); close(fig);

% Figura: curva de aprendizado da rede escolhida
fig = figure('Visible', 'off');
plot(modelo.hist.erro_tr, 'b'); hold on; plot(modelo.hist.erro_va, 'r');
xline_y = ylim; plot([1 1] * modelo.hist.melhor_epoca, xline_y, 'k--');
legend('treino', 'validacao', 'rede escolhida');
xlabel('epoca'); ylabel('erro quadratico medio');
title('Curva de aprendizado da rede escolhida');
saveas(fig, fullfile(pasta_result, 'curva_treino.png')); close(fig);

fprintf('\nResultados salvos em: %s\n', pasta_result);
