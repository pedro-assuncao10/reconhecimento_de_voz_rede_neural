%% EXTRAIR_ENTRADAS.M - transforma o audio nos exemplos de treino da rede
%
% Cada palavra e percorrida por uma janela de 150 ms que anda 25 ms por
% vez, a mesma janela do programa 2. Cada janela vira um exemplo de treino:
%   - entrada: as amplitudes do som em 32 faixas de 0 a 5 kHz (FFT, ver
%     entrada.m), da janela atual e, com contexto, tambem das vizinhas;
%   - rotulo: a silaba onde cai o centro da janela.
% Os trechos de silencio sao percorridos pela mesma janela.
%
% Tambem divide as repeticoes em treino (60%), teste (20%) e validacao
% (20%). A divisao e por palavra: todas as janelas de uma repeticao vao
% para o mesmo conjunto. Assim nenhum pedaco das palavras de teste aparece
% no treino, e o programa 2 pode ser testado nelas de forma justa.
%
% Gera um arquivo para cada combinacao de faixas e contexto:
%   entradas/entradas_energia_<faixas>.mat            (sem contexto)
%   entradas/entradas_energia_<faixas>_contexto.mat   (com contexto)
% com:
%   X        - uma linha por janela: as faixas da janela atual e das
%              vizinhas, ainda sem normalizar
%   y        - classe de cada janela (1 a 7, na ordem de 'classes')
%   conj     - conjunto de cada janela: 1 = treino, 2 = teste, 3 = validacao
%   arquivos - de onde veio cada janela, ex.: 'rei_012.wav'
%   classes, f_min, f_max, n_bandas, fs, modo, janela, passo, contexto
%
% As fronteiras das silabas vem do CSV gravado por segmentar_audios.m.
% Com metodos = {'tercos'}, gera as entradas com os cortes em tercos, que
% so foram usadas na comparacao do relatorio.
%
% Antes, rodar segmentar_audios.m.

clear; clc;

%% 1. Configuracao
pasta_script   = fileparts(mfilename('fullpath'));
pasta_seg      = fullfile(pasta_script, '..', 'segmentacao');
pasta_trechos  = fullfile(pasta_seg, 'saida');
pasta_entradas = fullfile(pasta_script, 'entradas');
if ~exist(pasta_entradas, 'dir'), mkdir(pasta_entradas); end

modo         = 'janelas';
janela       = 0.150;                          % duracao da janela (s)
passo        = 0.025;                          % quanto a janela anda (s)
                                               % (o programa 2 usa os mesmos valores)
contextos    = {[0], [-4 -2 0 2 4]};           % quais janelas entram, contadas em passos:
                                               %   [0]           = so a janela atual
                                               %   [-4 -2 0 2 4] = a atual e as vizinhas a
                                               %                   50 e 100 ms antes e depois
                                               % (gera um arquivo para cada opcao)
metodos      = {'energia'};                    % corte das silabas: 'energia' (o usado)
                                               % ou 'tercos' (so para comparar)
palavras     = {'direita', 'esquerda'};
silabas      = {{'di', 'rei', 'ta'}, {'es', 'quer', 'da'}};
classes      = {'di', 'rei', 'ta', 'es', 'quer', 'da', 'silencio'};
grupo_classe = [1 1 1 2 2 2 3];                % 1 = direita, 2 = esquerda, 3 = silencio
lista_bandas = [32 64];                        % numeros de faixas testados (a rede usa 32)
f_min = 0;                                     % faixa de frequencia: 0 a 5 kHz.
f_max = 5000;                                  % A voz vai ate ~4,2 kHz (ver o relatorio)
fracoes = [0.60 0.20 0.20];                    % treino, teste, validacao

rng(42);   % semente fixa do sorteio

%% 2. Divisao das repeticoes em treino, teste e validacao
% O sorteio e feito uma vez so e fica gravado em entradas/divisao.csv. O
% MATLAB e o Octave sorteiam numeros diferentes com a mesma semente; lendo
% o arquivo, a divisao e a mesma nos dois.

% Quantas repeticoes tem cada grupo (direita, esquerda, silencio)
n_grupo = zeros(1, 3);
for g = 1:3
    c = find(grupo_classe == g, 1);
    n_grupo(g) = numel(dir(fullfile(pasta_trechos, 'energia', classes{c}, '*.wav')));
end

% Se o arquivo existe, le a divisao dele; senao, embaralha as repeticoes de
% cada grupo e reparte em 60/20/20.
arq_divisao = fullfile(pasta_entradas, 'divisao.csv');
conj_grupo = cell(1, 3);
if exist(arq_divisao, 'file')
    T = dlmread(arq_divisao, ';', 1, 0);            % grupo; repeticao; conjunto
    for g = 1:3
        conj_grupo{g} = T(T(:, 1) == g, 3);
        fprintf('Grupo %d: divisao lida de divisao.csv (treino %d, teste %d, validacao %d)\n', g, ...
            sum(conj_grupo{g} == 1), sum(conj_grupo{g} == 2), sum(conj_grupo{g} == 3));
    end
