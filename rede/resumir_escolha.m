%% ========================================================================
%  RESUMIR_ESCOLHA.M
%  ------------------------------------------------------------------------
%  Junta os resultados de escolher_arquitetura.m (todas as sementes) e
%  mostra, para cada configuracao, a MEDIA e o DESVIO PADRAO entre as
%  sementes. Ordena da melhor para a pior pela regra de escolha:
%  palavras de validacao; desempate pelo acerto medio das silabas.
%
%  Uso: octave --eval "etapa = 1; resumir_escolha"
%  Saidas: resultados/escolha/resumo_etapa<N>.csv e resumo_etapa<N>.png
%  ========================================================================

if ~exist('etapa', 'var'), etapa = 1; end
pasta_script = fileparts(mfilename('fullpath'));
pasta_saida  = fullfile(pasta_script, 'resultados', 'escolha');

% Le todos os CSVs desta etapa (um por semente)
lista = dir(fullfile(pasta_saida, sprintf('etapa%d_semente*.csv', etapa)));
chave = {};  M = [];      % chave da configuracao e numeros de cada linha
for k = 1:numel(lista)
    fid = fopen(fullfile(pasta_saida, lista(k).name));
    fgetl(fid);                                          % cabecalho
    C = textscan(fid, '%f %f %s %s %s %s %f %f %f %f %f %f %f %f %f %f %f %f %f %f', ...
                 'Delimiter', ';');
    fclose(fid);
    for i = 1:numel(C{1})
        chave{end+1, 1} = sprintf('%2d faixas | ctx %-3s | %-6s | oculta %-14s | %-8s | taxa %g', ...
            C{2}(i), C{3}{i}, C{4}{i}, C{5}{i}, C{6}{i}, C{7}(i));   %#ok<SAGROW>
        % colunas: silabas, di..da, palavras, janelas valid, treino, epoca, tempo
        M(end+1, :) = [C{11}(i), C{12}(i), C{13}(i), C{14}(i), C{15}(i), C{16}(i), ...
                       C{17}(i), C{18}(i), C{10}(i), C{9}(i), C{19}(i), C{20}(i)]; %#ok<SAGROW>
    end
end

[confs, ~, g] = unique(chave);         % (a ordem final vem do sortrows abaixo)
nc = numel(confs);
med = zeros(nc, size(M, 2));  dp = med;  n = zeros(nc, 1);
for c = 1:nc
    med(c, :) = mean(M(g == c, :), 1);
    dp(c, :)  = std(M(g == c, :), 0, 1);
    n(c) = sum(g == c);
end
% Regra de escolha: mais palavras; desempate: mais silabas
[~, ordem] = sortrows([med(:, 8), med(:, 1)], [-1 -2]);

fprintf('\n=== ETAPA %d: media +- desvio entre sementes (VALIDACAO) ===\n', etapa);
fprintf('%-71s | %-13s | %-13s | %-13s | %4s %4s %4s %4s %4s %4s | %-9s | sementes\n', ...
    'configuracao', 'palavras', 'silabas', 'janelas', 'di', 'rei', 'ta', 'es', 'quer', 'da', 'epoca');
fid = fopen(fullfile(pasta_saida, sprintf('resumo_etapa%d.csv', etapa)), 'w');
fprintf(fid, 'configuracao;silabas_media;silabas_desvio;palavras_media;palavras_desvio;janelas_media;janelas_desvio;di;rei;ta;es;quer;da;treino;epoca_media;tempo_medio_s;sementes\n');
for c = ordem'
    fprintf('%-71s | %5.1f +- %4.1f | %5.1f +- %4.1f | %5.1f +- %4.1f | %4.0f %4.0f %4.0f %4.0f %4.0f %4.0f | %4.0f      | %d\n', ...
        confs{c}, 100*med(c,8), 100*dp(c,8), 100*med(c,1), 100*dp(c,1), 100*med(c,9), 100*dp(c,9), ...
        100*med(c,2:7), med(c,11), n(c));
    fprintf(fid, '%s;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.1f;%.1f;%d\n', ...
        strtrim(confs{c}), med(c,1), dp(c,1), med(c,8), dp(c,8), med(c,9), dp(c,9), ...
        med(c,2:7), med(c,10), med(c,11), med(c,12), n(c));
end
fclose(fid);

% Grafico: dois paineis (palavras e silabas). Barra = media entre as
% sementes; traco preto = +- 1 desvio padrao. Da melhor para a pior.
fig = figure('Visible', 'off', 'Position', [0 0 1600 250 + 45 * nc]);
cols   = [8, 1];
nomes  = {'palavras de VALIDACAO reconhecidas (%)', 'acerto medio das 6 silabas na VALIDACAO (%)'};
cores  = {[0.85 0.55 0.3], [0.4 0.6 0.85]};
ax = zeros(1, 2);
for k = 1:2
    % posicao manual: margem larga a esquerda para o nome das configuracoes
    if k == 1, ax(k) = axes('Position', [0.30 0.12 0.32 0.78]);
    else,      ax(k) = axes('Position', [0.66 0.12 0.30 0.78]); end
    cl = cols(k);
    barh(1:nc, 100 * med(ordem, cl), 0.6, 'FaceColor', cores{k}); hold on;
    for i = 1:nc
        c = ordem(i);
        plot(100 * (med(c,cl) + [-1 1] * dp(c,cl)), [i i], 'k-', 'LineWidth', 1.5);
        text(100 * (med(c,cl) + dp(c,cl)) + 0.5, i, sprintf('%.1f +- %.1f', 100*med(c,cl), 100*dp(c,cl)));
    end
    if k == 1
        set(gca, 'YTick', 1:nc, 'YTickLabel', strtrim(confs(ordem)), 'YDir', 'reverse');
    else
        set(gca, 'YTick', 1:nc, 'YTickLabel', {}, 'YDir', 'reverse');
    end
    lo = 100 * min(med(:,cl) - dp(:,cl));  hi = 100 * max(med(:,cl) + dp(:,cl));
    xlim([max(0, floor(lo) - 3), min(100, ceil(hi)) + 8]);  ylim([0.4, nc + 0.6]);
    xlabel(nomes{k});
end
title(ax(1), sprintf('Etapa %d - media de %d sementes (barra) e +- 1 desvio (traco); ordem: palavras, depois silabas', etapa, max(n)));
saveas(fig, fullfile(pasta_saida, sprintf('resumo_etapa%d.png', etapa)));
close(fig);
fprintf('\nResumo salvo em: %s\n', pasta_saida);
