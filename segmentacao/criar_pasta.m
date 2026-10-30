function criar_pasta(p)
    % CRIAR_PASTA  Cria a pasta p (e as pastas acima dela) se ainda nao existir.
    %   Usada por segmentar_audios.m para montar a estrutura de saida.
    if ~exist(p, 'dir')
        mkdir(p);
    end
end
