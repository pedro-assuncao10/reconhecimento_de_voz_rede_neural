function rede = mlp_criar(n_entradas, ocultas, n_saidas, ativacao)
    % MLP_CRIAR  Cria uma rede MLP com pesos iniciais aleatorios pequenos.
    %
    % Entradas:
    %   n_entradas - numero de neuronios de entrada (ex.: 32 ou 64 faixas)
    %   ocultas    - vetor com o numero de neuronios de cada camada oculta,
    %                ex.: [20] = 1 camada de 20; [20 10] = 2 camadas
    %   n_saidas   - numero de neuronios de saida (um por classe = 7)
    %   ativacao   - (opcional) funcao das camadas OCULTAS: 'sigmoide'
    %                (padrao) ou 'relu'. A camada de saida e sempre
    %                sigmoide (cada saida entre 0 e 1).
    % Saida:
    %   rede - estrutura com:
    %          rede.W{l} : matriz de pesos da camada l (entradas x neuronios)
    %          rede.b{l} : vetor linha de bias da camada l (1 x neuronios)
    %          rede.camadas : tamanhos de todas as camadas
    %          rede.ativacao : funcao das camadas ocultas

    if nargin < 4
        ativacao = 'sigmoide';
    end
    camadas = [n_entradas, ocultas, n_saidas];
    rede.camadas = camadas;
    rede.ativacao = ativacao;
    rede.W = cell(1, numel(camadas) - 1);
    rede.b = cell(1, numel(camadas) - 1);

    for l = 1:numel(camadas) - 1
        n_in  = camadas(l);      % neuronios que alimentam esta camada
        n_out = camadas(l + 1);  % neuronios desta camada
        % Inicializacao de Xavier/Glorot: sorteia pesos uniformes em
        % [-lim, +lim]. O limite depende do tamanho da camada para que os
        % neuronios sigmoides nao comecem saturados (perto de 0 ou 1),
        % onde a derivada e quase zero e a rede quase nao aprende.
        % Para ReLU (camadas ocultas) usa-se a inicializacao de He, que
        % compensa a ReLU zerar metade das saidas.
        lim = sqrt(6 / (n_in + n_out));
        if strcmp(ativacao, 'relu') && l < numel(camadas) - 1
            lim = sqrt(6 / n_in);
        end
        rede.W{l} = (2 * rand(n_in, n_out) - 1) * lim;
        rede.b{l} = zeros(1, n_out);
    end
end
