function varargout = rbf(acao, varargin)
    % RBF  Rede de funcao de base radial feita a mao, seguindo o algoritmo
    % da aula (slide 14):
    %   1) normalizar a entrada (feito antes, em entrada.m);
    %   2) determinar o centro dos neuronios escondidos (algoritmo WTA);
    %   3) determinar a abertura dos neuronios escondidos;
    %   4) congelar centros e aberturas;
    %   5) determinar os pesos da camada de saida (regra delta, como na MLP).
    %
    %   entrada -> K neuronios gaussianos -> saida (uma por classe)
    %
    %   Cada neuronio escondido i tem um centro c_i e uma abertura s_i, e
    %   responde out_i = exp(-|x - c_i|^2 / (2 s_i^2)): 1 quando a entrada
    %   esta em cima do centro, perto de 0 quando esta longe.
    %
    % Uso:
    %   rede        = rbf('treinar', Xtr, ytr, n_classes, o, Xva, yva)
    %   [classe, S] = rbf('classificar', rede, X)
    %   D           = rbf('dividir', D)   divisao 75/15/10 das amostras
    %
    % Opcoes (o):
    %   o.K          - numero de neuronios escondidos (centros)
    %   o.centros    - 'wta' (algoritmo da aula) ou 'kmeans' (comparacao)
    %   o.eta_c      - taxa de aprendizado do WTA
    %   o.largura    - 'unica'  : s = k * dmax (o mesmo raio para todos)
    %                  'metade' : s_i = metade da distancia ao centro mais perto
    %                  'media'  : s_i = media das distancias aos T centros mais perto
    %   o.k, o.T     - parametros da abertura
    %   o.saida      - 'delta' (regra delta, como na MLP) ou 'cholesky'
    %                  (minimos quadrados resolvidos a mao, so para comparar)
    %   o.ativ_saida - 'linear' ou 'sigmoide' (funcao dos neuronios de saida)
    %   o.taxa       - taxa de aprendizado da regra delta
    %   o.momento    - momento da regra delta (0 = sem momento; a MLP usa 0,9)
    %   o.epocas     - numero maximo de epocas da regra delta
    %
    % No MATLAB/Octave, outro arquivo so consegue chamar a primeira funcao
    % de um arquivo. Por isso esta primeira funcao so recebe o nome da acao
    % e chama a funcao certa, que esta mais abaixo.

    n = max(nargout, 1);
    switch acao
        case 'treinar',     [varargout{1:n}] = treinar(varargin{:});
        case 'ativar',      [varargout{1:n}] = ativar(varargin{:});
        case 'classificar', [varargout{1:n}] = classificar(varargin{:});
        case 'dividir',     [varargout{1:n}] = dividir(varargin{:});
        case 'wta',         [varargout{1:n}] = wta(varargin{:});
        case 'kmeans',      [varargout{1:n}] = kmeans_mao(varargin{:});
        case 'cholesky',    [varargout{1:n}] = resolve_cholesky(varargin{:});
        otherwise, error('rbf: acao desconhecida: %s', acao);
    end
end


