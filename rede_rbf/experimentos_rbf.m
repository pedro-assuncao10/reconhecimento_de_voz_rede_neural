function experimentos_rbf(acao, varargin)
    % EXPERIMENTOS_RBF  Testes para escolher, com dados, cada parametro da
    % rede RBF, com o mesmo esquema usado na MLP: uma coisa varia por etapa,
    % e o vencedor de cada etapa segue para a proxima.
    %
    % Usa as mesmas janelas e o mesmo reconhecedor de palavras da MLP, com a
    % divisao pedida no enunciado da RBF: treino 75%, validacao 15% e teste
    % 10% (rbf('dividir'), gravada em divisao_rbf.csv).
    %
    % Uso:
    %   experimentos_rbf('etapa', N)                    etapa N (1 a 6), 5 sementes
    %   experimentos_rbf('etapa', N, 'sementes', 1)     opcoes por nome
    %   experimentos_rbf('resumo', N)                   media e desvio da etapa N
    %   experimentos_rbf('validacao_cruzada')           5 partes, rede escolhida
    %   experimentos_rbf('resumo_validacao_cruzada')
    %
    % Etapas (na ordem do algoritmo da aula):
    %   1 - entrada: sem ou com contexto, 32 ou 64 faixas
    %   2 - normalizacao: max, db, zscore, minmax [0,1] e minmax [-1,1]
    %   3 - numero de neuronios escondidos: 25 a 800
    %   4 - como achar os centros: WTA com varias taxas, ou k-means
    %   5 - abertura: raio unico (varios k), metade da distancia, media dos T mais perto
    %   6 - pesos da saida: regra delta (saida linear ou sigmoide, varias
    %       taxas) ou cholesky. Nas etapas 1 a 5 a saida e o cholesky (ver
    %       referencia)
    %
    % Cada configuracao e treinada com 5 sementes e comparada pela media e
    % pelo desvio. Tudo e medido na validacao, com a tolerancia de 2 janelas
    % do programa 2; o teste fica para o resultado final (treinar_rbf.m).
    %
    % Regra de escolha (a mesma da MLP):
    %   1) mais palavras de validacao (media das sementes);
    %   2) se a diferenca for menor que o desvio, decidem as silabas, se a
    %      diferenca nelas for maior que o desvio;
    %   3) se empatar tambem, a opcao mais simples.

    pasta = fileparts(mfilename('fullpath'));
    switch acao
        case 'etapa',                    etapa(varargin{:});
        case 'resumo',                   resumo(varargin{:});
        case 'validacao_cruzada',        validacao_cruzada(varargin{:});
        case 'resumo_validacao_cruzada', resumo_validacao_cruzada();
        otherwise, error('experimentos_rbf: acao desconhecida: %s', acao);
    end
end


function o = opcoes(o, args)
    % OPCOES  Troca os valores padrao de 'o' pelos pares nome/valor de 'args'.
    for i = 1:2:numel(args)
        if ~isfield(o, args{i}), error('opcao desconhecida: %s', args{i}); end
        o.(args{i}) = args{i + 1};
    end
end


