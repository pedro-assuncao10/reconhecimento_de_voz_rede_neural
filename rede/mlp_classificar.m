function [classe, S] = mlp_classificar(rede, X)
    % MLP_CLASSIFICAR  Diz qual classe a rede reconhece para cada amostra.
    %
    % Entradas:
    %   rede - rede treinada
    %   X    - entradas ja normalizadas (uma amostra por linha)
    % Saidas:
    %   classe - indice da classe vencedora (neuronio de saida com maior valor)
    %   S      - saidas da rede (n x n_classes), valores entre 0 e 1
    A = mlp_propagar(rede, X);
    S = A{end};
    [~, classe] = max(S, [], 2);
end
