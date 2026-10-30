%% ========================================================================
%  PROGRAMA2_RECONHECER.M
%  ------------------------------------------------------------------------
%  Programa 2 do trabalho: reconhecimento das palavras inteiras DIREITA e
%  ESQUERDA a partir dos trechos que a rede aprendeu (treinar_mlp.m).
%  A logica (janela deslizante + maquina de estados) esta em
%  reconhecer_palavra.m.
%
%  Faz tres coisas:
%    PARTE 1 - Testa cada palavra de TESTE isoladamente (palavras que a
%              rede nunca viu no treino) e monta uma tabela de acertos.
%    PARTE 2 - Simula uma fala continua: emenda todas as palavras de teste
%              em ordem aleatoria, com silencio real entre elas, e mostra
%              o que o sistema reconhece ao longo do tempo.
%    PARTE 3 - (opcional) Reconhece um arquivo qualquer escolhido por
%              voce, ex.: uma gravacao nova. Basta preencher arquivo_extra.
%
%  Saidas (pasta resultados/):
%    programa2_fluxo.png - grafico da Parte 2
%  Requisito: rodar antes segmentar_audios.m, extrair_entradas.m e treinar_mlp.m
%  ========================================================================

clear; clc; close all;

%% 1. CONFIGURACAO ---------------------------------------------------------
pasta_script   = fileparts(mfilename('fullpath'));
pasta_palavras = fullfile(pasta_script, '..', 'segmentacao', 'saida', 'palavras');
pasta_sil      = fullfile(pasta_script, '..', 'segmentacao', 'saida', 'tercos', 'silencio');
pasta_result   = fullfile(pasta_script, 'resultados');

% PARTE 3: caminho de um .wav para reconhecer ('' = nao usar)
arquivo_extra = '';

rng(7);   % semente fixa para a ordem das palavras na Parte 2

% Carrega a melhor rede (e como normalizar as entradas para ela)
load(fullfile(pasta_result, 'modelo_final.mat'), 'modelo');

% Parametros da janela deslizante e da maquina de estados.
% A janela e o passo sao OS MESMOS usados para gerar as amostras de treino
% (extrair_entradas.m), por isso vem do proprio modelo.
p.janela       = modelo.janela;  % duracao de cada janela analisada (s) ~ uma silaba
p.passo        = modelo.passo;   % deslocamento entre janelas (s)
p.n_conf       = 1;      % janelas seguidas iguais para aceitar um trecho
                         % (com 2, a silaba do meio, que as vezes aparece
                         %  em uma janela so, era descartada)
p.max_silencio = 0.300;  % silencio maximo tolerado no meio de uma palavra (s)
fprintf('Rede: metodo %s | %d faixas | %s | ocultas [%s]\n\n', modelo.metodo, ...
    modelo.n_bandas, modelo.normalizacao, num2str(modelo.ocultas));

% Descobre quais repeticoes sao de TESTE a partir dos arquivos de teste
% guardados no modelo (ex.: 'di_005.wav' -> direita no 5; 'es_012.wav' ->
% esquerda no 12; 'silencio_020.wav' -> silencio no 20).
num_de = @(nome) str2double(regexprep(nome, '^.*_(\d+)\.wav$', '$1'));
arqs = modelo.arquivos_teste;
teste_dir = sort(cellfun(num_de, arqs(strncmp(arqs, 'di_', 3))));
teste_esq = sort(cellfun(num_de, arqs(strncmp(arqs, 'es_', 3))));
teste_sil = sort(cellfun(num_de, arqs(strncmp(arqs, 'silencio_', 9))));

%% 2. PARTE 1 - CADA PALAVRA DE TESTE ISOLADA -----------------------------
fprintf('=== PARTE 1: palavras de teste isoladas ===\n');
nomes   = {'direita', 'esquerda'};
listas  = {teste_dir, teste_esq};
saidas  = {'direita', 'esquerda', 'nada'};
T = zeros(2, 3);          % linhas: palavra dita; colunas: o que o sistema disse

for w = 1:2
    for num = listas{w}(:)'
        [x, fs] = audioread(fullfile(pasta_palavras, sprintf('%s_%03d.wav', nomes{w}, num)));
        x = mean(x, 2);
        r = reconhecer_palavra(x, fs, modelo, p);
        if isempty(r)
            resp = 3;                                      % nada reconhecido
        else
            resp = find(strcmp(saidas, r(1).palavra));     % 1a palavra reconhecida
        end
        T(w, resp) = T(w, resp) + 1;
    end
end

fprintf('%10s | %8s %8s %8s | acerto\n', 'dita', saidas{:});
for w = 1:2
    fprintf('%10s | %8d %8d %8d | %5.1f%%\n', nomes{w}, T(w, :), 100 * T(w, w) / sum(T(w, :)));
end
fprintf('Acerto geral: %.1f%% (%d de %d palavras)\n\n', ...
    100 * trace(T(:, 1:2)) / sum(T(:)), trace(T(:, 1:2)), sum(T(:)));

