%% SEGMENTAR_AUDIOS.M - corta as gravacoes em palavras, silabas e silencios
%
% Trabalho: reconhecimento de fonemas via MRNA (MLP), palavras DIREITA e
% ESQUERDA. Tudo e automatico, sem nenhum corte manual:
%   1) le as duas gravacoes longas (68 "direita" e 73 "esquerda");
%   2) mede o volume do som ao longo do tempo (energia, com a FFT, em
%      pedacos de 20 ms) e acha onde cada palavra comeca e termina;
%   3) corta cada palavra em 3 silabas nos "vales" do volume, que aparecem
%      quando a boca fecha numa consoante (/k/, /t/, /d/...). Os cortes em
%      tercos (3 pedacos iguais) tambem sao calculados: servem de reserva
%      quando nao ha vale e ficam no CSV, para a comparacao do relatorio;
%   4) recorta trechos de silencio entre as palavras (a 7a classe);
%   5) grava tudo em arquivos .wav, separados por classe, e gera figuras
%      para conferir os cortes.
%
% Classes (7): direita -> di, rei, ta; esquerda -> es, quer, da; silencio.
%
% Saidas (criadas automaticamente):
%   saida/palavras/             palavras inteiras (para o programa 2)
%   saida/energia/<classe>/     trechos de cada silaba e do silencio
%   saida/cortes_<palavra>.csv  tempo de cada corte (em segundos)
%   saida/figuras/              graficos para conferir os cortes
%
% So usa funcoes basicas (audioread, audiowrite, fft, movmean, sort),
% sem toolbox.

clear; clc; close all;

%% 1. Configuracao (todos os parametros ficam aqui)

% Pasta onde este script esta (todos os caminhos partem dela)
pasta_script = fileparts(mfilename('fullpath'));

% Lista de gravacoes: nome da palavra, arquivo original (.aac) e a copia
% em .flac, que e a usada. O .flac e um formato sem perda (as amostras sao
% exatamente as do audio original) que o MATLAB e o Octave leem direto; o
% Octave nao le .aac. O .aac so e usado se o .flac nao existir.
gravacoes = struct( ...
    'palavra', {'direita', 'esquerda'}, ...
    'arquivo', {fullfile(pasta_script, '..', 'material do professor', 'direita_-_68.aac'), ...
                fullfile(pasta_script, '..', 'material do professor', 'esquerda_-_73.aac')}, ...
    'arquivo_audio', {fullfile(pasta_script, 'audios', 'direita.flac'), ...
                      fullfile(pasta_script, 'audios', 'esquerda.flac')}, ...
    'silabas', {{'di', 'rei', 'ta'}, {'es', 'quer', 'da'}});

% Curva de volume: o audio e dividido em pedacos curtos (quadros)
dur_janela = 0.020;   % duracao de cada quadro: 20 ms
dur_passo  = 0.010;   % deslocamento entre quadros: 10 ms (sobreposicao de 50%)
f_min      = 250;     % soma so as frequencias da voz, de 250 Hz ...
f_max      = 6000;    % ... a 6000 Hz (abaixo de 250 Hz ha um zumbido de
                      % fundo; ate 6 kHz para nao perder o chiado do /s/)
n_suav     = 3;       % suaviza a curva (media de 3 quadros vizinhos)

% Deteccao das palavras
pct_piso      = 0.10; % nivel do silencio da sala: valor abaixo do qual estao 10% dos quadros
limiar_baixo  = 15;   % um quadro tem som se estiver 15 dB acima desse nivel
limiar_alto   = 30;   % um trecho so vira palavra se o pico passar de 30 dB acima dele
gap_min       = 0.120;% pausas menores que 120 ms dentro de uma palavra sao ignoradas
                      % (ex.: o fechamento da boca no /k/ de "esquerda")
dur_min       = 0.200;% trechos com menos de 200 ms sao descartados (estalos, ruidos)
queda_apara   = 25;   % apara o fim de cada palavra onde o volume cai 25 dB abaixo
                      % do pico dela (tira o eco da sala)

