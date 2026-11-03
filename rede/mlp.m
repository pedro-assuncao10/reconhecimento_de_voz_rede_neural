function varargout = mlp(acao, varargin)
    % MLP  Rede neural MLP feita a mao: criar, propagar, treinar e classificar.
    %
    % Uso:
    %   rede         = mlp('criar', n_entradas, ocultas, n_saidas, ativacao)
    %   A            = mlp('propagar', rede, X)
    %   [rede, hist] = mlp('treinar', rede, Xtr, Ytr, Xva, Yva, p)
    %   [classe, S]  = mlp('classificar', rede, X)
    %
    % Exemplo (a rede do trabalho): 160 entradas, ocultas de 64 e 32, 7 saidas
    %   rede = mlp('criar', 160, [64 32], 7, 'sigmoide');
    %
    % No MATLAB/Octave, outro arquivo so consegue chamar a primeira funcao
    % de um arquivo. Por isso esta primeira funcao so recebe o nome da acao
    % e chama a funcao certa, que esta mais abaixo.

    n = max(nargout, 1);
    switch acao
        case 'criar',       [varargout{1:n}] = criar(varargin{:});
        case 'propagar',    [varargout{1:n}] = propagar(varargin{:});
        case 'treinar',     [varargout{1:n}] = treinar(varargin{:});
        case 'classificar', [varargout{1:n}] = classificar(varargin{:});
        otherwise, error('mlp: acao desconhecida: %s', acao);
    end
end


function rede = criar(n_entradas, ocultas, n_saidas, ativacao)
    % CRIAR  Monta a rede com pesos iniciais pequenos, sorteados.
    %
    % Entradas:
    %   n_entradas - tamanho do vetor de entrada (160 na rede do trabalho)
    %   ocultas    - neuronios de cada camada oculta. Ex.: [64] = uma camada
    %                de 64; [64 32] = duas camadas, de 64 e de 32
    %   n_saidas   - um neuronio de saida por classe (7)
    %   ativacao   - funcao das camadas ocultas: 'sigmoide' (padrao) ou
    %                'relu'. A camada de saida e sempre sigmoide.
    % Saida:
    %   rede.W{l}     - pesos da camada l (linhas: entradas; colunas: neuronios)
    %   rede.b{l}     - bias da camada l (um por neuronio)
    %   rede.camadas  - tamanho de cada camada, ex.: [160 64 32 7]
    %   rede.ativacao - funcao das camadas ocultas

    if nargin < 4
        ativacao = 'sigmoide';
    end
    camadas = [n_entradas, ocultas, n_saidas];
    rede.camadas = camadas;
    rede.ativacao = ativacao;
    rede.W = cell(1, numel(camadas) - 1);
    rede.b = cell(1, numel(camadas) - 1);

    for l = 1:numel(camadas) - 1
        n_in  = camadas(l);      % neuronios da camada anterior
        n_out = camadas(l + 1);  % neuronios desta camada
        % Pesos sorteados entre -lim e +lim. O limite diminui quando a
        % camada e grande: com muitos pesos grandes, a soma que chega ao
        % neuronio fica enorme, a sigmoide fica "colada" em 0 ou 1 e a
        % derivada vira quase zero (a rede quase nao aprende).
        % Na ReLU o limite e um pouco maior, porque ela zera metade das
        % saidas.
        lim = sqrt(6 / (n_in + n_out));
        if strcmp(ativacao, 'relu') && l < numel(camadas) - 1
            lim = sqrt(6 / n_in);
        end
        rede.W{l} = (2 * rand(n_in, n_out) - 1) * lim;
        rede.b{l} = zeros(1, n_out);
    end
end


function A = propagar(rede, X)
    % PROPAGAR  Calcula a saida da rede (propagacao direta).
    %
    %   Em cada camada, cada neuronio faz a soma ponderada das entradas,
    %   soma o bias e aplica a funcao de ativacao:
    %       saida = ativacao(entrada * W + b)
    %
    % Entradas:
    %   rede - rede criada por mlp('criar')
    %   X    - uma amostra por linha
    % Saida:
    %   A    - saida de todas as camadas: A{1} = X, A{2} = 1a camada oculta,
    %          ..., A{end} = saida da rede. As saidas do meio sao guardadas
    %          porque o treino (retropropagacao) precisa delas.

    L = numel(rede.W);          % numero de camadas com pesos
    relu = isfield(rede, 'ativacao') && strcmp(rede.ativacao, 'relu');
    A = cell(1, L + 1);
    A{1} = X;
    for l = 1:L
        % Todas as amostras de uma vez: (n x entradas) * (entradas x
        % neuronios) = (n x neuronios). O bias e somado em todas as linhas.
        Z = A{l} * rede.W{l} + rede.b{l};
        if relu && l < L
            A{l + 1} = max(Z, 0);          % ReLU nas camadas ocultas
        else
            A{l + 1} = sigmoide(Z);        % sigmoide (a saida e sempre sigmoide)
        end
    end