end
for g = 1:3
    if ~isempty(conj_grupo{g}), continue; end      % ja veio do arquivo
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
if ~exist(arq_divisao, 'file')
    fid = fopen(arq_divisao, 'w');
    fprintf(fid, 'grupo;repeticao;conjunto\n');
    for g = 1:3
        fprintf(fid, '%d;%d;%d\n', [g * ones(1, numel(conj_grupo{g})); 1:numel(conj_grupo{g}); conj_grupo{g}']);
    end
    fclose(fid);
end

% Le as duas gravacoes e os cortes de cada palavra (tempos em segundos,
% gravados por segmentar_audios.m)
grav = cell(1, 2);  cortes = cell(1, 2);
for w = 1:2
    [x, fs] = audioread(fullfile(pasta_seg, 'audios', [palavras{w} '.flac']));
    grav{w} = mean(x, 2);
    % Colunas do CSV: palavra; inicio; A_corte1; A_corte2 (tercos);
    % B_corte1; B_corte2 (energia); fim; reserva
    cortes{w} = dlmread(fullfile(pasta_trechos, ['cortes_' palavras{w} '.csv']), ';', 1, 0);
end

%% 3. Uma linha de X para cada janela
for m = 1:numel(metodos)
  for nb = lista_bandas
    for ic = 1:numel(contextos)
        contexto = contextos{ic};
        X = []; y = []; conj = []; arquivos = {};

        J  = round(janela * fs);               % amostras por janela
        Pp = round(passo  * fs);               % amostras por passo
        % Colunas dos cortes no CSV: 3 e 4 = tercos, 5 e 6 = energia
        if strcmp(metodos{m}, 'tercos'), col = [3 4]; else, col = [5 6]; end
        for w = 1:2
            xw = grav{w};  C = cortes{w};
            for k = 1:size(C, 1)
                num = C(k, 1);
                t_ini = C(k, 2);  t_fim = C(k, 7);   % limites da palavra (s)
                c1 = C(k, col(1));  c2 = C(k, col(2)); % fronteiras das silabas (s)
                % Centro de cada janela: do inicio ao fim da palavra, de 25 em 25 ms
                for ct = round(t_ini * fs) : Pp : round(t_fim * fs)
                    a = ct - floor(J/2);               % 1a amostra da janela
                    if a < 1 || a + J - 1 > numel(xw), continue; end
                    % Rotulo = silaba onde cai o centro da janela
                    t = ct / fs;
                    if t < c1, s = 1; elseif t < c2, s = 2; else, s = 3; end
                    X(end+1, :) = entrada('espectro', xw, a, J, Pp, contexto, fs, nb, f_min, f_max);
                    y(end+1, 1) = find(strcmp(classes, silabas{w}{s}));
                    conj(end+1, 1) = conj_grupo{w}(num);
                    arquivos{end+1, 1} = sprintf('%s_%03d.wav', silabas{w}{s}, num);
                end
            end
        end
        % Silencio: a mesma janela percorre cada trecho de silencio
        lista = dir(fullfile(pasta_trechos, 'energia', 'silencio', '*.wav'));
        for k = 1:numel(lista)
            nome = lista(k).name;
            num  = str2double(regexprep(nome, '^.*_(\d+)\.wav$', '$1'));
            [xs, fs] = audioread(fullfile(lista(k).folder, nome));
            xs = mean(xs, 2);
            for a = 1 : Pp : numel(xs) - J + 1
                X(end+1, :) = entrada('espectro', xs, a, J, Pp, contexto, fs, nb, f_min, f_max);
                y(end+1, 1) = numel(classes);
                conj(end+1, 1) = conj_grupo{3}(num);
                arquivos{end+1, 1} = nome;
            end
        end

        n_bandas = nb;
        suf = '';  if ~isequal(contexto, 0), suf = '_contexto'; end   % nome do arquivo
        arq = fullfile(pasta_entradas, sprintf('entradas_%s_%d%s.mat', metodos{m}, nb, suf));
        % '-v7' = formato de .mat que o MATLAB e o Octave leem do mesmo jeito
        save(arq, 'X', 'y', 'conj', 'arquivos', 'classes', 'f_min', 'f_max', ...
             'n_bandas', 'fs', 'modo', 'janela', 'passo', 'contexto', '-v7');
        fprintf('%-8s %2d faixas contexto [%s]: %d amostras (treino %d, teste %d, validacao %d)\n', ...
            metodos{m}, nb, num2str(contexto), numel(y), sum(conj == 1), sum(conj == 2), sum(conj == 3));
        fprintf('         amostras por classe: %s\n', num2str(accumarray(y, 1)'));
    end
  end
end

fprintf('\nEntradas salvas em: %s\n', pasta_entradas);