% Corte das silabas nos vales de energia (no CSV, colunas "B")
regiao_corte1 = [0.15 0.50]; % 1o corte procurado entre 15% e 50% da palavra
regiao_corte2 = [0.45 0.95]; % 2o corte procurado entre 45% e 95% da palavra,
                             % e sempre depois do 1o corte
prom_min      = 0;    % profundidade minima do vale (dB). Com 0, corta sempre no
                      % vale mais fundo da regiao, mesmo raso; o corte de
                      % reserva so e usado se nao houver vale nenhum
silaba_min    = 0.040;% nenhuma silaba pode ter menos de 40 ms; se os vales
                      % derem um pedaco menor, a palavra e cortada em tercos
% 2o corte (rei|ta e quer|da): o vale e procurado numa curva de volume so
% de 1 a 5 kHz. Abaixo de ~600 Hz ha um zumbido de fundo constante, que
% "enchia" o vale do /t/ e do /d/ na curva de 250 a 6000 Hz; de 1 a 5 kHz,
% onde fica o som das vogais, esse vale aparece bem fundo.
% No "esquerda", o corte vai no comeco do vale (fim da vogal "er"), para o
% fechamento do /d/ ficar no "da". No "direita", vai no fundo do vale:
% ouvindo os trechos, com o corte no comeco o "rei" ficava curto demais
% (o fim do "ei" ia para o "ta").
f_min_corte2  = 1000;
f_max_corte2  = 5000;
corte2_no_fundo = {'direita'};   % palavras com o 2o corte no fundo do vale

% Ajuste fino das fronteiras, so para os cortes em tercos e de reserva
% (o 2o corte nos vales ja fica no lugar certo e nao usa isto). Ouvindo os
% trechos, o "ta" e o "da" comecavam tarde demais. Valor positivo adianta
% o corte; negativo, atrasa.
adianta_corte1 = 0.000; % fronteira di|rei e es|quer (s)
adianta_corte2 = 0.030; % fronteira rei|ta e quer|da: 30 ms mais cedo (s)

% Trechos de silencio
dur_silencio  = 0.300;% duracao de cada amostra de silencio: 300 ms (cabem
                      % varias janelas do programa 2 em cada uma)
margem_sil    = 0.100;% distancia minima de 100 ms de qualquer palavra

% Pastas de saida
pasta_saida = fullfile(pasta_script, 'saida');
classes     = {'di', 'rei', 'ta', 'es', 'quer', 'da', 'silencio'};

% Cria todas as pastas de saida (as que ainda nao existem)
pastas = [{fullfile(pasta_saida, 'palavras'), fullfile(pasta_saida, 'figuras')}, ...
          cellfun(@(c) fullfile(pasta_saida, 'energia', c), classes, 'UniformOutput', false)];
for i = 1:numel(pastas)
    if ~exist(pastas{i}, 'dir'), mkdir(pastas{i}); end
end

cont_silencio = 0;    % quantos trechos de silencio ja foram gravados

