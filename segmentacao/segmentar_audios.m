%% ========================================================================
%  SEGMENTAR_AUDIOS.M
%  ------------------------------------------------------------------------
%  Trabalho: Reconhecimento de fonemas via MRNA (MLP)
%  Palavras: DIREITA e ESQUERDA
%
%  O que este script faz (sem nenhum recorte manual):
%    1) Le as gravacoes longas (varias repeticoes da mesma palavra).
%    2) Encontra automaticamente onde cada palavra comeca e termina,
%       usando a energia do sinal na faixa de frequencia da voz.
%    3) Divide cada palavra em 3 trechos (silabas) por DOIS metodos,
%       para depois compararmos qual treina melhor a rede:
%         Metodo A - "tercos":  3 pedacos de mesma duracao.
%         Metodo B - "energia": corta nos "vales" de energia, que
%                               aparecem quando a boca fecha numa
%                               consoante (/k/, /t/, /d/...).
%    4) Recorta trechos de silencio entre as palavras (classe extra
%       "silencio", que a rede usara para saber que nada foi dito).
%    5) Salva tudo em arquivos .wav separados por classe e gera
%       figuras para conferencia visual.
%
%  Classes geradas (7 no total):
%    direita  -> di, rei, ta
%    esquerda -> es, quer, da
%    silencio -> silencio
%
%  Estrutura de saida (criada automaticamente):
%    saida/palavras/            palavras inteiras (para o programa 2)
%    saida/tercos/<classe>/     trechos do metodo A
%    saida/energia/<classe>/    trechos do metodo B
%    saida/cortes_<palavra>.csv posicoes de todos os cortes (em segundos)
%    saida/figuras/             graficos para conferencia
%
%  Requisitos: MATLAB base (nao usa nenhuma toolbox).
%  Funcoes prontas usadas: audioread, audiowrite, fft, movmean, sort.
%  ========================================================================

clear; clc; close all;

%% ------------------------------------------------------------------------
%  1. CONFIGURACAO (todos os parametros ajustaveis ficam aqui)
%  ------------------------------------------------------------------------

% Pasta onde este script esta (todos os caminhos partem dela)
pasta_script = fileparts(mfilename('fullpath'));

% Lista de gravacoes: nome da palavra, arquivo original (.aac) e uma
% copia em .wav (usada se o MATLAB nao conseguir ler o .aac).
gravacoes = struct( ...
    'palavra', {'direita', 'esquerda'}, ...
    'arquivo', {fullfile(pasta_script, '..', 'material do professor', 'direita_-_68.aac'), ...
                fullfile(pasta_script, '..', 'material do professor', 'esquerda_-_73.aac')}, ...
    'arquivo_wav', {fullfile(pasta_script, 'audios_wav', 'direita.wav'), ...
                    fullfile(pasta_script, 'audios_wav', 'esquerda.wav')}, ...
    'silabas', {{'di', 'rei', 'ta'}, {'es', 'quer', 'da'}});

% --- Analise de energia por quadros (janelas curtas de tempo) ---
dur_janela = 0.020;   % duracao de cada quadro: 20 ms
dur_passo  = 0.010;   % deslocamento entre quadros: 10 ms (sobreposicao de 50%)
f_min      = 250;     % faixa da voz considerada: 250 Hz ...
f_max      = 6000;    % ... ate 6000 Hz (abaixo de 250 Hz ha ruido de fundo;
                      % ate 6 kHz para nao perder o chiado do /s/)
n_suav     = 3;       % suavizacao da curva de energia (media movel de 3 quadros)

% --- Deteccao das palavras ---
pct_piso      = 0.10; % "piso" de ruido = valor abaixo do qual estao 10% dos quadros
limiar_baixo  = 15;   % quadro e considerado "som" se estiver 15 dB acima do piso
limiar_alto   = 30;   % um segmento so vira palavra se seu pico passar 30 dB do piso
gap_min       = 0.120;% pausas menores que 120 ms dentro de uma palavra sao ignoradas
                      % (ex.: o fechamento da boca no /k/ de "esquerda")
dur_min       = 0.200;% segmentos com menos de 200 ms sao descartados (estalos, ruidos)
queda_apara   = 25;   % apara cada palavra onde a energia cai 25 dB abaixo do
                      % pico dela (remove a "cauda" de reverberacao da sala)

% --- Metodo B (vales de energia) ---
regiao_corte1 = [0.15 0.50]; % 1o corte procurado entre 15% e 50% da palavra
regiao_corte2 = [0.50 0.90]; % 2o corte procurado entre 50% e 90% da palavra
prom_min      = 3;    % o vale precisa ter pelo menos 3 dB de profundidade;
                      % se nao houver, usa o corte do metodo A (terco)
