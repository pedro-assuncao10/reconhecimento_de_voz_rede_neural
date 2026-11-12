function varargout = entrada(acao, varargin)
    % ENTRADA  Transforma o audio no vetor que entra na rede: FFT em faixas
    % de frequencia, janelas vizinhas (contexto) e normalizacao.
    % E usada no treino (extrair_entradas.m, treinar_mlp.m) e no programa 2
    % (reconhecer_palavra.m), para a rede receber sempre o mesmo tipo de
    % entrada.
    %
    % Uso:
    %   v           = entrada('espectro', x, ini, J, passo, contexto, fs, n_bandas, f_min, f_max)
    %   [Xn, stats] = entrada('normalizar', X, tipo)          (no treino)
    %   Xn          = entrada('normalizar', X, tipo, stats)   (validacao, teste, programa 2)
    %
    % No MATLAB/Octave, outro arquivo so consegue chamar a primeira funcao
    % de um arquivo. Por isso esta primeira funcao so recebe o nome da acao
    % e chama a funcao certa, que esta mais abaixo.

    n = max(nargout, 1);
    switch acao
        case 'espectro',   [varargout{1:n}] = espectro(varargin{:});
        case 'normalizar', [varargout{1:n}] = normalizar(varargin{:});
        otherwise, error('entrada: acao desconhecida: %s', acao);
    end
end


function v = espectro(x, ini, J, passo_amostras, contexto, fs, n_bandas, f_min, f_max)
    % ESPECTRO  Vetor de entrada de uma janela: as faixas da janela atual e
    % das janelas vizinhas, uma ao lado da outra.
    %
    %   Por que as vizinhas: olhando so 150 ms, o "e" do comeco de "es" e o
    %   "e" de "quer" sao a mesma vogal, e a rede nao consegue separar os
    %   dois. O que muda e o que vem antes e depois (o "s" no "es", o "r"
    %   no "quer"). Com as janelas vizinhas, a rede tambem "ouve" isso.
    %
    % Entradas:
    %   x              - audio (vetor)
    %   ini            - primeira amostra da janela atual dentro de x
    %   J              - amostras por janela (150 ms)
    %   passo_amostras - amostras por passo (25 ms)
    %   contexto       - quais janelas entram, contadas em passos. Ex.:
    %                    [-4 -2 0 2 4] = 100 e 50 ms antes, a atual, 50 e
    %                    100 ms depois. [0] = so a janela atual (sem contexto)
    %   fs, n_bandas, f_min, f_max - como na funcao bandas, abaixo
    % Saida:
    %   v - vetor com n_bandas numeros por janela. Com 32 faixas e 5
    %       janelas: 160 numeros.
    %
    %   Se uma janela vizinha cair fora do audio (no inicio ou no fim),
    %   usa a janela da borda.

    x = x(:);
    v = zeros(1, n_bandas * numel(contexto));
    for i = 1:numel(contexto)
        a = ini + contexto(i) * passo_amostras;
        a = min(max(a, 1), numel(x) - J + 1);        % mantem dentro do audio
        v((i-1)*n_bandas + (1:n_bandas)) = bandas(x(a : a + J - 1), fs, n_bandas, f_min, f_max);
    end
end


