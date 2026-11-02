function A = mlp_propagar(rede, X)
    % MLP_PROPAGAR  Propagacao direta (forward): calcula a saida da rede.
    %
    %   Em cada camada, cada neuronio faz a soma ponderada das entradas
    %   (mais o bias) e aplica a funcao sigmoide:
    %       saida = sigmoide( entrada * W + b )
    %
    % Entradas:
    %   rede - estrutura criada por mlp_criar
    %   X    - matriz n x n_entradas (uma amostra por linha)
    % Saida:
    %   A    - cell com as ativacoes de todas as camadas:
    %          A{1} = X (entrada), A{2} = 1a oculta, ..., A{end} = saida.
    %          As ativacoes intermediarias sao guardadas porque a
    %          retropropagacao precisa delas.

    L = numel(rede.W);          % numero de camadas com pesos
    relu = isfield(rede, 'ativacao') && strcmp(rede.ativacao, 'relu');
    A = cell(1, L + 1);
    A{1} = X;
    for l = 1:L
        % A{l} (n x in) * W{l} (in x out) = (n x out); o bias (1 x out)
        % e somado a todas as linhas (expansao automatica).
        Z = A{l} * rede.W{l} + rede.b{l};
        if relu && l < L
            A{l + 1} = max(Z, 0);          % ReLU nas camadas ocultas
        else
            A{l + 1} = sigmoide(Z);        % sigmoide (sempre na saida)
        end
    end
end