silaba_min    = 0.040;% nenhuma silaba pode ficar com menos de 40 ms; se os
                      % vales gerarem um pedaco menor, a palavra usa os tercos

% --- Ajuste fino das fronteiras (vale para os dois metodos) ---
% Ouvindo os trechos, o "ta" e o "da" comecavam tarde demais (o fechamento
% da boca do /t/ e do /d/ ficava no trecho anterior). Valores positivos
% movem o corte para ANTES; negativos, para depois.
adianta_corte1 = 0.000; % fronteira di|rei e es|quer (s)
adianta_corte2 = 0.030; % fronteira rei|ta e quer|da: 30 ms mais cedo (s)

% --- Trechos de silencio ---
dur_silencio  = 0.300;% duracao de cada amostra de silencio: 300 ms (cabem
                      % varias janelas do programa 2 em cada uma)
margem_sil    = 0.100;% distancia minima de 100 ms de qualquer palavra

% Pastas de saida
pasta_saida = fullfile(pasta_script, 'saida');
metodos     = {'tercos', 'energia'};
classes     = {'di', 'rei', 'ta', 'es', 'quer', 'da', 'silencio'};

% Cria todas as pastas de saida (se ja existirem, nada acontece)
criar_pasta(fullfile(pasta_saida, 'palavras'));
criar_pasta(fullfile(pasta_saida, 'figuras'));
for m = 1:numel(metodos)
    for c = 1:numel(classes)
        criar_pasta(fullfile(pasta_saida, metodos{m}, classes{c}));
    end
end

cont_silencio = 0;    % contador global de amostras de silencio

