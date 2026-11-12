function [reconhecidas, reg] = reconhecer_palavra(x, fs, modelo, p)
    % RECONHECER_PALAVRA  Reconhece DIREITA e ESQUERDA num audio, usando a
    % rede treinada e uma maquina de estados. E o coracao do programa 2.
    %
    %   1) Janela deslizante: uma janela de p.janela segundos (150 ms)
    %      percorre o audio, andando p.passo segundos (25 ms) por vez. Cada
    %      janela vira o vetor de entrada (igual ao treino) e a rede diz
    %      qual silaba ela ouviu: di, rei, ta, es, quer, da ou silencio.
    %
    %   2) Confirmacao: uma resposta so e aceita se a rede der a mesma
    %      classe em p.n_conf janelas seguidas (no trabalho, n_conf = 1).
    %
    %   3) Maquina de estados (como pede o enunciado):
    %      - aguardando: espera a 1a silaba de uma palavra (di ou es);
    %      - ouviu a 1a: espera a 2a silaba dessa palavra (rei ou quer);
    %      - ouviu a 2a: espera a 3a (ta ou da);
    %      - ouviu a 3a: a palavra foi reconhecida, e volta a aguardar.
    %      Se aparecer uma silaba fora da ordem, ou silencio por mais de
    %      p.max_silencio segundos, a palavra e abandonada e o programa
    %      volta a aguardar. Se essa silaba for o inicio de uma palavra
    %      (di ou es), ele ja passa a seguir a nova palavra.
    %
    %   Tolerancia: p.max_fora janelas seguidas fora da ordem sao ignoradas
    %   antes de abandonar a palavra (no trabalho, 2 janelas = 50 ms). Isso
    %   evita que um erro isolado da rede derrube uma palavra falada certo.
    %   Uma silaba trocada de verdade ocupa de 6 a 10 janelas e continua
    %   reprovando a palavra.
    %
    % Entradas:
    %   x      - audio (mono)
    %   fs     - taxa de amostragem (Hz)
    %   modelo - rede e normalizacao, salvas por treinar_rbf.m
    %   p      - p.janela, p.passo, p.n_conf, p.max_silencio e p.max_fora
    %            (opcional, padrao 2; 0 = abandona na primeira janela errada)
    % Saidas:
    %   reconhecidas - uma linha por palavra reconhecida: .palavra e .tempo (s)
    %   reg          - resposta da rede em cada janela, para os graficos:
    %                  .t (tempo do centro da janela) e .classe

    % Ordem das silabas de cada palavra, como numeros de classe
    cls  = modelo.classes;
    idx  = @(nome) find(strcmp(cls, nome));
    palavras = {'direita', 'esquerda'};
    seq = {[idx('di'), idx('rei'), idx('ta')], ...
           [idx('es'), idx('quer'), idx('da')]};
    SIL = idx('silencio');

    % 1) Resposta da rede em cada janela
    x  = x(:);
    J  = round(p.janela * fs);                  % amostras por janela
    P  = round(p.passo  * fs);                  % amostras por passo
    nj = floor((numel(x) - J) / P) + 1;         % numero de janelas
    % Janelas vizinhas na entrada, do mesmo jeito que no treino (ver entrada.m)
    contexto = 0;
    if isfield(modelo, 'contexto'), contexto = modelo.contexto; end
    V  = zeros(nj, modelo.n_bandas * numel(contexto));
    for k = 1:nj
        V(k, :) = entrada('espectro', x, (k-1)*P + 1, J, P, contexto, fs, ...
                                    modelo.n_bandas, modelo.f_min, modelo.f_max);
    end
    Vn = entrada('normalizar', V, modelo.normalizacao, modelo.stats);  % mesma normalizacao do treino
    classe = rbf('classificar', modelo.rede, Vn);        % resposta da rede RBF
    reg.t = ((0:nj-1)' * P + J/2) / fs;
    reg.classe = classe;

    % 2) e 3) Confirmacao e maquina de estados
    reconhecidas = struct('palavra', {}, 'tempo', {});
    palavra_atual = 0;       % 0 = aguardando; 1 = direita; 2 = esquerda
    etapa = 0;               % quantas silabas da palavra ja foram ouvidas
    t_silencio = 0;          % janelas seguidas de silencio dentro da palavra
    max_sil_janelas = round(p.max_silencio / p.passo);
    max_fora = 2;  if isfield(p, 'max_fora'), max_fora = p.max_fora; end
    fora = 0;                % janelas seguidas fora da ordem

    for k = p.n_conf:nj
        % So aceita a classe se as ultimas n_conf janelas concordarem
        ultimas = classe(k - p.n_conf + 1 : k);
        if any(ultimas ~= ultimas(1))
            continue;                              % ainda nao confirmou: ignora
        end
        c = ultimas(1);

        if palavra_atual == 0
            % Aguardando: so a 1a silaba de uma palavra comeca a seguir
            for w = 1:2
                if c == seq{w}(1)
                    palavra_atual = w;  etapa = 1;  t_silencio = 0;
                end
            end
        else
            s = seq{palavra_atual};
            if c == s(etapa)
                t_silencio = 0;  fora = 0;         % continua na mesma silaba
            elseif c == s(etapa + 1)
                etapa = etapa + 1;                 % passou para a proxima silaba
                t_silencio = 0;  fora = 0;
                if etapa == 3                      % ouviu a ultima silaba
                    reconhecidas(end+1).palavra = palavras{palavra_atual};
                    reconhecidas(end).tempo = reg.t(k);
                    palavra_atual = 0;  etapa = 0; % volta a aguardar
                end
            elseif c == SIL
                t_silencio = t_silencio + 1;       % pausa curta e tolerada
                if t_silencio > max_sil_janelas
                    palavra_atual = 0;  etapa = 0; % pausa longa: desiste da palavra
                end
            else
                % Silaba fora da ordem: tolera ate max_fora janelas seguidas;
                % depois desiste da palavra. Se a silaba for o inicio de
                % uma palavra, ja passa a seguir essa palavra.
                fora = fora + 1;
                if fora <= max_fora, continue; end
                palavra_atual = 0;  etapa = 0;  fora = 0;
                for w = 1:2
                    if c == seq{w}(1)
                        palavra_atual = w;  etapa = 1;  t_silencio = 0;
                    end
                end
            end
        end
    end
end
