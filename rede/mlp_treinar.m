function [melhor, hist] = mlp_treinar(rede, Xtr, Ytr, Xva, Yva, p)
    % MLP_TREINAR  Treina a MLP com retropropagacao do erro (backpropagation).
    %
    %   Algoritmo (por lote de amostras):
    %     1) Propagacao direta: calcula a saida da rede.
    %     2) Erro na saida: e = saida_obtida - saida_desejada.
    %     3) Gradiente local (delta) da camada de saida:
    %            delta = e .* y .* (1 - y)      (y .* (1-y) = derivada da sigmoide)
    %     4) Retropropaga o delta camada por camada, da saida para a entrada:
    %            delta_anterior = (delta * W') .* a .* (1 - a)
    %     5) Atualiza pesos e bias com taxa de aprendizado e momento:
    %            v = momento * v - taxa * gradiente
    %            W = W + v
    %   Ao fim de cada epoca, mede o erro no conjunto de VALIDACAO e guarda
    %   a rede com o menor erro de validacao ("parada antecipada"): se a
    %   validacao nao melhorar por 'paciencia' epocas, o treino para.
    %
    % Entradas:
    %   rede     - rede inicial (mlp_criar)
    %   Xtr, Ytr - entradas e saidas desejadas de treino (uma amostra por linha)
    %   Xva, Yva - entradas e saidas desejadas de validacao
    %   p        - parametros: p.taxa, p.momento, p.epocas_max,
    %              p.tam_lote, p.paciencia
    % Saidas:
    %   melhor - rede com menor erro de validacao
    %   hist   - historico por epoca: erro_tr, erro_va (erro quadratico
    %            medio), acerto_va (fracao de acertos na validacao),
    %            e melhor_epoca

    L  = numel(rede.W);
    n  = size(Xtr, 1);
    relu = isfield(rede, 'ativacao') && strcmp(rede.ativacao, 'relu');

    % Velocidades do momento (comecam em zero), uma por matriz de pesos.
    vW = cell(1, L);  vb = cell(1, L);
    for l = 1:L
        vW{l} = zeros(size(rede.W{l}));
        vb{l} = zeros(size(rede.b{l}));
    end

    hist.erro_tr   = zeros(p.epocas_max, 1);
    hist.erro_va   = zeros(p.epocas_max, 1);
    hist.acerto_va = zeros(p.epocas_max, 1);
    melhor = rede;  melhor_erro = Inf;  hist.melhor_epoca = 0;
    sem_melhora = 0;

    for ep = 1:p.epocas_max
        ordem = randperm(n);                    % embaralha as amostras a cada epoca

        for ini = 1:p.tam_lote:n
            idx = ordem(ini : min(ini + p.tam_lote - 1, n));   % amostras do lote
            nb  = numel(idx);

            % 1) Propagacao direta
            A = mlp_propagar(rede, Xtr(idx, :));

            % 2) e 3) Erro e delta da camada de saida
            e     = A{L + 1} - Ytr(idx, :);
            delta = e .* A{L + 1} .* (1 - A{L + 1});

            % 4) e 5) Retropropagacao e atualizacao, da ultima camada a primeira
            for l = L:-1:1
                gW = A{l}' * delta / nb;        % gradiente medio dos pesos
                gb = mean(delta, 1);            % gradiente medio do bias
                if l > 1
                    % delta da camada anterior (usa os pesos ANTES da atualizacao),
                    % vezes a derivada da ativacao oculta:
                    %   sigmoide: a .* (1 - a)      ReLU: 1 se a > 0, senao 0
                    if relu
                        derivada = A{l} > 0;
                    else
                        derivada = A{l} .* (1 - A{l});
                    end
                    delta_ant = (delta * rede.W{l}') .* derivada;
                end
                vW{l} = p.momento * vW{l} - p.taxa * gW;
                vb{l} = p.momento * vb{l} - p.taxa * gb;
                rede.W{l} = rede.W{l} + vW{l};
                rede.b{l} = rede.b{l} + vb{l};
                if l > 1
                    delta = delta_ant;
                end
            end
        end

        % Avaliacao ao fim da epoca
        Str = mlp_propagar(rede, Xtr);  Str = Str{end};
        Sva = mlp_propagar(rede, Xva);  Sva = Sva{end};
        hist.erro_tr(ep) = mean((Str(:) - Ytr(:)).^2);
        hist.erro_va(ep) = mean((Sva(:) - Yva(:)).^2);
        [~, prev] = max(Sva, [], 2);            % classe prevista = maior saida
        [~, certa] = max(Yva, [], 2);           % classe correta
        hist.acerto_va(ep) = mean(prev == certa);

        % Parada antecipada: guarda a melhor rede segundo a validacao
        if hist.erro_va(ep) < melhor_erro
            melhor_erro = hist.erro_va(ep);
            melhor = rede;
            hist.melhor_epoca = ep;
            sem_melhora = 0;
        else
            sem_melhora = sem_melhora + 1;
            if sem_melhora >= p.paciencia
                break;                          % validacao parou de melhorar
            end
        end
    end

    % Corta o historico nas epocas realmente executadas
    hist.erro_tr   = hist.erro_tr(1:ep);
    hist.erro_va   = hist.erro_va(1:ep);
    hist.acerto_va = hist.acerto_va(1:ep);
end
