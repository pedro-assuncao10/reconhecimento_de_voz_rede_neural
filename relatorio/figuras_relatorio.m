%% FIGURAS_RELATORIO.M - figuras do relatorio em PDF
%
% Nao e preciso para rodar o projeto: so gera as figuras usadas no
% relatorio, a partir dos resultados ja salvos.
%   deteccao_trecho.png  - Figura 1: deteccao das palavras e cortes (10 s)
%   ondas_cortes.png     - Figura 2: onda de 4 palavras com os cortes
%   palavra_janelas.png  - Figura 3: resposta da rede janela a janela
%   matriz_confusao.png  - Figura 4: matriz de confusao do teste
pasta_rel = fileparts(mfilename('fullpath'));
pasta_res = fullfile(pasta_rel, '..', 'rede_mlp', 'resultados');
addpath(fullfile(pasta_rel, '..', 'rede_mlp'));
pasta_fig = fullfile(pasta_rel, 'figuras');
set(0, 'defaultaxesfontsize', 15);  set(0, 'defaulttextfontsize', 15);  % letras legiveis no PDF
azul  = [42 120 214] / 255;     % cor principal
cinza = [184 183 176] / 255;    % silencio
laranja = [235 104 52] / 255;
tinta = [82 81 78] / 255;

%% 1. Resposta da rede janela a janela numa palavra (Figura 3)
load(fullfile(pasta_res, 'modelo_final.mat'), 'modelo');
p.janela = modelo.janela;  p.passo = modelo.passo;  p.n_conf = 1;  p.max_silencio = 0.3;
pasta_pal = fullfile(pasta_rel, '..', 'segmentacao', 'saida', 'palavras');
% Procura uma palavra de teste que so foi reconhecida gracas a tolerancia
num_de = @(nome) str2double(regexprep(nome, '^.*_(\d+)\.wav$', '$1'));
arqs = modelo.arquivos_teste;
cand = {};
for w = {'di_', 'es_'}
    nums = unique(cellfun(num_de, arqs(strncmp(arqs, w{1}, 3))));
    pal = 'direita';  if strcmp(w{1}, 'es_'), pal = 'esquerda'; end
    for num = nums(:)'
        cand(end+1, :) = {pal, num};
    end
end
escolha = [];
for i = 1:size(cand, 1)
    [x, fs] = audioread(fullfile(pasta_pal, sprintf('%s_%03d.wav', cand{i, 1}, cand{i, 2})));
    x = mean(x, 2);
    p.max_fora = 0;  r0 = reconhecer_palavra(x, fs, modelo, p);
    p.max_fora = 2;  [r2, reg] = reconhecer_palavra(x, fs, modelo, p);
    ok0 = ~isempty(r0) && strcmp(r0(1).palavra, cand{i, 1});
    ok2 = ~isempty(r2) && strcmp(r2(1).palavra, cand{i, 1});
    if ~ok0 && ok2 && strcmp(cand{i, 1}, 'direita'), escolha = i; break; end
end
if isempty(escolha), escolha = 1; end
[x, fs] = audioread(fullfile(pasta_pal, sprintf('%s_%03d.wav', cand{escolha, 1}, cand{escolha, 2})));
x = mean(x, 2);
p.max_fora = 2;  [r2, reg] = reconhecer_palavra(x, fs, modelo, p);
fprintf('Palavra do exemplo: %s_%03d\n', cand{escolha, 1}, cand{escolha, 2});
fprintf('Sequencia: %s\n', strjoin(modelo.classes(reg.classe), ' '));
fig = figure('Visible', 'off', 'Position', [0 0 1200 700]);
subplot(2, 1, 1);
plot((0:numel(x)-1) / fs, x, 'Color', [0.55 0.55 0.55]);
xlim([0 numel(x) / fs]);  set(gca, 'Box', 'off');
ylabel('amplitude');  title('audio da palavra');
subplot(2, 1, 2);  hold on;
nc = numel(modelo.classes);
seq = [1 2 3];  if strcmp(cand{escolha, 1}, 'esquerda'), seq = [4 5 6]; end
for k = 1:numel(reg.t)
    cor = cinza;  if any(reg.classe(k) == seq), cor = azul; end
    if reg.classe(k) ~= nc && ~any(reg.classe(k) == seq), cor = laranja; end
    plot(reg.t(k), reg.classe(k), 'o', 'MarkerSize', 8, 'MarkerFaceColor', cor, 'MarkerEdgeColor', 'w');
