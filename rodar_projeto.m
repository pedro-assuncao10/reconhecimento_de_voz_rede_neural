function rodar_projeto(modo)
    % RODAR_PROJETO  Confere se o MATLAB/Octave tem tudo o que o projeto usa
    % e roda o projeto.
    %
    % Uso (com esta pasta aberta no MATLAB ou no Octave):
    %   rodar_projeto            confere e roda o programa 2 com a rede ja
    %                            treinada (rede/resultados/modelo_final.mat),
    %                            cerca de 1 minuto
    %   rodar_projeto('tudo')    confere e refaz tudo do zero: segmentacao,
    %                            entradas da rede, treino e programa 2,
    %                            cerca de 10 minutos
    %
    % O projeto usa so funcoes basicas do MATLAB/Octave (audioread, fft,
    % movmean, ...), sem toolbox e sem pacote extra: nao e preciso baixar
    % nada. Este script so confirma isso antes de comecar.

    if nargin < 1, modo = 'programa2'; end
    raiz = fileparts(mfilename('fullpath'));

    %% 1. Confere o ambiente
    fprintf('=== Conferindo o ambiente ===\n');
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('GNU Octave %s\n', OCTAVE_VERSION);
        if compare_versions(OCTAVE_VERSION, '6.0.0', '<')
            error('E preciso o Octave 6 ou mais novo (https://octave.org/download).');
        end
    else
        fprintf('MATLAB %s\n', version);
        if verLessThan('matlab', '9.1')
            error('E preciso o MATLAB R2016b ou mais novo.');
        end
    end

    % Funcoes prontas que o projeto usa (todas do MATLAB/Octave basico)
    funcoes = {'audioread', 'audiowrite', 'fft', 'movmean', 'rng', 'randperm', ...
               'textscan', 'dlmread', 'strjoin', 'regexprep', 'accumarray', 'saveas'};
    faltando = funcoes(cellfun(@(f) ~exist(f), funcoes));
    if ~isempty(faltando)
        error('Funcoes que faltam nesta instalacao: %s', strjoin(faltando, ', '));
    end
    fprintf('Funcoes usadas pelo projeto: todas disponiveis (%d)\n', numel(funcoes));
    fprintf('Toolboxes / pacotes extras: nenhum e necessario\n');

    % Arquivos de entrada
    precisa = {fullfile('segmentacao', 'audios_wav', 'direita.wav'), ...
               fullfile('segmentacao', 'audios_wav', 'esquerda.wav')};
    if ~strcmp(modo, 'tudo')
        precisa{end+1} = fullfile('rede', 'resultados', 'modelo_final.mat');
        precisa{end+1} = fullfile('segmentacao', 'saida', 'palavras', 'direita_001.wav');
    end
    for i = 1:numel(precisa)
        if ~exist(fullfile(raiz, precisa{i}), 'file')
            error('Arquivo nao encontrado: %s (rode rodar_projeto(''tudo''))', precisa{i});
        end
    end
    fprintf('Arquivos de entrada: ok\n');

    %% 2. Roda
    if strcmp(modo, 'tudo')
        executar('segmentacao', 'segmentar_audios');   % palavras, silabas e silencios
        executar('rede', 'extrair_entradas');          % vetores de entrada da rede
        executar('rede', 'treinar_mlp');               % treino e teste da rede
    end
    executar('rede', 'programa2_reconhecer');          % reconhecimento das palavras

    cd(fileparts(mfilename('fullpath')));
    fprintf('\nPronto. Resultados e figuras em rede/resultados/\n');
end


function executar(pasta, script)
    % EXECUTAR  Roda um dos scripts do projeto dentro da pasta dele (onde
    % estao as funcoes que ele usa).
    fprintf('\n=== %s/%s.m ===\n', pasta, script);
    cd(fullfile(fileparts(mfilename('fullpath')), pasta));
    eval(script);
end
