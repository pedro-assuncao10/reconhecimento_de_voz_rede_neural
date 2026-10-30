%% ========================================================================
%  EXTRAIR_ENTRADAS.M
%  ------------------------------------------------------------------------
%  Transforma o audio nos vetores de entrada da rede: amplitudes das
%  frequencias (FFT), agrupadas em faixas de 0 a 5 kHz (espectro_bandas.m).
%  Tambem sorteia quais amostras vao para treino (70%), teste (20%) e
%  validacao (10%).
%
%  DOIS MODOS de gerar as amostras (variavel 'modo'):
%    'trechos' - cada silaba recortada inteira vira UMA amostra.
%    'janelas' - (padrao) cada palavra e percorrida por uma janela deslizante
%                IGUAL a do programa 2 (mesma duracao e mesmo passo). Cada
%                janela vira uma amostra, rotulada com a silaba onde cai o
%                CENTRO da janela. Assim a rede treina com exatamente o tipo
%                de entrada que vai receber no reconhecimento, e ainda ganha
%                muito mais exemplos. O silencio tambem e percorrido por
%                janelas.
%
%  Gera um arquivo por combinacao (metodo de corte x numero de faixas):
%    entradas/entradas_<metodo>_<faixas>.mat, contendo:
%    X        - matriz n x B: amplitudes por faixa (SEM normalizar)
%    y        - classe de cada amostra (1..7, na ordem de 'classes')
%    conj     - conjunto de cada amostra: 1 = treino, 2 = teste, 3 = validacao
%    arquivos - origem de cada amostra, no formato '<silaba>_<repeticao>.wav'
%    classes, f_min, f_max, n_bandas, fs, modo, janela, passo
%
%  IMPORTANTE - divisao por PALAVRA, e nao por amostra:
%  tudo que vem de uma mesma repeticao (as 3 silabas, ou todas as janelas
%  dela) vai para o MESMO conjunto. Assim as palavras de teste nunca tiveram
%  nenhum pedaco visto no treino, e o programa 2 pode ser testado nelas de
%  forma justa. A divisao e a mesma para os dois metodos de corte.
%
%  Requisito: rodar antes segmentar_audios.m
%  ========================================================================

clear; clc;

%% 1. CONFIGURACAO ---------------------------------------------------------
pasta_script   = fileparts(mfilename('fullpath'));
pasta_seg      = fullfile(pasta_script, '..', 'segmentacao');
pasta_trechos  = fullfile(pasta_seg, 'saida');
pasta_entradas = fullfile(pasta_script, 'entradas');
if ~exist(pasta_entradas, 'dir'), mkdir(pasta_entradas); end

modo         = 'janelas';                      % 'janelas' ou 'trechos'
janela       = 0.150;                          % duracao da janela (s) - modo 'janelas'
passo        = 0.025;                          % passo da janela (s)   - modo 'janelas'
                                               % (o programa 2 usa estes mesmos valores)
metodos      = {'tercos', 'energia'};          % os dois metodos de corte
palavras     = {'direita', 'esquerda'};
silabas      = {{'di', 'rei', 'ta'}, {'es', 'quer', 'da'}};
classes      = {'di', 'rei', 'ta', 'es', 'quer', 'da', 'silencio'};
grupo_classe = [1 1 1 2 2 2 3];                % 1 = direita, 2 = esquerda, 3 = silencio
lista_bandas = [32 64];                        % numeros de faixas a testar
f_min = 0;                                     % faixa de frequencia usada:
f_max = 5000;                                  % 0 a 5 kHz (decisao do projeto)
fracoes = [0.70 0.20 0.10];                    % treino, teste, validacao

rng(42);   % semente fixa: o sorteio sai igual toda vez que rodar

%% 2. SORTEIO DOS CONJUNTOS (por palavra) ----------------------------------
% Conta quantas repeticoes existem em cada grupo, olhando a 1a classe dele.
n_grupo = zeros(1, 3);
for g = 1:3
    c = find(grupo_classe == g, 1);
    n_grupo(g) = numel(dir(fullfile(pasta_trechos, 'tercos', classes{c}, '*.wav')));
end

% Para cada grupo, embaralha os numeros das repeticoes e reparte 70/20/10.
conj_grupo = cell(1, 3);
for g = 1:3
    n  = n_grupo(g);
    nt = round(fracoes(1) * n);                % quantidade de treino
    ns = round(fracoes(2) * n);                % quantidade de teste
    c  = zeros(n, 1);
    ordem = randperm(n);
    c(ordem(1:nt))         = 1;                % treino
    c(ordem(nt+1:nt+ns))   = 2;                % teste
    c(ordem(nt+ns+1:end))  = 3;                % validacao (o restante)
    conj_grupo{g} = c;
    fprintf('Grupo %d: %d repeticoes -> treino %d, teste %d, validacao %d\n', ...
        g, n, sum(c == 1), sum(c == 2), sum(c == 3));
end