end
xlim([0 numel(x) / fs]);  ylim([0.5 nc + 0.5]);
set(gca, 'YTick', 1:nc, 'YTickLabel', modelo.classes, 'YDir', 'reverse', 'Box', 'off');
grid on;  set(gca, 'XGrid', 'off', 'GridAlpha', 0.15);
xlabel('tempo (s)');
title('resposta da rede em cada janela (um ponto a cada 25 ms)');
saveas(fig, fullfile(pasta_fig, 'palavra_janelas.png'));
close(fig);

%% 2. Deteccao das palavras nos primeiros 10 s (Figura 1)
% A mesma curva de volume de segmentar_audios.m (quadros de 20 ms a cada
% 10 ms, 250 a 6000 Hz, em dB, media de 3 quadros), com os cortes do CSV.
pasta_seg = fullfile(pasta_rel, '..', 'segmentacao');
[x, fs] = audioread(fullfile(pasta_seg, 'audios', 'direita.flac'));  x = mean(x, 2);
C = dlmread(fullfile(pasta_seg, 'saida', 'cortes_direita.csv'), ';', 1, 0);
J = round(0.020 * fs);  P = round(0.010 * fs);  nq = floor((numel(x) - J) / P) + 1;
Q = x((1:J)' + (0:nq-1) * P) .* (0.54 - 0.46 * cos(2*pi*(0:J-1)' / (J-1)));
X = abs(fft(Q)).^2;  X = X(1:floor(J/2)+1, :);  f = (0:floor(J/2))' * fs / J;
e = movmean(10 * log10(sum(X(f >= 250 & f <= 6000, :), 1) + 1e-10), 3);
v = sort(e);  piso = v(round(0.10 * numel(v)));
t = ((0:nq-1) * P + J/2) / fs;
fig = figure('Visible', 'off', 'Position', [0 0 1200 480]);
axes('Position', [0.08 0.3 0.9 0.66]);  hold on;
sel = t >= 0.5 & t <= 10.5;
for k = 1:size(C, 1)
    if C(k, 2) > 10.5, break; end
    patch([C(k,2) C(k,7) C(k,7) C(k,2)], [piso-10 piso-10 max(e)+5 max(e)+5], ...
          [0.85 0.9 0.97], 'EdgeColor', 'none');
    plot([1 1] * C(k, 5), [piso-10 max(e)+5], '-', 'Color', laranja, 'LineWidth', 1.2);
    plot([1 1] * C(k, 6), [piso-10 max(e)+5], '-', 'Color', laranja, 'LineWidth', 1.2);
end
h1 = plot(t(sel), e(sel), 'Color', azul, 'LineWidth', 1.2);
h2 = plot([0.5 10.5], [1 1] * (piso + 15), '--', 'Color', tinta);
h3 = patch(NaN, NaN, [0.85 0.9 0.97], 'EdgeColor', 'none');
h4 = plot(NaN, NaN, '-', 'Color', laranja, 'LineWidth', 1.2);
xlim([0.5 10.5]);  ylim([piso - 10, max(e) + 5]);
set(gca, 'Box', 'off', 'TickDir', 'out');
xlabel('tempo (s)');  ylabel('volume (dB)');
lg = legend([h1 h2 h3 h4], {'volume do som', 'limiar', 'palavra', 'cortes das silabas'}, ...
       'Orientation', 'horizontal');
set(lg, 'Position', [0.2 0.02 0.6 0.07]);
saveas(fig, fullfile(pasta_fig, 'deteccao_trecho.png'));
close(fig);

