function s = sufixo_contexto(contexto)
    % SUFIXO_CONTEXTO  Parte do nome do arquivo de entradas que indica o
    % contexto: '' = so a janela atual; '_contexto' = com janelas vizinhas.
    if isequal(contexto, 0), s = ''; else, s = '_contexto'; end
end