% No modo 'janelas', le uma vez as gravacoes completas e os cortes de
% cada palavra (tempos em segundos, salvos por segmentar_audios.m).
if strcmp(modo, 'janelas')
    grav = cell(1, 2);  cortes = cell(1, 2);
    for w = 1:2
        [x, fs] = audioread(fullfile(pasta_seg, 'audios_wav', [palavras{w} '.wav']));
        grav{w} = mean(x, 2);
        % Colunas do CSV: palavra; inicio; A_corte1; A_corte2; B_corte1;
        % B_corte2; fim; reserva  (separador ';', 1 linha de cabecalho)
        cortes{w} = dlmread(fullfile(pasta_trechos, ['cortes_' palavras{w} '.csv']), ';', 1, 0);
    end
end

%% 3. EXTRACAO DAS ENTRADAS ------------------------------------------------
for m = 1:numel(metodos)
    for nb = lista_bandas
        X = []; y = []; conj = []; arquivos = {};

        if strcmp(modo, 'trechos')
            % ---- Cada silaba recortada = uma amostra --------------------
            for c = 1:numel(classes)
                lista = dir(fullfile(pasta_trechos, metodos{m}, classes{c}, '*.wav'));
                for k = 1:numel(lista)
                    nome = lista(k).name;
                    % Numero da repeticao, tirado do nome ('rei_012.wav' -> 12)
                    num = str2double(regexprep(nome, '^.*_(\d+)\.wav$', '$1'));
                    [x, fs] = audioread(fullfile(lista(k).folder, nome));
                    X(end+1, :)  = espectro_bandas(mean(x, 2), fs, nb, f_min, f_max); %#ok<SAGROW>
                    y(end+1, 1)  = c;                                                 %#ok<SAGROW>
                    conj(end+1, 1) = conj_grupo{grupo_classe(c)}(num);                %#ok<SAGROW>
                    arquivos{end+1, 1} = nome;                                        %#ok<SAGROW>
                end
            end

        else
            % ---- Janelas deslizantes sobre cada palavra -----------------
            J  = round(janela * fs);               % amostras por janela
            Pp = round(passo  * fs);               % amostras por passo
            col = 2 * m + [1 2];                   % colunas dos cortes deste metodo
            for w = 1:2
                xw = grav{w};  C = cortes{w};
                for k = 1:size(C, 1)
                    num = C(k, 1);
                    t_ini = C(k, 2);  t_fim = C(k, 7);   % limites da palavra (s)
                    c1 = C(k, col(1));  c2 = C(k, col(2)); % fronteiras das silabas (s)
                    % Centros das janelas: do inicio ao fim da palavra
                    for ct = round(t_ini * fs) : Pp : round(t_fim * fs)
                        a = ct - floor(J/2);               % 1a amostra da janela
                        if a < 1 || a + J - 1 > numel(xw), continue; end
                        % Rotulo = silaba onde cai o CENTRO da janela
                        t = ct / fs;
                        if t < c1, s = 1; elseif t < c2, s = 2; else, s = 3; end
                        X(end+1, :) = espectro_bandas(xw(a : a + J - 1), fs, nb, f_min, f_max); %#ok<SAGROW>
                        y(end+1, 1) = find(strcmp(classes, silabas{w}{s}));                    %#ok<SAGROW>
                        conj(end+1, 1) = conj_grupo{w}(num);                                   %#ok<SAGROW>
                        arquivos{end+1, 1} = sprintf('%s_%03d.wav', silabas{w}{s}, num);      %#ok<SAGROW>
                    end
                end
            end
            % Silencio: janelas deslizantes dentro de cada amostra de silencio
            lista = dir(fullfile(pasta_trechos, metodos{m}, 'silencio', '*.wav'));
            for k = 1:numel(lista)
                nome = lista(k).name;
                num  = str2double(regexprep(nome, '^.*_(\d+)\.wav$', '$1'));
                [xs, fs] = audioread(fullfile(lista(k).folder, nome));
                xs = mean(xs, 2);
                for a = 1 : Pp : numel(xs) - J + 1
                    X(end+1, :) = espectro_bandas(xs(a : a + J - 1), fs, nb, f_min, f_max); %#ok<SAGROW>
                    y(end+1, 1) = numel(classes);                                          %#ok<SAGROW>
                    conj(end+1, 1) = conj_grupo{3}(num);                                   %#ok<SAGROW>
                    arquivos{end+1, 1} = nome;                                             %#ok<SAGROW>
                end
            end
        end

        n_bandas = nb;
        arq = fullfile(pasta_entradas, sprintf('entradas_%s_%d.mat', metodos{m}, nb));
        % '-v7' = formato .mat que o MATLAB e o Octave leem igualmente
        save(arq, 'X', 'y', 'conj', 'arquivos', 'classes', 'f_min', 'f_max', ...
             'n_bandas', 'fs', 'modo', 'janela', 'passo', '-v7');
        fprintf('%-8s %2d faixas: %d amostras (treino %d, teste %d, validacao %d)\n', ...
            metodos{m}, nb, numel(y), sum(conj == 1), sum(conj == 2), sum(conj == 3));
        fprintf('         amostras por classe: %s\n', num2str(accumarray(y, 1)'));
    end
end

fprintf('\nEntradas salvas em: %s\n', pasta_entradas);