%% 3. Onda de 4 palavras com os cortes (Figura 2)
fig = figure('Visible', 'off', 'Position', [0 0 1200 760]);
exemplos = {'direita', 1; 'direita', 31; 'esquerda', 1; 'esquerda', 30};
for i = 1:4
    pal = exemplos{i, 1};  k = exemplos{i, 2};
    silabas = {'di', 'rei', 'ta'};  if strcmp(pal, 'esquerda'), silabas = {'es', 'quer', 'da'}; end
    [x, fs] = audioread(fullfile(pasta_seg, 'audios', [pal '.flac']));  x = mean(x, 2);
    C = dlmread(fullfile(pasta_seg, 'saida', ['cortes_' pal '.csv']), ';', 1, 0);
    lim = C(k, [2 5 6 7]);
    s0 = round((lim(1) - 0.06) * fs);  s1 = round((lim(4) + 0.06) * fs);
    tt = (s0:s1) / fs;  onda = x(s0:s1);  amp = max(abs(onda));
    subplot(2, 2, i);  hold on;
    plot(tt, onda, 'Color', [0.6 0.6 0.6]);
    env = sqrt(movmean(onda.^2, round(0.010 * fs)));
    plot(tt, env * amp / max(env), 'Color', azul, 'LineWidth', 1.5);
    for j = 2:3, plot([1 1] * lim(j), [-1 1] * amp, '-', 'Color', laranja, 'LineWidth', 2.5); end
    for j = [1 4], plot([1 1] * lim(j), [-1 1] * amp, 'k-', 'LineWidth', 1.5); end
    for j = 1:3
        text(mean(lim(j:j+1)), -0.8 * amp, silabas{j}, 'HorizontalAlignment', 'center', ...
             'FontWeight', 'bold', 'FontSize', 17);
    end
    xlim(tt([1 end]));  ylim([-1 1] * amp);  set(gca, 'YTick', [], 'Box', 'off');
    title(sprintf('"%s" n. %d', pal, k));  xlabel('tempo (s)');
end
saveas(fig, fullfile(pasta_fig, 'ondas_cortes.png'));
close(fig);

%% 4. Matriz de confusao do teste (Figura 4)
nc = numel(modelo.classes);  MC = zeros(nc);
for i = 1:numel(modelo.y_teste)
    MC(modelo.y_teste(i), modelo.prev_teste(i)) = MC(modelo.y_teste(i), modelo.prev_teste(i)) + 1;
end
fig = figure('Visible', 'off', 'Position', [0 0 900 760]);
imagesc(MC ./ sum(MC, 2));  colormap(flipud(gray) * 0.85 + 0.15);  caxis([0 1]);
set(gca, 'XTick', 1:nc, 'XTickLabel', modelo.classes, 'YTick', 1:nc, 'YTickLabel', modelo.classes);
for i = 1:nc
    for j = 1:nc
        cor = [0 0 0];  if MC(i, j) / sum(MC(i, :)) > 0.5, cor = [1 1 1]; end
        text(j, i, num2str(MC(i, j)), 'HorizontalAlignment', 'center', 'Color', cor, 'FontSize', 16);
    end
end
xlabel('resposta da rede');  ylabel('silaba dita');
saveas(fig, fullfile(pasta_fig, 'matriz_confusao.png'));
close(fig);


%% 5. Rede RBF: matriz de confusao do teste
% (as figuras abaixo sao do relatorio da RBF)
addpath(fullfile(pasta_rel, '..', 'rede_rbf'));
R = load(fullfile(pasta_rel, '..', 'rede_rbf', 'resultados', 'modelo_final.mat'));
mr = R.modelo;
nc = numel(mr.classes);  MC = zeros(nc);
for i = 1:numel(mr.y_teste)
    MC(mr.y_teste(i), mr.prev_teste(i)) = MC(mr.y_teste(i), mr.prev_teste(i)) + 1;
end
fig = figure('Visible', 'off', 'Position', [0 0 900 760]);
imagesc(MC ./ sum(MC, 2));  colormap(flipud(gray) * 0.85 + 0.15);  caxis([0 1]);
set(gca, 'XTick', 1:nc, 'XTickLabel', mr.classes, 'YTick', 1:nc, 'YTickLabel', mr.classes);
for i = 1:nc
    for j = 1:nc
        cor = [0 0 0];  if MC(i, j) / sum(MC(i, :)) > 0.5, cor = [1 1 1]; end
        text(j, i, num2str(MC(i, j)), 'HorizontalAlignment', 'center', 'Color', cor, 'FontSize', 16);
    end