%% 2. Processa cada gravacao
for g = 1:numel(gravacoes)
    palavra = gravacoes(g).palavra;
    silabas = gravacoes(g).silabas;
    fprintf('\n=== Processando "%s" ===\n', palavra);

    % 2.1 Leitura do audio
    % Usa a copia .flac (cada programa decodifica o .aac de um jeito; com o
    % .flac o resultado e o mesmo em qualquer um). Sem ela, tenta o .aac.
    if exist(gravacoes(g).arquivo_audio, 'file')
        [x, fs] = audioread(gravacoes(g).arquivo_audio);
        fprintf('Lido: %s\n', gravacoes(g).arquivo_audio);
    else
        [x, fs] = audioread(gravacoes(g).arquivo);
        fprintf('Lido: %s\n', gravacoes(g).arquivo);
    end

    % Audio estereo (2 colunas): faz a media dos dois canais (mono)
    x = mean(x, 2);
    fprintf('Taxa de amostragem: %d Hz | duracao: %.1f s\n', fs, numel(x)/fs);

    % 2.2 Curva de volume (energia na faixa da voz), quadro a quadro
    % Cada quadro e uma janela de J amostras; quadros consecutivos
    % comecam P amostras depois do anterior.
    J  = round(dur_janela * fs);           % amostras por quadro (960 a 48 kHz)
    P  = round(dur_passo  * fs);           % amostras por passo  (480 a 48 kHz)
    nq = floor((numel(x) - J) / P) + 1;    % numero total de quadros

    % Monta todos os quadros de uma vez: a coluna k tem as amostras do
    % quadro k. (1:J)' e uma coluna, (0:nq-1)*P e uma linha, e a soma das
    % duas da uma matriz J x nq com os indices de cada quadro.
    idx = (1:J)' + (0:nq-1) * P;
    Q   = x(idx);                          % cada coluna = um quadro do sinal

    % Janela de Hamming (calculada a mao, sem toolbox): suaviza as bordas
    % do quadro, para o corte brusco nao criar frequencias falsas na FFT.
    n   = (0:J-1)';
    ham = 0.54 - 0.46 * cos(2*pi*n / (J-1));
    Q   = Q .* ham;

    % FFT de cada quadro (cada coluna). So a primeira metade interessa (a outra e espelho).
    X   = abs(fft(Q)).^2;                  % potencia de cada frequencia
    X   = X(1:floor(J/2)+1, :);
    f   = (0:floor(J/2))' * fs / J;        % frequencia (Hz) de cada linha

    % Soma a potencia so na faixa da voz e passa para decibeis: o volume do quadro
    banda = (f >= f_min) & (f <= f_max);
    e = 10 * log10(sum(X(banda, :), 1) + 1e-10);   % vetor linha, 1 x nq
    e = movmean(e, n_suav);                        % suaviza a curva

    % Curva so de 1 a 5 kHz, usada no 2o corte (ver configuracao)
    banda2 = (f >= f_min_corte2) & (f <= f_max_corte2);
    e2 = movmean(10 * log10(sum(X(banda2, :), 1) + 1e-10), n_suav);

    % 2.3 Deteccao das palavras
    % Nivel do silencio: ordena os volumes e pega o valor que deixa 10% abaixo
    v    = sort(e);
    piso = v(max(1, round(pct_piso * numel(v))));

    % Quadros com som: acima do limiar
    ativo = e > piso + limiar_baixo;

    % Inicio (passa de 0 para 1) e fim (de 1 para 0) de cada trecho com som
    d   = diff([0, ativo, 0]);
    ini = find(d == 1);          % primeiro quadro ativo de cada trecho
    fim = find(d == -1) - 1;     % ultimo quadro ativo de cada trecho

    % Junta trechos separados por pausas curtas (menores que gap_min)
    gap_q = gap_min / dur_passo;              % pausa minima em quadros
    I = ini(1); F = [];
    for k = 2:numel(ini)
        if (ini(k) - fim(k-1) - 1) < gap_q
            continue;                         % pausa curta: mesma palavra
        end
        F(end+1) = fim(k-1);                  % fecha a palavra anterior
        I(end+1) = ini(k);                    % abre a proxima
    end
    F(end+1) = fim(end);

    % Fica so com trechos longos e fortes o bastante para serem palavras
    dur_q = dur_min / dur_passo;
    seg = [];                                 % cada linha: [inicio fim] em quadros
    for k = 1:numel(I)
        trecho = e(I(k):F(k));
        if (F(k) - I(k) + 1) >= dur_q && max(trecho) > piso + limiar_alto
            seg(end+1, :) = [I(k), F(k)];
        end
    end
    seg_bruto = seg;                          % guardado para achar os silencios

    % Apara cada palavra: fica so com os quadros a menos de queda_apara dB
    % do pico da propria palavra (tira o eco do fim).
    for k = 1:size(seg, 1)
        trecho = e(seg(k,1):seg(k,2));
        acima  = find(trecho > max(trecho) - queda_apara);
        seg(k, :) = seg(k,1) - 1 + [acima(1), acima(end)];
    end
    n_pal = size(seg, 1);
    fprintf('Palavras encontradas: %d\n', n_pal);

    % 2.4 Cortes das silabas e gravacao dos arquivos
    % Tabela dos cortes: palavra, inicio, cortes em tercos (A), cortes nos
    % vales (B), fim, e quantos cortes nos vales usaram a reserva.
    tabela = zeros(n_pal, 8);
    for k = 1:n_pal
        a = seg(k, 1);  b = seg(k, 2);        % primeiro e ultimo quadro
        L = b - a + 1;                        % duracao da palavra em quadros

        % Cortes em tercos (A): em 1/3 e 2/3 da duracao
        cA = a + round([1/3, 2/3] * L);

        % Ajuste fino das fronteiras (adianta_corte1/2, em quadros)
        ajuste = round([adianta_corte1, adianta_corte2] / dur_passo);
        cA = cA - ajuste;

        % 1o corte nos vales (B): o vale mais fundo da regiao
        [c1, p1] = vale_na_regiao(e, a, b, regiao_corte1);
        reserva1 = isempty(c1) || p1 < prom_min;
        if reserva1, c1 = cA(1); else, c1 = c1 - ajuste(1); end  % sem vale: usa o terco

        % 2o corte nos vales (B): curva de 1 a 5 kHz, no comeco do vale (ou
        % no fundo, nas palavras de corte2_no_fundo). So procura depois do
        % 1o corte (mais silaba_min), para os dois cortes nunca cairem no
        % mesmo vale e espremerem a silaba do meio. Sem vale, divide ao meio
        % o que sobra depois do 1o corte.
        min_q = round(silaba_min / dur_passo);
        regiao2 = [max(regiao_corte2(1), (c1 + min_q - a) / L), regiao_corte2(2)];
        [c2_fundo, p2, c2] = vale_na_regiao(e2, a, b, regiao2);
        if any(strcmp(palavra, corte2_no_fundo)), c2 = c2_fundo; end
        reserva2 = isempty(c2) || p2 < prom_min;
        if reserva2
            c2 = round((c1 + b) / 2);
        else
            c2 = max(c2, c1 + min_q);          % garante a distancia minima do 1o corte
        end
        cB = [c1, c2];

        % Protecao: se algum pedaco ficar menor que silaba_min (os dois
        % cortes muito perto), a palavra e cortada em tercos.
        tam = diff([a, cB, b + 1]);              % duracao dos 3 pedacos (quadros)
        if any(tam < silaba_min / dur_passo)
            cB = cA;
            reserva1 = true;  reserva2 = true;
        end

        % Passa de numero do quadro para numero da amostra. O quadro q comeca
        % na amostra (q-1)*P + 1; a posicao usada e o centro do quadro.
        q2s = @(q) (q - 1) * P + round(J/2);
        s_ini = q2s(a);
        s_fim = q2s(b);

        % Salva a palavra inteira (com 100 ms de folga dos dois lados,
        % util para testar o programa 2).
        folga = round(0.1 * fs);
        w = x(max(1, s_ini - folga) : min(numel(x), s_fim + folga));
        audiowrite(fullfile(pasta_saida, 'palavras', ...
            sprintf('%s_%03d.wav', palavra, k)), w, fs);

        % Salva as 3 silabas (cortes nos vales)
        lim = [s_ini, q2s(cB(1)), q2s(cB(2)), s_fim];
        for s = 1:3
            trecho = x(lim(s) : lim(s+1) - 1);
            nome = sprintf('%s_%03d.wav', silabas{s}, k);
            audiowrite(fullfile(pasta_saida, 'energia', silabas{s}, nome), trecho, fs);
        end

        % Guarda os tempos (em segundos) para o CSV
        tabela(k, :) = [k, q2s(a), q2s(cA(1)), q2s(cA(2)), ...
                        q2s(cB(1)), q2s(cB(2)), q2s(b), reserva1 + reserva2] ./ ...
                       [1, fs, fs, fs, fs, fs, fs, 1];
    end

    % Grava o CSV dos cortes (abre no Excel)
    arq_csv = fullfile(pasta_saida, sprintf('cortes_%s.csv', palavra));
    fid = fopen(arq_csv, 'w');
    fprintf(fid, ['palavra;inicio_s;A_corte1_s;A_corte2_s;' ...
                  'B_corte1_s;B_corte2_s;fim_s;B_cortes_em_reserva\n']);
    fprintf(fid, '%d;%.3f;%.3f;%.3f;%.3f;%.3f;%.3f;%d\n', tabela');
    fclose(fid);
    fprintf('Cortes do metodo B sem nenhum vale (usaram o corte de reserva): %d de %d\n', ...
        sum(tabela(:, 8)), 2 * n_pal);

    % 2.5 Amostras de silencio
    % Entre o fim de uma palavra e o inicio da proxima, recorta dur_silencio
    % segundos bem no meio da pausa, longe das palavras (margem_sil). Usa os
    % limites antes de aparar, para nao pegar o eco do fim da palavra.
    n_sil = round(dur_silencio * fs);
    marg  = round(margem_sil * fs);
    for k = 1:size(seg_bruto, 1) - 1
        p_ini = q2s(seg_bruto(k, 2))   + marg;   % comeco util da pausa
        p_fim = q2s(seg_bruto(k+1, 1)) - marg;   % fim util da pausa
        if p_fim - p_ini >= n_sil
            meio   = round((p_ini + p_fim) / 2);
            trecho = x(meio - floor(n_sil/2) : meio - floor(n_sil/2) + n_sil - 1);
            cont_silencio = cont_silencio + 1;
            nome = sprintf('silencio_%03d.wav', cont_silencio);
            audiowrite(fullfile(pasta_saida, 'energia', 'silencio', nome), trecho, fs);
        end
    end

    % 2.6 Figuras para conferencia
    t = ((0:nq-1) * P + J/2) / fs;            % tempo (s) do centro de cada quadro

    % Figura 1: gravacao inteira com as palavras detectadas.
    fig = figure('Visible', 'off', 'Position', [0 0 1800 500]);
    h1 = plot(t, e, 'b'); hold on;
    % (linhas feitas com plot: o Octave antigo nao tem yline/xline)
    h2 = plot(t([1 end]), [1 1] * (piso + limiar_baixo), 'k--');
    for k = 1:n_pal
        xr = t(seg(k, :));
        h3 = patch([xr(1) xr(2) xr(2) xr(1)], [min(e) min(e) max(e) max(e)], ...
              'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    end
    xlim(t([1 end]));  ylim([piso - 10, max(e) + 5]);
    xlabel('tempo (s)'); ylabel('energia 250-6000 Hz (dB)');
    title(sprintf('%s: %d palavras detectadas', upper(palavra), n_pal));
    legend([h1 h2 h3], {'energia do som (250-6000 Hz)', ...
        sprintf('limiar: acima disso e som (piso + %d dB)', limiar_baixo), ...
        'palavra detectada'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
    saveas(fig, fullfile(pasta_saida, 'figuras', sprintf('%s_deteccao.png', palavra)));
    close(fig);

    % Cada palavra tem 4 linhas verticais: inicio, 1o corte, 2o corte e fim.
    % (O silencio nao sai da palavra: vem das pausas entre as palavras.)

    % Figura 2: 12 palavras, com os cortes sobre as curvas de volume
    fig = figure('Visible', 'off', 'Position', [0 0 1800 900]);
    amostra = round(linspace(1, n_pal, 12));
    for i = 1:12
        k = amostra(i);
        a = seg(k, 1); b = seg(k, 2);
        janela = max(1, a - 15) : min(nq, b + 15);
        subplot(3, 4, i);
        h1 = plot(t(janela), e(janela), 'b'); hold on;
        h2 = plot(t(janela), e2(janela), 'm');
        yl = ylim;  vline = @(x, estilo) plot([x x], yl, estilo, 'LineWidth', 1.5);
        h3 = vline(t(a), 'k'); vline(t(b), 'k');
        h4 = vline(tabela(k, 5), 'r');   vline(tabela(k, 6), 'r');
        title(sprintf('%s #%d', palavra, k)); xlabel('tempo (s)'); ylabel('dB');
    end
    % Titulo e legenda gerais (annotation funciona no MATLAB e no Octave;
    % o Octave nao tem sgtitle)
    annotation('textbox', [0 0.96 1 0.04], 'String', ...
        sprintf('%s: cortes das silabas %s | %s | %s nos vales de energia', ...
        upper(palavra), silabas{:}), ...
        'HorizontalAlignment', 'center', 'EdgeColor', 'none', 'FontWeight', 'bold');
    lg = legend([h1 h2 h3 h4], {'energia 250-6000 Hz (usada no corte 1)', ...
        'energia 1-5 kHz (usada no corte 2)', 'inicio / fim da palavra', ...
        'corte 1 e corte 2'}, ...
        'Orientation', 'horizontal');
    set(lg, 'Position', [0.15 0.01 0.7 0.03]);
    saveas(fig, fullfile(pasta_saida, 'figuras', sprintf('%s_cortes.png', palavra)));
    close(fig);

    % Figura 3: a onda do som de 6 palavras, com os cortes e o nome de cada
    % silaba. Os vales sao onde a onda "afina".
    fig = figure('Visible', 'off', 'Position', [0 0 1800 900]);
    amostra = round(linspace(1, n_pal, 6));
    for i = 1:6
        k = amostra(i);
        s_a = round(tabela(k, 2) * fs);  s_b = round(tabela(k, 7) * fs);
        s0 = max(1, s_a - round(0.08 * fs));  s1 = min(numel(x), s_b + round(0.08 * fs));
        tt = (s0:s1) / fs;  onda = x(s0:s1);  amp = max(abs(onda));
        subplot(3, 2, i);
        h1 = plot(tt, onda, 'Color', [0.55 0.55 0.55]); hold on;
        % contorno da onda: amplitude media em pedacos de 10 ms
        env = sqrt(movmean(onda.^2, round(0.010 * fs)));
        h2 = plot(tt, env * amp / max(env), 'b', 'LineWidth', 1.2);
        vline = @(x, estilo) plot([x x], [-1 1] * amp, estilo, 'LineWidth', 2);
        h3 = vline(tabela(k, 2), 'k'); vline(tabela(k, 7), 'k');
        h4 = vline(tabela(k, 5), 'r'); vline(tabela(k, 6), 'r');
        lim = tabela(k, [2 5 6 7]);
        for s = 1:3
            text(mean(lim(s:s+1)), -0.85 * amp, silabas{s}, 'HorizontalAlignment', ...
                'center', 'FontWeight', 'bold', 'FontSize', 12, 'Color', [0.7 0 0]);
        end
        xlim(tt([1 end])); ylim([-1 1] * amp);
        title(sprintf('%s #%d', palavra, k)); xlabel('tempo (s)'); ylabel('amplitude');
    end
    annotation('textbox', [0 0.96 1 0.04], 'String', ...
        sprintf('%s: onda do audio e cortes das silabas', upper(palavra)), ...
        'HorizontalAlignment', 'center', 'EdgeColor', 'none', 'FontWeight', 'bold');
    lg = legend([h1 h2 h3 h4], {'onda (sinal de audio)', 'contorno da onda (amplitude)', ...
        'inicio / fim da palavra', 'corte 1 e corte 2'}, ...
        'Orientation', 'horizontal');
    set(lg, 'Position', [0.2 0.01 0.6 0.03]);
    saveas(fig, fullfile(pasta_saida, 'figuras', sprintf('%s_ondas.png', palavra)));
    close(fig);
end

fprintf('\nAmostras de silencio salvas: %d\n', cont_silencio);
fprintf('Pronto! Arquivos em: %s\n', pasta_saida);

% Observacao: a funcao vale_na_regiao fica em vale_na_regiao.m, nesta
% mesma pasta. (O Octave nao aceita funcoes no fim de um script e o MATLAB
% so aceita la; em arquivo separado, o script roda igual nos dois.)