function r = referencia()
    % REFERENCIA  Configuracao usada enquanto um fator ainda nao foi testado;
    % depois de cada etapa, o valor dela passa a ser o vencedor.
    r.faixas = 32;
    r.contexto = [-4 -2 0 2 4];
    r.normalizacao = 'db';                         % etapa 2
    r.K = 200;                                     % etapa 3
    r.centros = 'wta';  r.eta_c = 0.05;
    r.largura = 'unica';  r.k = 0.5;  r.T = 2;      % etapa 5
    % Saida das etapas 1 a 5: cholesky (os pesos exatos de minimos
    % quadrados). Assim cada etapa compara so a camada escondida: a regra
    % delta diverge quando a taxa passa de 2 / (maior autovalor de
    % Phi'Phi/n), e esse limite muda com cada configuracao. A regra delta
    % da aula e escolhida na etapa 6.
    r.saida = 'cholesky';  r.ativ_saida = 'linear';  r.taxa = 0;
    r.momento = 0;  r.epocas = 1000;
end


function D = carregar(pasta, c)
    % CARREGAR  Entradas da combinacao de faixas e contexto, com a divisao
    % 75/15/10 da RBF.
    suf = '';  if ~isequal(c.contexto, 0), suf = '_contexto'; end
    D = load(fullfile(pasta, 'entradas', sprintf('entradas_energia_%d%s.mat', c.faixas, suf)));
    D = rbf('dividir', D);
end


function etapa(n_etapa, varargin)
    % ETAPA  Treina todas as configuracoes de uma etapa, para cada semente.
    % Saida: resultados/etapa<N>_semente<S>.csv (uma linha por rede)
    o.sementes = 1:5;
    o = opcoes(o, varargin);
    ref = referencia();

    % Cada configuracao e a referencia com um ou dois campos trocados
    confs = {};
    switch n_etapa
        case 1   % entrada
            for nb = [32 64]
                for ctx = {0, [-4 -2 0 2 4]}
                    c = ref;  c.faixas = nb;  c.contexto = ctx{1};  confs{end+1} = c;
                end
            end
        case 2   % normalizacao
            for nm = {'max', 'db', 'zscore', 'minmax', 'minmax11'}
                c = ref;  c.normalizacao = nm{1};  confs{end+1} = c;
            end
        case 3   % numero de neuronios escondidos
            for K = [25 50 100 200 400 800]
                c = ref;  c.K = K;  confs{end+1} = c;
            end
        case 4   % como achar os centros
            for eta = [0.01 0.05 0.1 0.3]
                c = ref;  c.centros = 'wta';  c.eta_c = eta;  confs{end+1} = c;
            end
            c = ref;  c.centros = 'kmeans';  c.eta_c = 0;  confs{end+1} = c;
        case 5   % abertura dos neuronios escondidos
            for k = [0.1 0.2 0.3 0.5 1]
                c = ref;  c.largura = 'unica';  c.k = k;  confs{end+1} = c;
            end
            c = ref;  c.largura = 'metade';  confs{end+1} = c;
            for T = [2 3 5]
                c = ref;  c.largura = 'media';  c.T = T;  confs{end+1} = c;
            end
        case 6   % pesos da camada de saida
            for tx = [0.005 0.01 0.02 0.05]
                c = ref;  c.saida = 'delta';  c.ativ_saida = 'linear';  c.taxa = tx;  confs{end+1} = c;
            end
            for tx = [0.05 0.1 0.2 0.5]
                c = ref;  c.saida = 'delta';  c.ativ_saida = 'sigmoide';  c.taxa = tx;  confs{end+1} = c;
            end
            c = ref;  c.saida = 'cholesky';  c.ativ_saida = 'linear';  c.taxa = 0;  confs{end+1} = c;
            % Com momento 0,9 (como na MLP) e ate 5000 epocas: a regra
            % delta sem momento ainda melhorava no limite de 1000 epocas
            for tx = [0.002 0.005 0.01 0.02]
                c = ref;  c.saida = 'delta';  c.ativ_saida = 'linear';  c.taxa = tx;
                c.momento = 0.9;  c.epocas = 5000;  confs{end+1} = c;
            end
            for tx = [0.02 0.05 0.1]
                c = ref;  c.saida = 'delta';  c.ativ_saida = 'sigmoide';  c.taxa = tx;
                c.momento = 0.9;  c.epocas = 5000;  confs{end+1} = c;
            end
        otherwise
            error('etapa deve ser de 1 a 6');
    end

    p_rec.n_conf = 1;  p_rec.max_silencio = 0.300;
    p_rec.max_fora = 2;                            % tolerancia de 2 janelas, como no programa 2

    pasta = fileparts(mfilename('fullpath'));
    pasta_palavras = fullfile(pasta, '..', 'segmentacao', 'saida', 'palavras');
    pasta_saida = fullfile(pasta, 'resultados');
    if ~exist(pasta_saida, 'dir'), mkdir(pasta_saida); end

    pal = [];
    for s = o.sementes
        fid = fopen(fullfile(pasta_saida, sprintf('etapa%d_semente%d.csv', n_etapa, s)), 'w');
        fprintf(fid, ['etapa;faixas;contexto;normalizacao;K;centros;eta_c;largura;k;T;saida;ativ_saida;taxa;momento;epocas;semente;' ...
                      'acerto_treino;acerto_validacao;silabas_validacao;di;rei;ta;es;quer;da;' ...
                      'palavras_validacao;epoca;tempo_s\n']);
        for i = 1:numel(confs)
            c = confs{i};
            D = carregar(pasta, c);
            if isempty(pal), [pal, fs_pal] = carregar_palavras(pasta_palavras, D); end
            r = avaliar(D, pal, fs_pal, c, p_rec, s);
            txt_ctx = 'nao';  if ~isequal(c.contexto, 0), txt_ctx = 'sim'; end
            fprintf(fid, '%d;%d;%s;%s;%d;%s;%g;%s;%g;%d;%s;%s;%g;%g;%d;%d;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%d;%.1f\n', ...
                n_etapa, c.faixas, txt_ctx, c.normalizacao, c.K, c.centros, c.eta_c, c.largura, c.k, c.T, ...
                c.saida, c.ativ_saida, c.taxa, c.momento, c.epocas, s, r.ac_tr, r.ac_va, r.ac_silabas, r.silabas, r.ac_palavras, ...
                r.epoca, r.tempo);
            fprintf('etapa %d semente %d | %s | silabas %5.1f%% | palavras %5.1f%% | %5.1f s\n', ...
                n_etapa, s, descricao(c), 100*r.ac_silabas, 100*r.ac_palavras, r.tempo);
        end
        fclose(fid);
    end
end


function txt = descricao(c)
    % DESCRICAO  Texto curto de uma configuracao (para a tela e o resumo).
    txt_ctx = 'nao';  if ~isequal(c.contexto, 0), txt_ctx = 'sim'; end
    switch c.largura
        case 'unica',  lg = sprintf('raio unico k=%g', c.k);
        case 'metade', lg = 'metade da dist.';
        otherwise,     lg = sprintf('media T=%d', c.T);
    end
    if strcmp(c.centros, 'wta'), ct = sprintf('WTA eta=%g', c.eta_c); else, ct = 'k-means'; end
    if strcmp(c.saida, 'cholesky'), sd = 'cholesky';
    else
        sd = sprintf('delta %s taxa=%g', c.ativ_saida, c.taxa);
        if c.momento > 0, sd = sprintf('%s momento=%g ate %d epocas', sd, c.momento, c.epocas); end
    end
    txt = sprintf('%d faixas ctx %s | %s | K=%d | %s | %s | %s', c.faixas, txt_ctx, c.normalizacao, ...
                  c.K, ct, lg, sd);
end


function r = avaliar(D, pal, fs_pal, c, p_rec, semente)
    % AVALIAR  Treina uma RBF e mede o desempenho dela so na validacao.
    rng(semente);
    tr = D.conj == 1;  va = D.conj == 3;
    [Xtr, stats] = entrada('normalizar', D.X(tr, :), c.normalizacao);
    Xva = entrada('normalizar', D.X(va, :), c.normalizacao, stats);

    tic;
    rede = rbf('treinar', Xtr, D.y(tr), numel(D.classes), c, Xva, D.y(va));
    r.tempo = toc;
    r.epoca = rede.epoca;

    r.ac_tr = mean(rbf('classificar', rede, Xtr) == D.y(tr));
    prev = rbf('classificar', rede, Xva);
    yv = D.y(va);
    r.ac_va = mean(prev == yv);
    r.silabas = arrayfun(@(k) mean(prev(yv == k) == k), 1:6);
    r.ac_silabas = mean(r.silabas);

    % Palavras inteiras de validacao pelo reconhecedor do programa 2
    m_tmp = struct('tipo', 'rbf', 'rede', rede, 'stats', stats, 'n_bandas', D.n_bandas, ...
        'normalizacao', c.normalizacao, 'classes', {D.classes}, 'f_min', D.f_min, ...
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


function [pal, fs_pal] = carregar_palavras(pasta_palavras, D)
    % CARREGAR_PALAVRAS  Le as palavras inteiras de validacao e de teste,
    % pela divisao que esta em D.conj.
    nomes_pal = {'direita', 'esquerda'};
    prim = {'di_', 'es_'};
    num_de = @(nome) str2double(regexprep(nome, '^.*_(\d+)\.wav$', '$1'));
    pal = struct('audio', {}, 'palavra', {}, 'conj', {});
    fs_pal = [];
    for w = 1:2
        sel = strncmp(D.arquivos, prim{w}, 3) & D.conj ~= 1;
        for num = unique(cellfun(num_de, D.arquivos(sel)))'
            [x, fs_pal] = audioread(fullfile(pasta_palavras, sprintf('%s_%03d.wav', nomes_pal{w}, num)));
            cj = D.conj(find(sel & strcmp(D.arquivos, sprintf('%s%03d.wav', prim{w}, num)), 1));
            pal(end+1) = struct('audio', mean(x, 2), 'palavra', nomes_pal{w}, 'conj', cj);
        end
    end
end


function resumo(n_etapa)
    % RESUMO  Junta os CSVs de uma etapa (todas as sementes) e mostra, para
    % cada configuracao, a media e o desvio entre as sementes, da melhor
    % para a pior (palavras; desempate: silabas).
    % Saida: resultados/resumo_etapa<N>.csv
    pasta_saida = fullfile(fileparts(mfilename('fullpath')), 'resultados');
    lista = dir(fullfile(pasta_saida, sprintf('etapa%d_semente*.csv', n_etapa)));
    chave = {};  M = [];
    for k = 1:numel(lista)
        fid = fopen(fullfile(pasta_saida, lista(k).name));  fgetl(fid);
        C = textscan(fid, ['%f %f %s %s %f %s %f %s %f %f %s %s %f %f %f %f' repmat(' %f', 1, 12)], 'Delimiter', ';');
        fclose(fid);
        for i = 1:numel(C{1})
            c = struct('faixas', C{2}(i), 'contexto', 0, 'normalizacao', C{4}{i}, 'K', C{5}(i), ...
                'centros', C{6}{i}, 'eta_c', C{7}(i), 'largura', C{8}{i}, 'k', C{9}(i), 'T', C{10}(i), ...
                'saida', C{11}{i}, 'ativ_saida', C{12}{i}, 'taxa', C{13}(i), 'momento', C{14}(i), 'epocas', C{15}(i));
            if strcmp(C{3}{i}, 'sim'), c.contexto = [-4 -2 0 2 4]; end
            chave{end+1, 1} = descricao(c);
            % colunas: silabas, di..da, palavras, janelas valid, treino, epoca, tempo
            M(end+1, :) = [C{19}(i), C{20}(i), C{21}(i), C{22}(i), C{23}(i), C{24}(i), C{25}(i), ...
                           C{26}(i), C{18}(i), C{17}(i), C{27}(i), C{28}(i)];
        end
    end
    [confs, ~, g] = unique(chave);
    nc = numel(confs);
    med = zeros(nc, size(M, 2));  dp = med;  n = zeros(nc, 1);
    for c = 1:nc
        med(c, :) = mean(M(g == c, :), 1);
        dp(c, :)  = std(M(g == c, :), 0, 1);
        n(c) = sum(g == c);
    end
    [~, ordem] = sortrows([med(:, 8), med(:, 1)], [-1 -2]);

    fprintf('\n=== ETAPA %d (RBF): media +- desvio entre sementes (validacao, tolerancia 2) ===\n', n_etapa);
    fid = fopen(fullfile(pasta_saida, sprintf('resumo_etapa%d.csv', n_etapa)), 'w');
    fprintf(fid, 'configuracao;palavras_media;palavras_desvio;silabas_media;silabas_desvio;janelas_media;di;rei;ta;es;quer;da;treino;epoca_media;tempo_medio_s;sementes\n');
    for c = ordem'
        fprintf('%-95s | palavras %5.1f +- %4.1f | silabas %5.1f +- %4.1f | janelas %5.1f | epoca %4.0f | %5.1f s\n', ...
            confs{c}, 100*med(c,8), 100*dp(c,8), 100*med(c,1), 100*dp(c,1), 100*med(c,9), med(c,11), med(c,12));
        fprintf(fid, '%s;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.0f;%.1f;%d\n', ...
            confs{c}, med(c,8), dp(c,8), med(c,1), dp(c,1), med(c,9), med(c,2:7), med(c,10), med(c,11), med(c,12), n(c));
    end
    fclose(fid);
end


function r = escolhida()
    % ESCOLHIDA  A rede escolhida no fim das 6 etapas: a referencia com a
    % saida vencedora da etapa 6 (regra delta, como pede o slide 13).
    r = referencia();
    r.saida = 'delta';  r.ativ_saida = 'sigmoide';  r.taxa = 0.1;
    r.momento = 0.9;  r.epocas = 5000;
end


function validacao_cruzada(varargin)
    % VALIDACAO_CRUZADA  A rede escolhida em 5 partes: as palavras que nao
    % sao de teste (divisao 75/15/10) sao divididas em 5 partes, e a rede e
    % treinada 5 vezes, cada vez validando numa parte. Mede as palavras com
    % tolerancia de 0 a 3 janelas.
    % Saida: resultados/validacao_cruzada/<variante>_parte<K>.csv
    o = escolhida();
    o.variante = 'rbf';
    o.partes = 1:5;
    o = opcoes(o, varargin);
    n_partes = 5;  lista_fora = [0 1 2 3];
    p_rec.n_conf = 1;  p_rec.max_silencio = 0.300;

    pasta = fileparts(mfilename('fullpath'));
    pasta_palavras = fullfile(pasta, '..', 'segmentacao', 'saida', 'palavras');
    pasta_saida = fullfile(pasta, 'resultados', 'validacao_cruzada');
    if ~exist(pasta_saida, 'dir'), [~] = mkdir(pasta_saida); end   % sem erro se outra parte criou antes
    D = carregar(pasta, o);

    % Sorteio das 5 partes (por repeticao, fora o teste)
    grupo = 1 + (D.y >= 4) + (D.y == 7);
    num = cellfun(@(a) str2double(regexprep(a, '^.*_(\d+)\.wav$', '$1')), D.arquivos);
    parte = zeros(size(D.y));
    rng(7);
    for g = 1:3
        reps = unique(num(grupo == g & D.conj ~= 2));
        reps = reps(randperm(numel(reps)));
        for i = 1:numel(reps)
            parte(grupo == g & num == reps(i)) = mod(i - 1, n_partes) + 1;
        end
    end
    nomes = {'direita', 'esquerda'};
    pal = struct('audio', {}, 'palavra', {}, 'parte', {});
    for w = 1:2
        for r = unique(num(grupo == w & parte > 0))'
            [x, fs_pal] = audioread(fullfile(pasta_palavras, sprintf('%s_%03d.wav', nomes{w}, r)));
            k = find(grupo == w & num == r, 1);
            pal(end+1) = struct('audio', mean(x, 2), 'palavra', nomes{w}, 'parte', parte(k));
        end
    end

    m_rec = struct('tipo', 'rbf', 'n_bandas', D.n_bandas, 'normalizacao', o.normalizacao, ...
        'classes', {D.classes}, 'f_min', D.f_min, 'f_max', D.f_max, 'contexto', D.contexto);
    p_rec.janela = D.janela;  p_rec.passo = D.passo;
    for k = o.partes
        tr = parte > 0 & parte ~= k;  va = parte == k;
        [Xtr, stats] = entrada('normalizar', D.X(tr, :), o.normalizacao);
        Xva = entrada('normalizar', D.X(va, :), o.normalizacao, stats);
        rng(1);
        rede = rbf('treinar', Xtr, D.y(tr), numel(D.classes), o, Xva, D.y(va));
        prev = rbf('classificar', rede, Xva);  yv = D.y(va);
        silabas = arrayfun(@(c) mean(prev(yv == c) == c), 1:6);
        janelas = mean(prev == yv);

        m_rec.rede = rede;  m_rec.stats = stats;
        iv = find([pal.parte] == k);
        certas = zeros(1, numel(lista_fora));
        for j = 1:numel(lista_fora)
            p_rec.max_fora = lista_fora(j);
            for i = iv
                r = reconhecer_palavra(pal(i).audio, fs_pal, m_rec, p_rec);
                certas(j) = certas(j) + (~isempty(r) && strcmp(r(1).palavra, pal(i).palavra));
            end
        end
        fid = fopen(fullfile(pasta_saida, sprintf('%s_parte%d.csv', o.variante, k)), 'w');
        fprintf(fid, 'variante;parte;max_fora;palavras;certas;silabas;di;rei;ta;es;quer;da;janelas\n');
        for j = 1:numel(lista_fora)
            fprintf(fid, '%s;%d;%d;%d;%d;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f\n', o.variante, k, ...
                lista_fora(j), numel(iv), certas(j), mean(silabas), silabas, janelas);
        end
        fclose(fid);
        fprintf('%s parte %d | silabas %.1f%% | palavras %s de %d (tolerancia 0..3)\n', ...
            o.variante, k, 100 * mean(silabas), mat2str(certas), numel(iv));
    end
end


function resumo_validacao_cruzada()
    % RESUMO_VALIDACAO_CRUZADA  Junta as 5 partes de cada variante.
    pasta_saida = fullfile(fileparts(mfilename('fullpath')), 'resultados', 'validacao_cruzada');
    lista = dir(fullfile(pasta_saida, '*_parte*.csv'));
    nomes = {};  L = [];
    for k = 1:numel(lista)
        fid = fopen(fullfile(pasta_saida, lista(k).name));  fgetl(fid);
        C = textscan(fid, '%s %f %f %f %f %f %f %f %f %f %f %f %f', 'Delimiter', ';');
        fclose(fid);
        for i = 1:numel(C{1})
            [tf, iv] = ismember(C{1}{i}, nomes);
            if ~tf, nomes{end+1} = C{1}{i}; iv = numel(nomes); end
            L(end+1, :) = [iv, C{2}(i), C{3}(i), C{4}(i), C{5}(i), C{6}(i), C{7}(i), C{8}(i), ...
                           C{9}(i), C{10}(i), C{11}(i), C{12}(i), C{13}(i)];
        end
    end
    fid = fopen(fullfile(pasta_saida, 'resumo.csv'), 'w');
    fprintf(fid, 'variante;tolerancia;partes;palavras;certas;acerto_palavras;silabas;di;rei;ta;es;quer;da;janelas\n');
    fprintf('\n=== VALIDACAO CRUZADA (RBF) ===\n');
    for v = 1:numel(nomes)
        for f = unique(L(L(:,1) == v, 3))'
            S = L(L(:,1) == v & L(:,3) == f, :);
            tot = sum(S(:,5));  n = sum(S(:,4));
            fprintf('%-20s | tol %d | %3d/%3d = %5.1f%% | silabas %5.1f%% | %s\n', nomes{v}, f, tot, n, ...
                100*tot/n, 100*mean(S(:,6)), sprintf('%3.0f ', 100*mean(S(:,7:12), 1)));
            fprintf(fid, '%s;%d;%d;%d;%d;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f\n', nomes{v}, f, ...
                size(S,1), n, tot, tot/n, mean(S(:,6)), mean(S(:,7:12), 1), mean(S(:,13)));
        end
    end
    fclose(fid);
end
