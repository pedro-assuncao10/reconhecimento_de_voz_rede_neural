function rodar_projeto(modo)
    % RODAR_PROJETO  Confere se o MATLAB/Octave tem tudo o que o projeto usa
    % e roda o projeto.
    %
    % Uso (com esta pasta aberta no MATLAB ou no Octave):
    %   rodar_projeto            confere e roda o programa 2 com a rede ja
    %                            treinada (rede/resultados/modelo_final.mat),
    %                            cerca de 3 minutos. Se as palavras ainda nao
    %                            foram cortadas, roda a segmentacao antes
    %   rodar_projeto('tudo')    confere e refaz tudo do zero: segmentacao,
    %                            entradas da rede, treino e programa 2,
    %                            cerca de 10 minutos
    %   rodar_projeto('rbf')     o mesmo que o primeiro, com a rede RBF
    %                            (rede_rbf/resultados/modelo_final.mat)
    %   rodar_projeto('rbf_tudo') o mesmo que 'tudo', com a rede RBF
    %
    % O projeto usa so funcoes basicas do MATLAB/Octave (audioread, fft,
    % movmean, ...), sem toolbox e sem pacote extra: nao e preciso baixar
    % nada. Este script so confirma isso antes de comecar.

    if nargin < 1, modo = 'programa2'; end
    raiz = fileparts(mfilename('fullpath'));
    rbf  = strncmp(modo, 'rbf', 3);                       % rede RBF ou MLP
    tudo = any(strcmp(modo, {'tudo', 'rbf_tudo'}));       % refaz tudo do zero?

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
    precisa = {fullfile('segmentacao', 'audios', 'direita.flac'), ...
               fullfile('segmentacao', 'audios', 'esquerda.flac')};
    if ~tudo && rbf
        precisa{end+1} = fullfile('rede_rbf', 'resultados', 'modelo_final.mat');
    elseif ~tudo
        precisa{end+1} = fullfile('rede', 'resultados', 'modelo_final.mat');
    end
    for i = 1:numel(precisa)
        if ~exist(fullfile(raiz, precisa{i}), 'file')
            error('Arquivo nao encontrado: %s (rode com ''tudo'' ou ''rbf_tudo'')', precisa{i});
        end
    end
    fprintf('Arquivos de entrada: ok\n');

    %% 2. Roda
    % As palavras, silabas e silencios cortados (segmentacao/saida) sao
    % gerados pela segmentacao. Sem eles, ela roda antes do programa 2.
    ja_cortado = exist(fullfile(raiz, 'segmentacao', 'saida', 'palavras', 'direita_001.wav'), 'file');
    if tudo || ~ja_cortado
        executar('segmentacao', 'segmentar_audios');   % palavras, silabas e silencios
    end
    if tudo
        executar('rede', 'extrair_entradas');          % vetores de entrada da rede
    end
    if tudo && rbf
        executar('rede_rbf', 'treinar_rbf');           % treino e teste da RBF
    elseif tudo
        executar('rede', 'treinar_mlp');               % treino e teste da MLP
    end
    if rbf
        executar('rede', 'programa2_reconhecer(''rbf'')');   % reconhecimento com a RBF
        pasta_res = 'rede_rbf/resultados/';
    else
        executar('rede', 'programa2_reconhecer');            % reconhecimento com a MLP
        pasta_res = 'rede/resultados/';
    end

    cd(fileparts(mfilename('fullpath')));
    fprintf('\nPronto. Resultados e figuras em %s\n', pasta_res);
end


function executar(pasta, script)
    % EXECUTAR  Roda um dos scripts do projeto dentro da pasta dele (onde
    % estao as funcoes que ele usa).
    fprintf('\n=== %s: %s ===\n', pasta, script);
    cd(fullfile(fileparts(mfilename('fullpath')), pasta));
    eval(script);
end
