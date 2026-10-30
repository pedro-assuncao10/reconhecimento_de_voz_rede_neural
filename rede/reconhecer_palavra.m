function [reconhecidas, reg] = reconhecer_palavra(x, fs, modelo, p)
    % RECONHECER_PALAVRA  Programa 2: reconhece DIREITA/ESQUERDA num audio
    % usando a rede treinada e uma maquina de estados.
    %
    %   1) JANELA DESLIZANTE: uma janela curta (p.janela segundos) percorre
    %      o audio, andando p.passo segundos por vez. Cada janela vira o
    %      vetor de entrada (espectro em faixas, normalizado igual ao
    %      treino) e a rede diz qual trecho ela ouviu (di, rei, ta, es,
    %      quer, da ou silencio).
    %
    %   2) ESTABILIDADE: a resposta da rede numa unica janela pode oscilar.
    %      Um trecho so e considerado "ouvido" quando a rede responde a
    %      mesma classe em p.n_conf janelas seguidas.
    %
    %   3) MAQUINA DE ESTADOS (como pede o enunciado):
    %      - AGUARDANDO: espera o 1o trecho de uma das palavras (di ou es).
    %      - Ouviu o 1o trecho: espera o 2o trecho DESSA palavra (rei / quer).
    %      - Ouviu o 2o trecho: espera o 3o trecho (ta / da).
    %      - Ouviu o 3o trecho: PALAVRA RECONHECIDA; volta a aguardar.
    %      Se aparecer um trecho fora da sequencia, ou silencio por mais de
    %      p.max_silencio segundos, a palavra e abandonada e o sistema
    %      volta a AGUARDAR o 1o trecho. (Se o trecho fora de sequencia for
    %      o inicio de uma palavra, ja comeca a acompanhar essa palavra.)
    %
    % Entradas:
    %   x      - audio (vetor de amostras, mono)
    %   fs     - taxa de amostragem (Hz)
    %   modelo - estrutura salva por treinar_mlp.m (rede + normalizacao)
    %   p      - parametros: p.janela, p.passo, p.n_conf, p.max_silencio
    % Saidas:
    %   reconhecidas - struct array com .palavra e .tempo (s) de cada
    %                  palavra reconhecida
    %   reg          - registro por janela, para graficos: .t (tempo do
    %                  centro da janela) e .classe (resposta da rede)

    % Sequencia esperada de cada palavra, em indices de modelo.classes
    cls  = modelo.classes;
    idx  = @(nome) find(strcmp(cls, nome));
    palavras = {'direita', 'esquerda'};
    seq = {[idx('di'), idx('rei'), idx('ta')], ...
           [idx('es'), idx('quer'), idx('da')]};
    SIL = idx('silencio');

    % ---- 1) Classifica todas as janelas ---------------------------------
    x  = x(:);
    J  = round(p.janela * fs);                  % amostras por janela
    P  = round(p.passo  * fs);                  % amostras por passo
    nj = floor((numel(x) - J) / P) + 1;         % numero de janelas
    V  = zeros(nj, modelo.n_bandas);
    for k = 1:nj
        trecho  = x((k-1)*P + (1:J));
        V(k, :) = espectro_bandas(trecho, fs, modelo.n_bandas, modelo.f_min, modelo.f_max);
    end
    Vn = normalizar(V, modelo.normalizacao, modelo.stats);  % mesma normalizacao do treino
    classe = mlp_classificar(modelo.rede, Vn);
    reg.t = ((0:nj-1)' * P + J/2) / fs;
    reg.classe = classe;

    % ---- 2) e 3) Estabilidade + maquina de estados ----------------------
    reconhecidas = struct('palavra', {}, 'tempo', {});
    palavra_atual = 0;       % 0 = AGUARDANDO; 1 = direita; 2 = esquerda
    etapa = 0;               % quantos trechos da palavra ja foram ouvidos
    t_silencio = 0;          % tempo continuo de silencio dentro da palavra
    max_sil_janelas = round(p.max_silencio / p.passo);

    for k = p.n_conf:nj
        % So aceita a classe se as ultimas n_conf janelas concordarem
        ultimas = classe(k - p.n_conf + 1 : k);
        if any(ultimas ~= ultimas(1))
            continue;                              % ainda instavel: ignora
        end
        c = ultimas(1);

        if palavra_atual == 0
            % ----- Estado AGUARDANDO: so o 1o trecho de uma palavra inicia
            for w = 1:2
                if c == seq{w}(1)
                    palavra_atual = w;  etapa = 1;  t_silencio = 0;
                end
            end
        else
            s = seq{palavra_atual};
            if c == s(etapa)
                t_silencio = 0;                    % continua no mesmo trecho
            elseif c == s(etapa + 1)
                etapa = etapa + 1;                 % avancou para o proximo trecho
                t_silencio = 0;
                if etapa == 3                      % ouviu o trecho final
                    reconhecidas(end+1).palavra = palavras{palavra_atual}; %#ok<AGROW>
                    reconhecidas(end).tempo = reg.t(k);
                    palavra_atual = 0;  etapa = 0; % volta a AGUARDAR
                end
            elseif c == SIL
                t_silencio = t_silencio + 1;       % pausa: tolera um pouco
                if t_silencio > max_sil_janelas
                    palavra_atual = 0;  etapa = 0; % pausa longa: desiste
                end
            else
                % Trecho fora da sequencia: desiste desta palavra. Se o
                % trecho for o inicio de uma palavra, ja passa a segui-la.
                palavra_atual = 0;  etapa = 0;
                for w = 1:2
                    if c == seq{w}(1)
                        palavra_atual = w;  etapa = 1;  t_silencio = 0;
                    end
                end
            end
        end
    end
end