%% 3. PARTE 2 - FALA CONTINUA SIMULADA ------------------------------------
fprintf('=== PARTE 2: fala continua (palavras de teste emendadas) ===\n');
% Lista de palavras em ordem aleatoria: [palavra(1/2), numero]
fila = [ones(numel(teste_dir), 1), teste_dir(:); 2 * ones(numel(teste_esq), 1), teste_esq(:)];
fila = fila(randperm(size(fila, 1)), :);

% Silencio "de verdade" (ruido da sala) vindo das amostras de TESTE
sil = [];
for num = teste_sil(:)'
    [s, fs] = audioread(fullfile(pasta_sil, sprintf('silencio_%03d.wav', num)));
    sil = [sil; mean(s, 2)]; %#ok<AGROW>
end
n_pausa = round(0.45 * fs);               % pausa de ~0,45 s entre palavras

% Monta o fluxo: pausa, palavra, pausa, palavra, ...
fluxo = [];  verdade = zeros(size(fila, 1), 3);    % [palavra, t_inicio, t_fim]
pos_sil = 1;
for i = 1:size(fila, 1)
    pausa = sil(pos_sil : pos_sil + n_pausa - 1);  % pega um pedaco do silencio
    pos_sil = mod(pos_sil + n_pausa - 1, numel(sil) - n_pausa) + 1;
    [x, fs] = audioread(fullfile(pasta_palavras, sprintf('%s_%03d.wav', nomes{fila(i,1)}, fila(i,2))));
    x = mean(x, 2);
    fluxo = [fluxo; pausa]; %#ok<AGROW>
    verdade(i, :) = [fila(i,1), numel(fluxo) / fs, (numel(fluxo) + numel(x)) / fs];
    fluxo = [fluxo; x]; %#ok<AGROW>
end
fluxo = [fluxo; sil(1:n_pausa)];

[rec, reg] = reconhecer_palavra(fluxo, fs, modelo, p);

% Compara: cada palavra dita deve ser reconhecida enquanto e falada
% (ate 0,3 s depois do fim, para dar tempo das ultimas janelas).
usada = false(1, numel(rec));
certas = 0; trocadas = 0; perdidas = 0;
for i = 1:size(verdade, 1)
    achou = 0;
    for j = 1:numel(rec)
        if ~usada(j) && rec(j).tempo >= verdade(i, 2) && rec(j).tempo <= verdade(i, 3) + 0.3
            achou = j; break;
        end
    end
    if achou == 0
        perdidas = perdidas + 1;
    else
        usada(achou) = true;
        if strcmp(rec(achou).palavra, nomes{verdade(i, 1)})
            certas = certas + 1;
        else
            trocadas = trocadas + 1;
        end
    end
end
falsos = sum(~usada);   % reconhecimentos sem nenhuma palavra dita

fprintf('Palavras faladas: %d | reconhecidas certas: %d | trocadas: %d | perdidas: %d | falsos alarmes: %d\n', ...
    size(verdade, 1), certas, trocadas, perdidas, falsos);
fprintf('Acerto no fluxo: %.1f%%\n\n', 100 * certas / size(verdade, 1));

% Grafico: em cima o audio com o que foi dito; embaixo a resposta da rede
% em cada janela e as palavras reconhecidas.
fig = figure('Visible', 'off', 'Position', [0 0 1800 700]);
subplot(2, 1, 1);
plot((0:numel(fluxo)-1) / fs, fluxo, 'Color', [0.5 0.5 0.5]); hold on;
for i = 1:size(verdade, 1)
    text(mean(verdade(i, 2:3)), 0.9 * max(abs(fluxo)), nomes{verdade(i,1)}(1:3), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end
for j = 1:numel(rec)
    cor = [0 0.6 0]; if ~usada(j), cor = [0.8 0 0]; end
    plot(rec(j).tempo, -0.9 * max(abs(fluxo)), 'v', 'Color', cor, 'MarkerFaceColor', cor);
    text(rec(j).tempo, -0.75 * max(abs(fluxo)), rec(j).palavra(1:3), 'Color', cor, ...
        'HorizontalAlignment', 'center');
end
xlim([0 numel(fluxo) / fs]);
title('Fala continua: em cima, o que foi dito | embaixo (triangulos), o que o sistema reconheceu');
subplot(2, 1, 2);
stairs(reg.t, reg.classe, 'b'); xlim([0 numel(fluxo) / fs]); ylim([0.5 numel(modelo.classes) + 0.5]);
set(gca, 'YTick', 1:numel(modelo.classes), 'YTickLabel', modelo.classes);
xlabel('tempo (s)'); title('Resposta da rede em cada janela');
saveas(fig, fullfile(pasta_result, 'programa2_fluxo.png')); close(fig);

%% 4. PARTE 3 - ARQUIVO ESCOLHIDO (opcional) ------------------------------
if ~isempty(arquivo_extra)
    fprintf('=== PARTE 3: %s ===\n', arquivo_extra);
    [x, fs] = audioread(arquivo_extra);
    rec = reconhecer_palavra(mean(x, 2), fs, modelo, p);
    if isempty(rec)
        fprintf('Nenhuma palavra reconhecida.\n');
    end
    for j = 1:numel(rec)
        fprintf('%6.2f s: %s\n', rec(j).tempo, upper(rec(j).palavra));
    end
end

fprintf('Grafico salvo em: %s\n', fullfile(pasta_result, 'programa2_fluxo.png'));