%% ------------------------------------------------------------------------
%  2. PROCESSA CADA GRAVACAO
%  ------------------------------------------------------------------------
for g = 1:numel(gravacoes)
    palavra = gravacoes(g).palavra;
    silabas = gravacoes(g).silabas;
    fprintf('\n=== Processando "%s" ===\n', palavra);

    % ---- 2.1 Leitura do audio ------------------------------------------
    % Tenta ler o .aac original; se falhar, usa a copia .wav.
    try
        [x, fs] = audioread(gravacoes(g).arquivo);
        fprintf('Lido: %s\n', gravacoes(g).arquivo);
    catch
        [x, fs] = audioread(gravacoes(g).arquivo_wav);
        fprintf('AAC nao suportado; lido: %s\n', gravacoes(g).arquivo_wav);
    end

    % Se o audio for estereo (2 colunas), faz a media dos canais -> mono.
    x = mean(x, 2);
    fprintf('Taxa de amostragem: %d Hz | duracao: %.1f s\n', fs, numel(x)/fs);

    % ---- 2.2 Energia na faixa da voz, quadro a quadro ------------------
    % Cada quadro e uma janela de J amostras; quadros consecutivos
    % comecam P amostras depois do anterior.
    J  = round(dur_janela * fs);           % amostras por quadro (960 a 48 kHz)
    P  = round(dur_passo  * fs);           % amostras por passo  (480 a 48 kHz)
    nq = floor((numel(x) - J) / P) + 1;    % numero total de quadros

    % Matriz de indices: coluna k contem as amostras do quadro k.
    % (1:J)' e um vetor coluna; (0:nq-1)*P e um vetor linha; a soma
    % gera uma matriz J x nq (expansao automatica do MATLAB/Octave).
    idx = (1:J)' + (0:nq-1) * P;
    Q   = x(idx);                          % cada coluna = um quadro do sinal

    % Janela de Hamming (calculada a mao para nao depender de toolbox):
    % suaviza as bordas do quadro e reduz o "vazamento" na FFT.
    n   = (0:J-1)';
    ham = 0.54 - 0.46 * cos(2*pi*n / (J-1));
    Q   = Q .* ham;

    % FFT de cada quadro (coluna). Guardamos so a metade util (sem espelho).
    X   = abs(fft(Q)).^2;                  % potencia de cada frequencia
    X   = X(1:floor(J/2)+1, :);
    f   = (0:floor(J/2))' * fs / J;        % frequencia (Hz) de cada linha

    % Soma a potencia apenas na faixa da voz e converte para decibeis.
    banda = (f >= f_min) & (f <= f_max);
    e = 10 * log10(sum(X(banda, :), 1) + 1e-10);   % vetor linha, 1 x nq
    e = movmean(e, n_suav);                        % suaviza a curva

    % ---- 2.3 Deteccao das palavras -------------------------------------
    % Piso de ruido: ordena as energias e pega o valor no percentil 10%.
    v    = sort(e);
    piso = v(max(1, round(pct_piso * numel(v))));

    % Quadros "ativos" = acima do limiar baixo.
    ativo = e > piso + limiar_baixo;

    % Encontra inicio (subida 0->1) e fim (descida 1->0) de cada trecho ativo.
    d   = diff([0, ativo, 0]);
    ini = find(d == 1);          % primeiro quadro ativo de cada trecho
    fim = find(d == -1) - 1;     % ultimo quadro ativo de cada trecho

    % Une trechos separados por pausas curtas (< gap_min).
    gap_q = gap_min / dur_passo;              % pausa minima em quadros
    I = ini(1); F = [];
    for k = 2:numel(ini)
        if (ini(k) - fim(k-1) - 1) < gap_q
            continue;                         % pausa curta: mesma palavra
        end
        F(end+1) = fim(k-1);                  %#ok<SAGROW> fecha a palavra anterior
        I(end+1) = ini(k);                    %#ok<SAGROW> abre a proxima
    end
    F(end+1) = fim(end);

    % Mantem so segmentos longos o bastante e com pico forte o bastante.
    dur_q = dur_min / dur_passo;
    seg = [];                                 % cada linha: [inicio fim] em quadros
    for k = 1:numel(I)
        trecho = e(I(k):F(k));
        if (F(k) - I(k) + 1) >= dur_q && max(trecho) > piso + limiar_alto
            seg(end+1, :) = [I(k), F(k)];     %#ok<SAGROW>
        end
    end
    seg_bruto = seg;                          % guardado para achar os silencios

    % Apara cada palavra: mantem so os quadros a menos de 'queda_apara'
    % dB do pico da propria palavra (remove a cauda de reverberacao).
    for k = 1:size(seg, 1)
        trecho = e(seg(k,1):seg(k,2));
        acima  = find(trecho > max(trecho) - queda_apara);
        seg(k, :) = seg(k,1) - 1 + [acima(1), acima(end)];
    end
    n_pal = size(seg, 1);
    fprintf('Palavras encontradas: %d\n', n_pal);

    % ---- 2.4 Cortes das silabas e gravacao dos arquivos ----------------
    % Tabela com os cortes: palavra, inicio, corte1/corte2 (A e B), fim,
    % e se o metodo B precisou usar o terco como reserva.
    tabela = zeros(n_pal, 8);
    for k = 1:n_pal
        a = seg(k, 1);  b = seg(k, 2);        % primeiro e ultimo quadro
        L = b - a + 1;                        % duracao da palavra em quadros

        % Metodo A: cortes em 1/3 e 2/3 da duracao.
        cA = a + round([1/3, 2/3] * L);

        % Metodo B: procura o vale mais profundo em cada regiao.
        [c1, p1] = vale_na_regiao(e, a, b, regiao_corte1);
        [c2, p2] = vale_na_regiao(e, a, b, regiao_corte2);
        reserva1 = isempty(c1) || p1 < prom_min;
        reserva2 = isempty(c2) || p2 < prom_min;
        if reserva1, c1 = cA(1); end          % sem vale claro: usa o terco
        if reserva2, c2 = cA(2); end
        cB = [c1, c2];

        % Ajuste fino das fronteiras (adianta_corte1/2, em quadros)
        ajuste = round([adianta_corte1, adianta_corte2] / dur_passo);
        cA = cA - ajuste;
        cB = cB - ajuste;

        % Protecao: os dois vales podem cair no mesmo ponto (ex.: ambos
        % exatamente em 50% da palavra), gerando uma silaba vazia. Se
        % qualquer pedaco ficar menor que 'silaba_min', usa os tercos.
        tam = diff([a, cB, b + 1]);              % duracao dos 3 pedacos (quadros)
        if any(tam < silaba_min / dur_passo)
            cB = cA;
            reserva1 = true;  reserva2 = true;
        end

        % Converte quadros -> amostras. O quadro q (1, 2, ...) comeca na
        % amostra (q-1)*P + 1; usamos o CENTRO do quadro como posicao.
        q2s = @(q) (q - 1) * P + round(J/2);
        s_ini = q2s(a);
        s_fim = q2s(b);

        % Salva a palavra inteira (com 100 ms de folga dos dois lados,
        % util para testar o programa 2).
        folga = round(0.1 * fs);
        w = x(max(1, s_ini - folga) : min(numel(x), s_fim + folga));
        audiowrite(fullfile(pasta_saida, 'palavras', ...
            sprintf('%s_%03d.wav', palavra, k)), w, fs);

        % Salva os 3 trechos de cada metodo.
        cortes = {cA, cB};
        for m = 1:2
            lim = [s_ini, q2s(cortes{m}(1)), q2s(cortes{m}(2)), s_fim];
            for s = 1:3
                trecho = x(lim(s) : lim(s+1) - 1);
                nome = sprintf('%s_%03d.wav', silabas{s}, k);
                audiowrite(fullfile(pasta_saida, metodos{m}, silabas{s}, nome), ...
                    trecho, fs);
            end
        end

        % Guarda os tempos (em segundos) para a tabela CSV.
        tabela(k, :) = [k, q2s(a), q2s(cA(1)), q2s(cA(2)), ...
                        q2s(cB(1)), q2s(cB(2)), q2s(b), reserva1 + reserva2] ./ ...
                       [1, fs, fs, fs, fs, fs, fs, 1];
    end

    % Escreve a tabela CSV (abre no Excel).
    arq_csv = fullfile(pasta_saida, sprintf('cortes_%s.csv', palavra));
    fid = fopen(arq_csv, 'w');
    fprintf(fid, ['palavra;inicio_s;A_corte1_s;A_corte2_s;' ...
                  'B_corte1_s;B_corte2_s;fim_s;B_cortes_em_reserva\n']);
    fprintf(fid, '%d;%.3f;%.3f;%.3f;%.3f;%.3f;%.3f;%d\n', tabela');
    fclose(fid);
    fprintf('Cortes do metodo B que usaram o terco (sem vale claro): %d de %d\n', ...
        sum(tabela(:, 8)), 2 * n_pal);

    % ---- 2.5 Amostras de silencio --------------------------------------
    % Entre o fim de uma palavra e o inicio da proxima (antes de aparar,
    % para nao pegar a cauda de reverberacao), recorta 'dur_silencio'
    % segundos bem no meio da pausa, respeitando a margem.
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
            % A mesma amostra de silencio vai para os dois metodos,
            % para que cada conjunto (tercos/energia) fique completo.
            for m = 1:2
                audiowrite(fullfile(pasta_saida, metodos{m}, 'silencio', nome), ...
                    trecho, fs);
            end
        end
    end

    % ---- 2.6 Figuras para conferencia ----------------------------------
    t = ((0:nq-1) * P + J/2) / fs;            % tempo (s) do centro de cada quadro

    % Figura 1: gravacao inteira com as palavras detectadas.
    fig = figure('Visible', 'off', 'Position', [0 0 1800 500]);
    plot(t, e, 'b'); hold on;
    yline(piso + limiar_baixo, 'k--', 'limiar');
    for k = 1:n_pal
        xr = t(seg(k, :));
        patch([xr(1) xr(2) xr(2) xr(1)], [min(e) min(e) max(e) max(e)], ...
              'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    end
    xlabel('tempo (s)'); ylabel('energia 250-6000 Hz (dB)');
    title(sprintf('"%s": %d palavras detectadas (verde)', palavra, n_pal));
    saveas(fig, fullfile(pasta_saida, 'figuras', sprintf('%s_deteccao.png', palavra)));
    close(fig);

    % Figura 2: 12 palavras espalhadas, com os cortes A (verde tracejado)
    % e B (vermelho) sobre a curva de energia.
    fig = figure('Visible', 'off', 'Position', [0 0 1800 800]);
    amostra = round(linspace(1, n_pal, 12));
    for i = 1:12
        k = amostra(i);
        a = seg(k, 1); b = seg(k, 2);
        janela = max(1, a - 15) : min(nq, b + 15);
        subplot(3, 4, i);
        plot(t(janela), e(janela), 'b'); hold on;
        xline(t(a), 'k'); xline(t(b), 'k');
        xline(tabela(k, 3), 'g--'); xline(tabela(k, 4), 'g--');
        xline(tabela(k, 5), 'r');   xline(tabela(k, 6), 'r');
        title(sprintf('%s #%d', palavra, k));
    end
    % Titulo geral da figura (annotation funciona no MATLAB e no Octave;
    % o sgtitle nao existe no Octave).
    annotation('textbox', [0 0.96 1 0.04], 'String', ...
        sprintf('"%s": cortes A (verde tracejado) x B (vermelho)', palavra), ...
        'HorizontalAlignment', 'center', 'EdgeColor', 'none', 'FontWeight', 'bold');
    saveas(fig, fullfile(pasta_saida, 'figuras', sprintf('%s_cortes.png', palavra)));
    close(fig);
end

fprintf('\nAmostras de silencio salvas: %d\n', cont_silencio);
fprintf('Pronto! Arquivos em: %s\n', pasta_saida);

% Observacao: as funcoes auxiliares criar_pasta e vale_na_regiao estao
% em arquivos separados (criar_pasta.m e vale_na_regiao.m) nesta mesma
% pasta. Assim o script roda igual no MATLAB e no GNU Octave.
