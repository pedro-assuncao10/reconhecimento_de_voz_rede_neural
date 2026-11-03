function [corte, prom, inicio] = vale_na_regiao(e, a, b, regiao)
    % VALE_NA_REGIAO  Acha o vale mais fundo da curva de volume numa parte
    % da palavra. E usada por segmentar_audios.m para decidir onde cortar as
    % silabas: quando a boca fecha numa consoante (/k/, /t/, /d/), o volume
    % do som cai e forma um vale na curva.
    %
    % Entradas:
    %   e      - curva de volume (dB) da gravacao inteira, um valor por quadro
    %   a, b   - primeiro e ultimo quadro da palavra
    %   regiao - onde procurar, em fracao da palavra. Ex.: [0.15 0.50] = de
    %            15% a 50% da palavra
    % Saidas:
    %   corte  - quadro do vale escolhido ([] se nao houver nenhum)
    %   prom   - profundidade do vale em dB: quanto ele fica abaixo do mais
    %            baixo dos dois picos ao redor dele
    %   inicio - quadro onde o vale comeca: andando do fundo para a
    %            esquerda, o primeiro ponto que passa de meia profundidade.
    %            E onde a vogal anterior acaba e a consoante comeca.

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

    % Inicio do vale (meia profundidade, lado esquerdo)
    inicio = corte;
    if ~isempty(corte)
        while inicio > a && e(inicio - 1) < e(corte) + prom / 2
            inicio = inicio - 1;
        end
    end
end
