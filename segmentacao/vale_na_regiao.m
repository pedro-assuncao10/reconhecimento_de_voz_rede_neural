function [corte, prom] = vale_na_regiao(e, a, b, regiao)
    % VALE_NA_REGIAO  Acha o "vale" de energia mais profundo numa parte da palavra.
    %   Usada pelo Metodo B de segmentar_audios.m para decidir onde cortar
    %   as silabas: quando a boca fecha numa consoante (/k/, /t/, /d/),
    %   a energia do som cai e forma um vale na curva.
    %
    % Entradas:
    %   e      - curva de energia (dB) da gravacao inteira, um valor por quadro
    %   a, b   - primeiro e ultimo quadro da palavra
    %   regiao - [inicio fim] relativos a palavra, ex.: [0.15 0.50] = de 15% a 50%
    % Saidas:
    %   corte  - quadro do vale escolhido ([] se nao houver nenhum)
    %   prom   - profundidade do vale em dB (proeminencia): quanto ele
    %            fica abaixo do MENOR dos dois picos que o cercam.

    w = e(a:b);                                 % energia so desta palavra
    n = numel(w);
    i0 = max(2,     ceil(regiao(1) * n) + 1);   % +1 porque o MATLAB comeca em 1
    i1 = min(n - 1, floor(regiao(2) * n) + 1);

    corte = []; prom = 0;
    for i = i0:i1
        % Minimo local: menor ou igual aos dois vizinhos.
        eh_minimo = w(i) <= w(i-1) && w(i) <= w(i+1);
        if eh_minimo
            % Profundidade = menor entre (maior pico a esquerda) e
            % (maior pico a direita), menos o valor do vale.
            p = min(max(w(1:i-1)), max(w(i+1:end))) - w(i);
            if p > prom                         % guarda o vale mais profundo
                prom  = p;
                corte = a + i - 1;              % converte para indice da gravacao
            end
        end
    end
end