function v = bandas(x, fs, n_bandas, f_min, f_max)
    % BANDAS  Amplitude media do som em cada faixa de frequencia de um trecho.
    %
    %   A FFT diz quais frequencias existem no trecho e com que amplitude.
    %   A faixa de f_min a f_max e dividida em n_bandas faixas de mesma
    %   largura, e cada numero da saida e a amplitude media dentro de uma
    %   faixa. Com 0 a 5 kHz e 32 faixas, cada faixa tem 156 Hz.
    %
    % Entradas:
    %   x        - amostras do trecho (vetor)
    %   fs       - taxa de amostragem (Hz)
    %   n_bandas - numero de faixas (32)
    %   f_min    - frequencia inicial (Hz)
    %   f_max    - frequencia final (Hz)
    % Saida:
    %   v        - um numero por faixa (ainda sem normalizar; isso e feito
    %              depois, na funcao normalizar)

    x = x(:);                       % garante vetor coluna
    x = x - mean(x);                % tira o nivel DC (deslocamento do zero)
    N = numel(x);

    % Janela de Hamming: suaviza as bordas do trecho. Sem ela, o corte
    % brusco no comeco e no fim criaria frequencias que nao existem no som.
    n = (0:N-1)';
    x = x .* (0.54 - 0.46 * cos(2*pi*n / (N-1)));

    % Amplitude de cada frequencia. Dividir por N faz a amplitude nao
    % depender da duracao do trecho.
    A = abs(fft(x)) / N;
    A = A(1:floor(N/2)+1);          % so a primeira metade (a outra e espelho)
    f = (0:floor(N/2))' * fs / N;   % frequencia (Hz) de cada ponto de A

    % Divide de f_min a f_max em n_bandas faixas de mesma largura
    bordas = linspace(f_min, f_max, n_bandas + 1);
    v = zeros(1, n_bandas);
    for k = 1:n_bandas
        sel = (f >= bordas(k)) & (f < bordas(k+1));   % pontos desta faixa
        v(k) = mean(A(sel));                          % amplitude media da faixa
    end
end


function [Xn, stats] = normalizar(X, tipo, stats)
    % NORMALIZAR  Ajusta a escala das entradas antes da rede. Sem isso,
    % falar mais alto ou mais baixo mudaria a entrada, e a rede poderia
    % confundir volume com silaba.
    %
    % Entradas:
    %   X     - uma amostra por linha
    %   tipo  - 'max'    : divide cada amostra pelo seu maior valor (fica de 0 a 1)
    %           'db'     : o mesmo, em decibeis, de -60 dB a 0 dB, levado
    %                      para 0 a 1
    %           'zscore' : para cada coluna, subtrai a media e divide pelo
    %                      desvio padrao, calculados so no treino
    %           'minmax' : para cada coluna, (x - xmin) / (xmax - xmin), com o
    %                      minimo e o maximo do treino: fica entre 0 e 1
    %           'minmax11': o mesmo, levado para -1 a 1:
    %                      (2x - xmax - xmin) / (xmax - xmin)
    %   stats - (no zscore e no minmax) valores do treino, para usar os
    %           mesmos na validacao, no teste e no programa 2
    % Saidas:
    %   Xn    - entradas normalizadas (mesmo tamanho de X)
    %   stats - media (mu) e desvio (sigma) do zscore, ou minimo (xmin) e
    %           maximo (xmax) do minmax
    %
    % A rede do trabalho usa 'max' (escolhida na etapa 2 dos experimentos).

    if nargin < 3
        stats = struct();
    end

    switch tipo
        case 'max'
            Xn = X ./ max(X, [], 2);                  % cada linha dividida pelo seu maior valor

        case 'db'
            R  = X ./ max(X, [], 2);                  % relativo ao maior valor (0 a 1)
            D  = 20 * log10(R + 1e-12);               % em decibeis (0 ou negativo)
            D  = max(D, -60);                         % nada abaixo de -60 dB
            Xn = (D + 60) / 60;                       % -60..0 dB vira 0..1

        case 'zscore'
            if ~isfield(stats, 'mu')                  % primeira vez: calcula no treino
                stats.mu    = mean(X, 1);
                stats.sigma = std(X, 0, 1) + 1e-12;   % +1e-12 evita divisao por zero
            end
            Xn = (X - stats.mu) ./ stats.sigma;

        case {'minmax', 'minmax11'}
            if ~isfield(stats, 'xmin')                % primeira vez: calcula no treino
                stats.xmin = min(X, [], 1);
                stats.xmax = max(X, [], 1);
            end
            faixa = stats.xmax - stats.xmin + 1e-12;  % +1e-12 evita divisao por zero
            if strcmp(tipo, 'minmax')
                Xn = (X - stats.xmin) ./ faixa;                    % 0 a 1
            else
                Xn = (2 * X - stats.xmax - stats.xmin) ./ faixa;   % -1 a 1
            end

        otherwise
            error('Normalizacao desconhecida: %s', tipo);
    end
end
