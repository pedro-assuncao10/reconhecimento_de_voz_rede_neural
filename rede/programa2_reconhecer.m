function programa2_reconhecer(tipo)
    % PROGRAMA2_RECONHECER  Programa 2: reconhecimento das palavras
    %
    % Reconhece as palavras inteiras DIREITA e ESQUERDA usando a rede treinada
    % (treinar_mlp.m). A janela deslizante e a maquina de estados estao em
    % reconhecer_palavra.m.
    %
    % Faz tres coisas:
    %   Parte 1 - reconhece cada palavra de teste sozinha (palavras que a rede
    %             nunca viu no treino) e mostra uma tabela de acertos.
    %   Parte 2 - simula uma fala continua: emenda todas as palavras de teste,
    %             em ordem sorteada, com silencio de verdade entre elas, e
    %             confere o que o sistema reconhece ao longo do tempo.
    %   Parte 3 - (opcional) reconhece um arquivo .wav qualquer, por exemplo
    %             uma gravacao nova. Basta preencher arquivo_extra.
    %
    % Saida (pasta resultados/): programa2_fluxo.png, o grafico da Parte 2.
    %
    % Uso:
    %   programa2_reconhecer          com a rede MLP (rede/resultados/)
    %   programa2_reconhecer('rbf')   com a rede RBF (rede_rbf/resultados/)
    %
    % Antes, rodar segmentar_audios.m e o treino da rede (treinar_mlp.m ou
    % treinar_rbf.m), ou usar a rede que ja esta salva em modelo_final.mat.

    if nargin < 1, tipo = 'mlp'; end
    close all;

    %% 1. Configuracao
    pasta_script   = fileparts(mfilename('fullpath'));
    pasta_palavras = fullfile(pasta_script, '..', 'segmentacao', 'saida', 'palavras');
    pasta_sil      = fullfile(pasta_script, '..', 'segmentacao', 'saida', 'energia', 'silencio');
    if strcmp(tipo, 'rbf')
        pasta_result = fullfile(pasta_script, '..', 'rede_rbf', 'resultados');
        addpath(fullfile(pasta_script, '..', 'rede_rbf'));   % rbf.m
    else
        pasta_result = fullfile(pasta_script, 'resultados');
    end

    % Parte 3: caminho de um .wav para reconhecer ('' = nao usar)
    arquivo_extra = '';

    rng(7);   % semente fixa: a ordem das palavras da Parte 2 sai sempre igual

    % Carrega a rede treinada (e como normalizar as entradas para ela)
    load(fullfile(pasta_result, 'modelo_final.mat'), 'modelo');

    % Parametros da janela deslizante e da maquina de estados. A janela e o
    % passo sao os mesmos do treino (extrair_entradas.m), por isso vem do
    % proprio modelo.
    p.janela       = modelo.janela;  % duracao de cada janela (150 ms)
    p.passo        = modelo.passo;   % quanto a janela anda de cada vez (25 ms)
    p.n_conf       = 1;      % janelas seguidas iguais para aceitar uma silaba
                             % (com 2, a silaba do meio, que as vezes aparece
                             % numa janela so, era perdida)
    p.max_silencio = 0.300;  % silencio maximo tolerado no meio de uma palavra (s)
    p.max_fora     = 2;      % janelas seguidas fora da ordem que sao ignoradas
                             % (erro isolado da rede). Uma silaba falada ocupa
                             % de 6 a 10 janelas, entao uma silaba trocada de
                             % verdade continua reprovando a palavra
    if strcmp(tipo, 'rbf')
        fprintf('Rede RBF: %d faixas | %s | %d neuronios | centros %s | abertura %s | saida %s %s | contexto [%s]\n\n', ...
            modelo.n_bandas, modelo.normalizacao, size(modelo.rede.C, 1), modelo.opcoes.centros, ...
            modelo.opcoes.largura, modelo.opcoes.saida, modelo.opcoes.ativ_saida, num2str(modelo.contexto));
    else
        fprintf('Rede MLP: metodo %s | %d faixas | %s | ocultas [%s] | %s | contexto [%s]\n\n', modelo.metodo, ...
            modelo.n_bandas, modelo.normalizacao, num2str(modelo.ocultas), modelo.ativacao, num2str(modelo.contexto));
    end

    % Quais repeticoes sao de teste, pelos nomes guardados no modelo.
    % Ex.: 'di_005.wav' e a direita n. 5; 'es_012.wav', a esquerda n. 12;
    % 'silencio_020.wav', o silencio n. 20.
    num_de = @(nome) str2double(regexprep(nome, '^.*_(\d+)\.wav$', '$1'));
    arqs = modelo.arquivos_teste;
    teste_dir = unique(cellfun(num_de, arqs(strncmp(arqs, 'di_', 3))));
    teste_esq = unique(cellfun(num_de, arqs(strncmp(arqs, 'es_', 3))));
    teste_sil = unique(cellfun(num_de, arqs(strncmp(arqs, 'silencio_', 9))));

    %% 2. Parte 1: cada palavra de teste sozinha
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

    %% 3. Parte 2: fala continua simulada
    fprintf('=== PARTE 2: fala continua (palavras de teste emendadas) ===\n');
    % Palavras em ordem sorteada: [palavra (1 = direita, 2 = esquerda), numero]
    fila = [ones(numel(teste_dir), 1), teste_dir(:); 2 * ones(numel(teste_esq), 1), teste_esq(:)];
    fila = fila(randperm(size(fila, 1)), :);

    % Silencio de verdade (o ruido da sala), tirado das amostras de teste
    sil = [];
    for num = teste_sil(:)'
        [s, fs] = audioread(fullfile(pasta_sil, sprintf('silencio_%03d.wav', num)));
        sil = [sil; mean(s, 2)];
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
        fluxo = [fluxo; pausa];
        verdade(i, :) = [fila(i,1), numel(fluxo) / fs, (numel(fluxo) + numel(x)) / fs];
        fluxo = [fluxo; x];
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
    % Legenda (pontos NaN so para criar as entradas da legenda)
    h1 = plot(NaN, NaN, 'Color', [0.5 0.5 0.5]);
    h2 = plot(NaN, NaN, 'v', 'Color', [0 0.6 0], 'MarkerFaceColor', [0 0.6 0]);
    h3 = plot(NaN, NaN, 'v', 'Color', [0.8 0 0], 'MarkerFaceColor', [0.8 0 0]);
    legend([h1 h2 h3], {'audio (texto em cima = palavra que foi dita)', ...
        'palavra reconhecida durante uma palavra dita', ...
        'falso alarme (reconhecida sem nada dito)'}, 'Location', 'eastoutside');
    xlabel('tempo (s)'); ylabel('amplitude');
    title('Fala continua: em cima, o que foi dito | embaixo (triangulos), o que o sistema reconheceu');
    subplot(2, 1, 2);
    stairs(reg.t, reg.classe, 'b'); xlim([0 numel(fluxo) / fs]); ylim([0.5 numel(modelo.classes) + 0.5]);
    set(gca, 'YTick', 1:numel(modelo.classes), 'YTickLabel', modelo.classes);
    xlabel('tempo (s)'); ylabel('classe');
    title('Resposta da rede em cada janela de 150 ms (a maquina de estados procura di>rei>ta ou es>quer>da)');
    saveas(fig, fullfile(pasta_result, 'programa2_fluxo.png')); close(fig);

    %% 4. Parte 3: arquivo escolhido (opcional)
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
end
