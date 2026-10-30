function y = sigmoide(z)
    % SIGMOIDE  Funcao de ativacao logistica: y = 1 / (1 + e^(-z)).
    %   Leva qualquer numero real para o intervalo (0, 1).
    %   Sua derivada tem forma simples: dy/dz = y .* (1 - y),
    %   o que e usado na retropropagacao (mlp_treinar.m).
    y = 1 ./ (1 + exp(-z));
end
