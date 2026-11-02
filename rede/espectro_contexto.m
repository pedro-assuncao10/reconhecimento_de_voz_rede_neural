function v = espectro_contexto(x, ini, J, passo_amostras, contexto, fs, n_bandas, f_min, f_max)
    % ESPECTRO_CONTEXTO  Vetor de entrada da rede: a janela atual + janelas
    % vizinhas (antes e depois), uma ao lado da outra.
    %
    %   Por que: olhando so 150 ms, o "e" do comeco de "es" e o "e" de
    %   "quer" sao a mesma vogal, e a rede nao tem como distingui-los. O que
    %   os diferencia e o que vem antes/depois (o "s" no "es", o "r" no
    %   "quer"). Com as janelas vizinhas na entrada, a rede "ouve" esse
    %   contexto.
    %
    % Entradas:
    %   x              - audio (vetor)
    %   ini            - 1a amostra da janela ATUAL em x
    %   J              - amostras por janela
    %   passo_amostras - amostras por passo (o deslocamento de 1 vizinho)
    %   contexto       - deslocamentos das janelas, em passos. Ex.: [-4 -2 0 2 4]
    %                    = 100 e 50 ms antes, a atual, 50 e 100 ms depois
    %                    (com passo de 25 ms). [0] = sem contexto.
    %   fs, n_bandas, f_min, f_max - como em espectro_bandas
    % Saida:
    %   v - vetor linha 1 x (n_bandas * numel(contexto))
    %
    %   Se um vizinho sair do audio (inicio ou fim), usa a janela da borda.

    x = x(:);
    v = zeros(1, n_bandas * numel(contexto));
    for i = 1:numel(contexto)
        a = ini + contexto(i) * passo_amostras;
        a = min(max(a, 1), numel(x) - J + 1);        % mantem dentro do audio
        v((i-1)*n_bandas + (1:n_bandas)) = espectro_bandas(x(a : a + J - 1), fs, n_bandas, f_min, f_max);
    end
end
