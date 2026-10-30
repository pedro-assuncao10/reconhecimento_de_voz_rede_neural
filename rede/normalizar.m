function [Xn, stats] = normalizar(X, tipo, stats)
    % NORMALIZAR  Coloca as entradas numa escala comparavel antes da rede.
    %   Sem normalizar, falar mais alto ou mais baixo mudaria a entrada,
    %   e a rede poderia confundir volume com fonema.
    %
    % Entradas:
    %   X     - matriz n x B (uma amostra por linha, uma faixa por coluna)
    %   tipo  - 'max'    : divide cada amostra pelo seu maior valor -> [0, 1]
    %           'db'     : escala logaritmica (decibeis) relativa ao maior
    %                      valor, de -60 dB a 0 dB, mapeada para [0, 1]
    %           'zscore' : para cada faixa, subtrai a media e divide pelo
    %                      desvio padrao (calculados SO no conjunto de treino)
    %   stats - (opcional) media/desvio do treino, para aplicar o 'zscore'
    %           em validacao, teste e no programa 2 com os mesmos valores
    % Saidas:
    %   Xn    - matriz normalizada (mesmo tamanho de X)
    %   stats - estrutura com media (mu) e desvio (sigma) usados

    if nargin < 3
        stats = struct();
    end

    switch tipo
        case 'max'
            Xn = X ./ max(X, [], 2);                  % cada linha / seu maximo

        case 'db'
            R  = X ./ max(X, [], 2);                  % relativo ao maximo (0..1)
            D  = 20 * log10(R + 1e-12);               % em decibeis (<= 0)
            D  = max(D, -60);                         % limita em -60 dB
            Xn = (D + 60) / 60;                       % -60..0 dB -> 0..1

        case 'zscore'
            if ~isfield(stats, 'mu')                  % 1a vez: calcula no treino
                stats.mu    = mean(X, 1);
                stats.sigma = std(X, 0, 1) + 1e-12;   % +1e-12 evita divisao por 0
            end
            Xn = (X - stats.mu) ./ stats.sigma;

        otherwise
            error('Normalizacao desconhecida: %s', tipo);
    end
end
