function v = espectro_bandas(x, fs, n_bandas, f_min, f_max)
    % ESPECTRO_BANDAS  Transforma um trecho de audio no vetor de entrada da rede.
    %
    %   Ideia (slides 5 e 11 do professor): todo som e uma soma de senoides.
    %   A FFT diz QUAIS frequencias existem no trecho e COM QUE AMPLITUDE.
    %   Como cada trecho tem uma duracao diferente, a FFT de cada um tem um
    %   numero diferente de pontos. Para a rede (que tem um numero FIXO de
    %   entradas), a faixa f_min..f_max e dividida em n_bandas faixas iguais,
    %   e cada entrada e a amplitude media dentro de uma faixa.
    %
    % Entradas:
    %   x        - amostras do trecho (vetor)
    %   fs       - taxa de amostragem (Hz)
    %   n_bandas - numero de faixas = numero de entradas da rede (ex.: 32 ou 64)
    %   f_min    - frequencia inicial considerada (Hz)
    %   f_max    - frequencia final considerada (Hz)
    % Saida:
    %   v        - vetor linha 1 x n_bandas com a amplitude media de cada faixa
    %              (ainda SEM normalizacao; ela e feita depois, em normalizar.m)

    x = x(:);                       % garante vetor coluna
    x = x - mean(x);                % remove o nivel DC (deslocamento do zero)
    N = numel(x);

    % Janela de Hamming: atenua as bordas do trecho para o corte abrupto
    % nao criar frequencias falsas na FFT ("vazamento espectral").
    n = (0:N-1)';
    x = x .* (0.54 - 0.46 * cos(2*pi*n / (N-1)));

    % Amplitude de cada frequencia. Dividir por N deixa a amplitude
    % independente da duracao do trecho.
    A = abs(fft(x)) / N;
    A = A(1:floor(N/2)+1);          % so a metade util (o resto e espelho)
    f = (0:floor(N/2))' * fs / N;   % frequencia (Hz) de cada ponto de A

    % Divide f_min..f_max em n_bandas faixas de mesma largura.
    bordas = linspace(f_min, f_max, n_bandas + 1);
    v = zeros(1, n_bandas);
    for k = 1:n_bandas
        sel = (f >= bordas(k)) & (f < bordas(k+1));   % pontos desta faixa
        v(k) = mean(A(sel));                          % amplitude media da faixa
    end
end