end


function [melhor, hist] = treinar(rede, Xtr, Ytr, Xva, Yva, p)
    % TREINAR  Treina a rede por retropropagacao do erro.
    %
    %   Para cada lote de amostras:
    %     1) calcula a saida da rede;
    %     2) erro na saida: e = saida_obtida - saida_desejada;
    %     3) delta da camada de saida: delta = e .* y .* (1 - y)
    %        (y .* (1 - y) e a derivada da sigmoide);
    %     4) leva o delta para tras, camada por camada:
    %        delta_anterior = (delta * W') .* a .* (1 - a);
    %     5) atualiza pesos e bias com taxa de aprendizado e momento:
    %        v = momento * v - taxa * gradiente;   W = W + v
    %
    %   No fim de cada epoca, mede o erro na validacao e guarda a rede com
    %   o menor erro ate ali (parada antecipada). Se o erro nao melhorar
    %   por p.paciencia epocas seguidas, o treino para.
    %
    % Entradas:
    %   rede     - rede inicial (mlp('criar'))
    %   Xtr, Ytr - entradas e saidas desejadas do treino (uma amostra por linha)
    %   Xva, Yva - entradas e saidas desejadas da validacao
    %   p        - p.taxa, p.momento, p.epocas_max, p.tam_lote, p.paciencia
    % Saidas:
    %   melhor - a rede com menor erro na validacao
    %   hist   - por epoca: erro_tr e erro_va (erro quadratico medio),
    %            acerto_va (fracao de acertos na validacao) e melhor_epoca

    L  = numel(rede.W);
    n  = size(Xtr, 1);
    relu = isfield(rede, 'ativacao') && strcmp(rede.ativacao, 'relu');

    % "Velocidade" do momento de cada matriz de pesos (comeca em zero)
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
        ordem = randperm(n);                    % ordem diferente a cada epoca

        for ini = 1:p.tam_lote:n
            idx = ordem(ini : min(ini + p.tam_lote - 1, n));   % amostras deste lote
            nb  = numel(idx);

            % 1) Saida da rede para o lote
            A = propagar(rede, Xtr(idx, :));

            % 2) e 3) Erro e delta da camada de saida
            e     = A{L + 1} - Ytr(idx, :);
            delta = e .* A{L + 1} .* (1 - A{L + 1});

            % 4) e 5) Da ultima camada para a primeira: gradiente, delta da
            % camada anterior e atualizacao dos pesos
            for l = L:-1:1
                gW = A{l}' * delta / nb;        % gradiente medio dos pesos
                gb = mean(delta, 1);            % gradiente medio do bias
                if l > 1
                    % Delta da camada anterior, calculado com os pesos antes
                    % de atualizar, vezes a derivada da ativacao:
                    %   sigmoide: a .* (1 - a)     ReLU: 1 se a > 0, senao 0
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

        % Fim da epoca: erro no treino e na validacao
        Str = propagar(rede, Xtr);  Str = Str{end};
        Sva = propagar(rede, Xva);  Sva = Sva{end};
        hist.erro_tr(ep) = mean((Str(:) - Ytr(:)).^2);
        hist.erro_va(ep) = mean((Sva(:) - Yva(:)).^2);
        [~, prev] = max(Sva, [], 2);            % classe prevista = maior saida
        [~, certa] = max(Yva, [], 2);           % classe correta
        hist.acerto_va(ep) = mean(prev == certa);

        % Parada antecipada: guarda a rede de menor erro na validacao
        if hist.erro_va(ep) < melhor_erro
            melhor_erro = hist.erro_va(ep);
            melhor = rede;
            hist.melhor_epoca = ep;
            sem_melhora = 0;
        else
            sem_melhora = sem_melhora + 1;
            if sem_melhora >= p.paciencia
                break;                          % a validacao parou de melhorar
            end
        end
    end

    % Guarda so as epocas que de fato rodaram
    hist.erro_tr   = hist.erro_tr(1:ep);
    hist.erro_va   = hist.erro_va(1:ep);
    hist.acerto_va = hist.acerto_va(1:ep);
end


function [classe, S] = classificar(rede, X)
    % CLASSIFICAR  Diz a classe de cada amostra: o neuronio de saida com
    % o maior valor.
    %
    % Entradas:
    %   rede - rede treinada
    %   X    - entradas ja normalizadas (uma amostra por linha)
    % Saidas:
    %   classe - numero da classe vencedora de cada amostra
    %   S      - as 7 saidas da rede para cada amostra (entre 0 e 1)
    A = propagar(rede, X);
    S = A{end};
    [~, classe] = max(S, [], 2);
end


function y = sigmoide(z)
    % SIGMOIDE  y = 1 / (1 + e^(-z)): leva qualquer numero para entre 0 e 1.
    %   A derivada e simples, dy/dz = y .* (1 - y), e e ela que aparece
    %   na retropropagacao (funcao treinar, acima).
    y = 1 ./ (1 + exp(-z));
end