function rede = treinar(Xtr, ytr, n_classes, o, Xva, yva)
    % TREINAR  Passos 2 a 5 do algoritmo (a entrada ja vem normalizada).

    % 2) Centros dos neuronios escondidos
    if strcmp(o.centros, 'kmeans')
        C = kmeans_mao(Xtr, o.K);
    else
        C = wta(Xtr, o.K, o.eta_c);
    end
    K = size(C, 1);

    % 3) Aberturas (slide 12)
    Dc = sqrt(distancia2(C, C));                   % distancia entre os centros
    Dc(1:K+1:end) = Inf;                           % ignora a distancia de cada um a ele mesmo
    switch o.largura
        case 'unica'                               % raio unico: s = k * dmax
            s = o.k * max(Dc(isfinite(Dc))) * ones(1, K);
        case 'metade'                              % metade da distancia ao centro mais perto
            s = min(Dc, [], 2)' / 2;
        case 'media'                               % media das distancias aos T centros mais perto
            Ds = sort(Dc, 2);
            s = mean(Ds(:, 1:o.T), 2)';
    end
    s = max(s, 1e-6);                              % abertura nunca zero

    % 4) Centros e aberturas ficam congelados daqui para a frente
    rede.C = C;  rede.s = s;  rede.n_classes = n_classes;  rede.opcoes = o;

    % 5) Pesos da camada de saida
    Phi = ativar(rede, Xtr);
    Y = zeros(numel(ytr), n_classes);
    Y(sub2ind(size(Y), (1:numel(ytr))', ytr(:))) = 1;    % 1 na classe certa
    if strcmp(o.saida, 'cholesky')
        % Comparacao: minimos quadrados, (Phi'Phi) W = Phi'Y. Um valor
        % minusculo na diagonal garante solucao com centros quase iguais.
        A = Phi' * Phi;
        A(1:size(A,1)+1:end) = A(1:size(A,1)+1:end) + 1e-10 * mean(diag(A));
        rede.W = resolve_cholesky(A, Phi' * Y);
        rede.epoca = 0;
    else
        Phiva = ativar(rede, Xva);
        Yva = zeros(numel(yva), n_classes);
        Yva(sub2ind(size(Yva), (1:numel(yva))', yva(:))) = 1;
        if ~isfield(o, 'momento'), o.momento = 0; end
        if ~isfield(o, 'epocas'), o.epocas = 1000; end
        [rede.W, rede.epoca] = regra_delta(Phi, Y, Phiva, Yva, o.taxa, o.ativ_saida, o.momento, o.epocas);
    end
end


function Phi = ativar(rede, X)
    % ATIVAR  Saida dos K neuronios escondidos para cada amostra, mais uma
    % coluna de 1 (o bias da camada de saida).
    D = distancia2(X, rede.C);                     % |x - c|^2, n x K
    Phi = [exp(-D ./ (2 * rede.s.^2)), ones(size(X, 1), 1)];
end


function [classe, S] = classificar(rede, X)
    % CLASSIFICAR  Classe de cada amostra: o neuronio de saida de maior valor.
    S = ativar(rede, X) * rede.W;
    if isfield(rede.opcoes, 'ativ_saida') && strcmp(rede.opcoes.ativ_saida, 'sigmoide') ...
            && ~strcmp(rede.opcoes.saida, 'cholesky')
        S = 1 ./ (1 + exp(-S));
    end
    [~, classe] = max(S, [], 2);
end


function D = distancia2(X, C)
    % DISTANCIA2  Distancia euclidiana ao quadrado entre cada linha de X e
    % cada linha de C, de uma vez: |x - c|^2 = |x|^2 + |c|^2 - 2 x.c
    D = sum(X.^2, 2) + sum(C.^2, 2)' - 2 * X * C';
    D = max(D, 0);                                 % tira negativos de arredondamento
end


function [C, Eq] = wta(X, K, eta)
    % WTA  Algoritmo "o vencedor leva tudo" (slide 10):
    %   1) taxa de aprendizado eta;
    %   2) centros iniciais sorteados entre as amostras de treino;
    %   3) para cada amostra x, so o centro mais perto (o vencedor) anda
    %      na direcao dela: c = c + eta (x - c);
    %   4) repete enquanto o erro de quantizacao Eq (distancia media ao
    %      quadrado de cada amostra ao seu centro mais perto) ainda cai
    %      mais de 0,1% de uma passada para a outra (no maximo 100 passadas).
    n = size(X, 1);
    ordem = randperm(n);
    C = X(ordem(1:K), :);
    Eq_ant = Inf;
    for passada = 1:100
        for t = randperm(n)
            x = X(t, :);
            [~, i] = min(sum((C - x).^2, 2));      % centro vencedor
            C(i, :) = C(i, :) + eta * (x - C(i, :));
        end
        Eq = mean(min(distancia2(X, C), [], 2));   % erro de quantizacao
        if Eq_ant - Eq < 1e-3 * Eq_ant, break; end
        Eq_ant = Eq;
    end
end


function C = kmeans_mao(X, K)
    % KMEANS_MAO  Comparacao com o WTA: liga cada amostra ao centro mais
    % perto, move cada centro para a media das suas amostras e repete ate
    % ninguem trocar de centro (no maximo 100 vezes).
    n = size(X, 1);
    ordem = randperm(n);
    C = X(ordem(1:K), :);
    grupo = zeros(n, 1);
    for it = 1:100
        D = distancia2(X, C);
        [dmin, novo] = min(D, [], 2);
        if isequal(novo, grupo), break; end
        grupo = novo;
        for k = 1:K
            sel = grupo == k;
            if any(sel)
                C(k, :) = mean(X(sel, :), 1);
            else
                [~, j] = max(dmin);                % centro vazio vai para a amostra mais longe
                C(k, :) = X(j, :);
                dmin(j) = 0;
            end
        end
    end
end


function [melhor, melhor_ep] = regra_delta(Phi, Y, Phiva, Yva, taxa, ativ, momento, epocas)
    % REGRA_DELTA  Pesos da saida como no treino da MLP (slide 13):
    %   delta_W = taxa * e * f' * out
    %   e   = saida desejada - saida da rede
    %   f'  = derivada da funcao de saida: 1 (linear) ou y(1 - y) (sigmoide)
    %   out = saida dos neuronios escondidos (congelados)
    % Com momento, como na MLP: v = momento * v + delta_W;  W = W + v.
    % Em lotes de 32, com parada antecipada pela validacao (paciencia de 200
    % epocas, no maximo 'epocas').
    sig = strcmp(ativ, 'sigmoide');
    W = zeros(size(Phi, 2), size(Y, 2));
    n = size(Phi, 1);
    v = zeros(size(W));                            % "velocidade" do momento
    melhor = W;  melhor_erro = Inf;  melhor_ep = 0;  sem_melhora = 0;
    for ep = 1:epocas
        ordem = randperm(n);
        for ini = 1:32:n
            idx = ordem(ini : min(ini + 31, n));
            y = Phi(idx, :) * W;
            if sig
                y = 1 ./ (1 + exp(-y));
                fd = y .* (1 - y);                  % derivada da sigmoide
            else
                fd = 1;                             % derivada da linear
            end
            e = Y(idx, :) - y;
            v = momento * v + taxa * Phi(idx, :)' * (e .* fd) / numel(idx);
            W = W + v;
        end
        yva = Phiva * W;
        if sig, yva = 1 ./ (1 + exp(-yva)); end
        erro = mean(mean((Yva - yva).^2));
        if erro < melhor_erro
            melhor = W;  melhor_erro = erro;  melhor_ep = ep;  sem_melhora = 0;
        else
            sem_melhora = sem_melhora + 1;
            if sem_melhora >= 200, break; end
        end
    end
end


function W = resolve_cholesky(A, B)
    % RESOLVE_CHOLESKY  Resolve A W = B (A simetrica e positiva) sem a barra
    % invertida: fatora A = L L' e resolve L Z = B e depois L' W = Z.
    m = size(A, 1);
    L = zeros(m);
    for j = 1:m
        d = A(j, j) - L(j, 1:j-1) * L(j, 1:j-1)';
        L(j, j) = sqrt(d);
        L(j+1:m, j) = (A(j+1:m, j) - L(j+1:m, 1:j-1) * L(j, 1:j-1)') / L(j, j);
    end
    Z = zeros(size(B));
    for i = 1:m
        Z(i, :) = (B(i, :) - L(i, 1:i-1) * Z(1:i-1, :)) / L(i, i);
    end
    W = zeros(size(B));
    for i = m:-1:1
        W(i, :) = (Z(i, :) - L(i+1:m, i)' * W(i+1:m, :)) / L(i, i);
    end
end


function D = dividir(D)
    % DIVIDIR  Divisao pedida no enunciado do trabalho da RBF: treino 75%,
    % validacao 15%, teste 10%, por repeticao da palavra (todas as janelas
    % de uma repeticao vao para o mesmo conjunto). O sorteio e feito uma vez
    % e fica gravado em divisao_rbf.csv, para ser o mesmo no MATLAB e no
    % Octave. Grava o campo D.conj (1 = treino, 2 = teste, 3 = validacao).
    arq = fullfile(fileparts(mfilename('fullpath')), 'divisao_rbf.csv');
    grupo = 1 + (D.y >= 4) + (D.y == 7);           % 1 direita, 2 esquerda, 3 silencio
    num = cellfun(@(a) str2double(regexprep(a, '^.*_(\d+)\.wav$', '$1')), D.arquivos);
    if exist(arq, 'file')
        T = dlmread(arq, ';', 1, 0);               % grupo; repeticao; conjunto
    else
        rng(42);
        T = [];
        for g = 1:3
            n = max(num(grupo == g));
            nt = round(0.75 * n);  nv = round(0.15 * n);
            c = 2 * ones(n, 1);                    % teste: o que sobra (10%)
            ordem = randperm(n);
            c(ordem(1:nt)) = 1;                    % treino
            c(ordem(nt+1:nt+nv)) = 3;              % validacao
            T = [T; g * ones(n, 1), (1:n)', c];
        end
        fid = fopen(arq, 'w');
        fprintf(fid, 'grupo;repeticao;conjunto\n');
        fprintf(fid, '%d;%d;%d\n', T');
        fclose(fid);
    end
    D.conj = zeros(size(D.y));
    for g = 1:3
        tg = T(T(:, 1) == g, :);
        sel = grupo == g;
        D.conj(sel) = tg(num(sel), 3);
    end
end