end
xlabel('resposta da rede');  ylabel('silaba dita');
saveas(fig, fullfile(pasta_fig, 'matriz_confusao_rbf.png'));
close(fig);


%% 6. Rede RBF: erro da regra delta a cada epoca, com taxas e momento diferentes
% Mesma camada escondida da RBF escolhida (200 centros pelo WTA, raio unico
% 0,5 dmax, db); so muda o treino dos pesos da saida (saida linear).
Dr = rbf('dividir', load(fullfile(pasta_rel, '..', 'rede_rbf', 'entradas', 'entradas_energia_32_contexto.mat')));
tr = Dr.conj == 1;  va = Dr.conj == 3;
[Xtr, st] = entrada('normalizar', Dr.X(tr, :), 'db');  Xva = entrada('normalizar', Dr.X(va, :), 'db', st);
rng(1);
o = struct('K', 200, 'centros', 'wta', 'eta_c', 0.05, 'largura', 'unica', 'k', 0.5, 'T', 2, ...
           'saida', 'cholesky', 'ativ_saida', 'linear', 'taxa', 0);
rr = rbf('treinar', Xtr, Dr.y(tr), 7, o);
Phi = rbf('ativar', rr, Xtr);  Phiva = rbf('ativar', rr, Xva);
Y = zeros(sum(tr), 7);  Y(sub2ind(size(Y), (1:sum(tr))', Dr.y(tr))) = 1;
Yva = zeros(sum(va), 7);  Yva(sub2ind(size(Yva), (1:sum(va))', Dr.y(va))) = 1;
casos = {0.05, 0, 'taxa 0,05 (acima do limite): diverge'; ...
         0.02, 0, 'taxa 0,02 (perto do limite)'; ...
         0.005, 0, 'taxa 0,005 (abaixo do limite): lenta'; ...
         0.005, 0.9, 'taxa 0,005 com momento 0,9'};
cores = {[0.85 0.2 0.2], laranja, cinza * 0.6, azul};
n_ep = 1500;
fig = figure('Visible', 'off', 'Position', [0 0 1200 560]);
axes('Position', [0.09 0.14 0.6 0.8]);  hold on;
for c = 1:size(casos, 1)
    % O erro e medido a cada lote (fracao de epoca no eixo x), para a
    % divergencia, que acontece ja na 1a epoca, aparecer no grafico.
    rng(1);  W = zeros(size(Phi, 2), 7);  v = zeros(size(W));
    n_lotes = ceil(size(Phi, 1) / 32);
    x_ep = [];  erro = [];
    for ep = 1:n_ep
        ordem = randperm(size(Phi, 1));
        for b = 1:n_lotes
            idx = ordem((b-1)*32 + 1 : min(b*32, numel(ordem)));
            e = Y(idx, :) - Phi(idx, :) * W;
            v = casos{c, 2} * v + casos{c, 1} * Phi(idx, :)' * e / numel(idx);
            W = W + v;
            if ep <= 2 || b == n_lotes                 % todo lote no comeco, depois 1 por epoca
                x_ep(end+1) = ep - 1 + b / n_lotes;
                erro(end+1) = mean(mean((Yva - Phiva * W).^2));
            end
        end
        if ~isfinite(erro(end)) || erro(end) > 1e6, break; end   % explodiu: para
    end
    h(c) = plot(x_ep, min(erro, 1e3), 'Color', cores{c}, 'LineWidth', 2);
end
A = Phi' * Phi;  A(1:size(A,1)+1:end) = A(1:size(A,1)+1:end) + 1e-10 * mean(diag(A));
W = rbf('cholesky', A, Phi' * Y);
h(5) = plot([1 n_ep], [1 1] * mean(mean((Yva - Phiva * W).^2)), 'k--', 'LineWidth', 1.5);
set(gca, 'YScale', 'log', 'Box', 'off');  ylim([0.035 10]);  xlim([1 n_ep]);
xlabel('epoca');  ylabel('erro quadratico na validacao (escala log)');
lg = legend(h, [casos(:, 3); {'minimo exato (cholesky)'}]);
set(lg, 'Position', [0.71 0.45 0.27 0.3]);
saveas(fig, fullfile(pasta_fig, 'regra_delta_rbf.png'));
close(fig);
