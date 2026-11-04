%% ANALISE_FREQUENCIAS.M - ate que frequencia vai a voz nas gravacoes
%
% Nao e preciso para rodar o projeto: so mede o dado que justifica a faixa
% de 0 a 5 kHz da entrada da rede (secao 3.2 do relatorio).
%
% Como:
%   1) divide as duas gravacoes em quadros de 20 ms (Hamming e FFT), como
%      na segmentacao;
%   2) separa os quadros de fala (dentro das palavras, pelo CSV dos cortes)
%      dos quadros de silencio (a mais de 100 ms de qualquer palavra);
%   3) calcula a potencia media de cada frequencia na fala e no silencio, e
%      quanto a fala fica acima do ruido em cada frequencia;
%   4) energia da voz = potencia da fala menos a do ruido; calcula que
%      fracao dessa energia esta abaixo de cada frequencia.
%
% Resultado: a voz se destaca do ruido ate cerca de 4,2 kHz, e 99,9% da
% energia da voz fica abaixo disso. Figura: figuras/espectro_fala_ruido.png.
pasta_rel = fileparts(mfilename('fullpath'));
pasta_seg = fullfile(pasta_rel, '..', 'segmentacao');
palavras = {'direita', 'esquerda'};
dur_q = 0.020;  dur_p = 0.010;

Pf = 0;  Pn = 0;  nf = 0;  nn = 0;
for w = 1:2
    [x, fs] = audioread(fullfile(pasta_seg, 'audios', [palavras{w} '.flac']));
    x = mean(x, 2);
    C = dlmread(fullfile(pasta_seg, 'saida', ['cortes_' palavras{w} '.csv']), ';', 1, 0);
    J = round(dur_q * fs);  P = round(dur_p * fs);
    nq = floor((numel(x) - J) / P) + 1;
    t = ((0:nq-1) * P + J/2) / fs;                    % centro de cada quadro (s)
    fala = false(1, nq);  perto = false(1, nq);
    for k = 1:size(C, 1)
        fala  = fala  | (t >= C(k, 2) & t <= C(k, 7));
        perto = perto | (t >= C(k, 2) - 0.1 & t <= C(k, 7) + 0.1);
    end
    sil = ~perto;
    ham = 0.54 - 0.46 * cos(2*pi*(0:J-1)' / (J-1));
    for q = 1:nq
        if ~fala(q) && ~sil(q), continue; end
        seg = x((q-1)*P + (1:J));
        A = abs(fft((seg - mean(seg)) .* ham)).^2;
        A = A(1:floor(J/2)+1);
        if fala(q), Pf = Pf + A; nf = nf + 1; else, Pn = Pn + A; nn = nn + 1; end
    end
end
Pf = Pf / nf;  Pn = Pn / nn;
f = (0:floor(J/2))' * fs / J;                         % resolucao de 50 Hz

snr = 10 * log10(Pf ./ Pn);
snr_s = movmean(snr, 5);                              % suaviza em 250 Hz
voz = max(Pf - Pn, 0);                                % energia da voz sem o ruido
acum = cumsum(voz) / sum(voz);

fprintf('Quadros de fala: %d | quadros de silencio: %d (fs = %d Hz)\n', nf, nn, fs);
% Onde a voz acaba: a primeira frequencia, depois do ultimo pico da voz
% (~3,5 kHz), em que a fala fica menos de 15 dB acima do ruido. (Acima de
% ~12 kHz a compressao do AAC zera o silencio, e a comparacao perde o
% sentido.)
i_pico = find(f >= 3000 & f <= 4000);  [~, k] = max(snr_s(i_pico));  i_pico = i_pico(k);
f15 = f(i_pico - 1 + find(snr_s(i_pico:end) < 15, 1));
f_meio = f(i_pico - 1 + find(snr_s(i_pico:end) < (snr_s(i_pico) + 10) / 2, 1));
fprintf('Ultimo formante: %.0f Hz (%.1f dB acima do ruido)\n', f(i_pico), snr_s(i_pico));
fprintf('Voz cai a meia altura (entre o pico e o patamar) em %.0f Hz\n', f_meio);
fprintf('Voz cai para menos de 15 dB acima do ruido em %.0f Hz\n', f15);
for p = [0.95 0.99 0.995 0.999]
    fprintf('%.1f%% da energia da voz abaixo de %5.0f Hz\n', 100*p, f(find(acum >= p, 1)));
end
fprintf('Energia da voz abaixo de 5 kHz: %.2f%%\n', 100 * acum(find(f <= 5000, 1, 'last')));
i250 = find(f <= 250, 1, 'last');
fprintf('Abaixo de 250 Hz: SNR media %.1f dB (zumbido de fundo)\n', mean(snr(2:i250)));
fprintf('SNR media 250-1000 Hz: %.1f dB | 1-3 kHz: %.1f dB | 3-5 kHz: %.1f dB | 5-8 kHz: %.1f dB | 8-12 kHz: %.1f dB\n', ...
    mean(snr(f>=250 & f<1000)), mean(snr(f>=1000 & f<3000)), mean(snr(f>=3000 & f<5000)), ...
    mean(snr(f>=5000 & f<8000)), mean(snr(f>=8000 & f<12000)));

fig = figure('Visible', 'off', 'Position', [0 0 1500 520]);
subplot(1, 2, 1);
ref = max(10*log10(Pf));
plot(f/1000, movmean(10*log10(Pf), 3) - ref, 'b'); hold on;
plot(f/1000, movmean(10*log10(Pn), 3) - ref, 'Color', [0.5 0.5 0.5]);
plot([5 5], [-90 5], 'r--', 'LineWidth', 1.5);
xlim([0 12]); ylim([-90 5]); grid on;
xlabel('frequencia (kHz)'); ylabel('potencia (dB, relativa ao pico da fala)');
title('Gravacoes originais: espectro medio da fala e do silencio');
legend('fala (dentro das palavras)', 'silencio (ruido da sala)', 'limite usado: 5 kHz');
subplot(1, 2, 2);
plot(f/1000, snr_s, 'b', 'LineWidth', 1.2); hold on;
plot([0 12], [10 10], 'k:');
plot([5 5], [-5 50], 'r--', 'LineWidth', 1.5);
xlim([0 12]); ylim([-5 50]); grid on;
xlabel('frequencia (kHz)'); ylabel('fala acima do ruido (dB)');
plot([0 12], [15 15], 'k:');
title(sprintf('Relacao sinal-ruido: a voz cai para o patamar em %.1f kHz', f15/1000));
legend('fala / silencio', '10 dB', 'limite usado: 5 kHz', '15 dB');
saveas(fig, fullfile(pasta_rel, 'figuras', 'espectro_fala_ruido.png'));
close(fig);
