function [pal, fs_pal] = carregar_palavras(pasta_palavras, D)
    % CARREGAR_PALAVRAS  Le as palavras INTEIRAS de validacao e de teste,
    % para medir o reconhecimento de palavras (programa 2).
    %
    %   A divisao em treino/teste/validacao e por repeticao da palavra e
    %   vem do arquivo de entradas (extrair_entradas.m): uma repeticao e de
    %   validacao/teste se a sua 1a silaba (di_/es_) estiver nesse conjunto.
    %   (No modo janelas ha uma entrada por janela, por isso o unique.)
    %
    % Entradas:
    %   pasta_palavras - pasta segmentacao/saida/palavras
    %   D              - conteudo de um arquivo entradas_*.mat
    % Saidas:
    %   pal    - struct array, uma por palavra: .audio, .palavra, .conj
    %            (conj: 2 = teste, 3 = validacao)
    %   fs_pal - taxa de amostragem dos audios

    nomes_pal = {'direita', 'esquerda'};
    prim = {'di_', 'es_'};                       % 1a silaba de cada palavra
    num_de = @(nome) str2double(regexprep(nome, '^.*_(\d+)\.wav$', '$1'));
    pal = struct('audio', {}, 'palavra', {}, 'conj', {});
    fs_pal = [];
    for w = 1:2
        sel = strncmp(D.arquivos, prim{w}, 3) & D.conj ~= 1;
        nums = unique(cellfun(num_de, D.arquivos(sel)));
        for num = nums(:)'
            [x, fs_pal] = audioread(fullfile(pasta_palavras, sprintf('%s_%03d.wav', nomes_pal{w}, num)));
            cj = D.conj(find(sel & strcmp(D.arquivos, sprintf('%s%03d.wav', prim{w}, num)), 1));
            pal(end+1) = struct('audio', mean(x, 2), 'palavra', nomes_pal{w}, 'conj', cj); %#ok<AGROW>
        end
    end
end
