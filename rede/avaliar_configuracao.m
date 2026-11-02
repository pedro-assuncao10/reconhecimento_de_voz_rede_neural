function r = avaliar_configuracao(D, pal, fs_pal, ocultas, ativacao, p, p_rec, semente, normalizacao)
    % AVALIAR_CONFIGURACAO  Treina UMA rede e mede o desempenho dela SO na
    % VALIDACAO (usada por escolher_arquitetura.m).
    %
    %   O conjunto de TESTE nao e tocado aqui: ele fica guardado para a
    %   nota final da rede escolhida (treinar_mlp.m), para que nenhuma
    %   escolha seja feita olhando o teste.
    %
    % Entradas:
    %   D        - conteudo de um arquivo entradas_*.mat
    %   pal      - palavras inteiras (carregar_palavras.m); usa as de validacao
    %   fs_pal   - taxa de amostragem das palavras
    %   ocultas  - neuronios por camada oculta, ex.: [64 32]
    %   ativacao - 'sigmoide' ou 'relu' (camadas ocultas)
    %   p        - parametros do treino (p.taxa, p.momento, ...; mlp_treinar)
    %   p_rec    - parametros do reconhecedor (reconhecer_palavra)
    %   semente  - semente do sorteio dos pesos iniciais e da ordem das
    %              amostras. Treinar a mesma configuracao com sementes
    %              diferentes mostra quanto do resultado e "sorte".
    %   normalizacao - 'max', 'db' ou 'zscore' (normalizar.m); padrao 'db'
    % Saida (r):
    %   ac_tr, ac_va - acerto por janela no treino e na validacao
    %   silabas      - acerto de cada silaba na validacao (1 x 6)
    %   ac_silabas   - media do acerto das 6 silabas na validacao
    %   ac_palavras  - fracao das palavras de validacao reconhecidas
    %   epoca, tempo - melhor epoca e tempo de treino (s)

    if nargin < 9, normalizacao = 'db'; end
    rng(semente);
    n_classes = numel(D.classes);
    Y = zeros(numel(D.y), n_classes);
    Y(sub2ind(size(Y), (1:numel(D.y))', D.y)) = 1;
    tr = D.conj == 1;  va = D.conj == 3;

    [Xtr, stats] = normalizar(D.X(tr, :), normalizacao);
    Xva = normalizar(D.X(va, :), normalizacao, stats);

    rede = mlp_criar(size(D.X, 2), ocultas, n_classes, ativacao);
    tic;
    [rede, hist] = mlp_treinar(rede, Xtr, Y(tr, :), Xva, Y(va, :), p);
    r.tempo = toc;
    r.epoca = hist.melhor_epoca;

    r.ac_tr = mean(mlp_classificar(rede, Xtr) == D.y(tr));
    prev = mlp_classificar(rede, Xva);
    yv = D.y(va);
    r.ac_va = mean(prev == yv);
    r.silabas = arrayfun(@(c) mean(prev(yv == c) == c), 1:6);
    r.ac_silabas = mean(r.silabas);

    % Palavras inteiras de validacao pelo reconhecedor do programa 2
    m_tmp = struct('rede', rede, 'stats', stats, 'n_bandas', D.n_bandas, ...
        'normalizacao', normalizacao, 'classes', {D.classes}, 'f_min', D.f_min, ...
        'f_max', D.f_max, 'contexto', D.contexto);
    p_rec.janela = D.janela;  p_rec.passo = D.passo;
    iv = find([pal.conj] == 3);
    certa = false(1, numel(iv));
    for i = 1:numel(iv)
        rr = reconhecer_palavra(pal(iv(i)).audio, fs_pal, m_tmp, p_rec);
        certa(i) = ~isempty(rr) && strcmp(rr(1).palavra, pal(iv(i)).palavra);
    end
    r.ac_palavras = mean(certa);
end
