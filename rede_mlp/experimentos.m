function experimentos(acao, varargin)
    % EXPERIMENTOS  Testes usados para escolher, com dados, cada parametro da
    % rede antes do treino final (treinar_mlp.m). Tabelas e conclusoes em
    % resultados/RELATORIO.md.
    %
    % Uso:
    %   experimentos('etapa', N)                    etapa N (1 a 4), 5 sementes
    %   experimentos('etapa', N, 'sementes', 1:2)   opcoes por nome (ver abaixo)
    %   experimentos('resumo', N)                   media e desvio da etapa N
    %   experimentos('validacao_cruzada')           5 partes, rede escolhida
    %   experimentos('validacao_cruzada', 'variante', 'energia_sem_contexto', ...
    %                'arq_entradas', 'entradas_energia_32.mat')
    %   experimentos('resumo_validacao_cruzada')
    %
    % Exemplo, rodando as sementes em paralelo (um terminal por semente):
    %   octave --eval "experimentos('etapa', 1, 'sementes', 1)"
    %
    % Etapas (cada uma usa o que as anteriores escolheram; ver a funcao etapa):
    %   1 - entrada: sem ou com contexto, 32 ou 64 faixas
    %   2 - normalizacao: max, db ou zscore
    %   3 - camadas ocultas: de [32] a [256 128 64 32], todas em funil
    %   4 - ATIVACAO + TAXA DE APRENDIZADO: sigmoide x ReLU, 4 taxas cada
    %
    % Cada configuracao e treinada com 5 sementes (pesos iniciais e ordem das
    % amostras sorteados de outro jeito) e comparada pela media e pelo desvio
    % entre elas. Tudo e medido na validacao; o teste fica guardado para o
    % resultado final, em treinar_mlp.m.
    %
    % Regra de escolha:
    %   1) vence quem reconhece mais palavras de validacao (media das sementes);
    %   2) se a diferenca for menor que o desvio (empate), decidem as silabas,
    %      se a diferenca nelas for maior que o desvio;
    %   3) se empatar tambem nas silabas, vence a opcao mais simples.

    switch acao
        case 'etapa',                    etapa(varargin{:});
        case 'resumo',                   resumo(varargin{:});
        case 'validacao_cruzada',        validacao_cruzada(varargin{:});
        case 'resumo_validacao_cruzada', resumo_validacao_cruzada();
        otherwise, error('experimentos: acao desconhecida: %s', acao);
    end
end


function o = opcoes(o, args)
    % OPCOES  Troca os valores padrao de 'o' pelos pares nome/valor de 'args'.
    for i = 1:2:numel(args)
        if ~isfield(o, args{i}), error('opcao desconhecida: %s', args{i}); end
        o.(args{i}) = args{i + 1};
    end
end


function etapa(n_etapa, varargin)
    % ETAPA  Treina todas as configuracoes de uma etapa, para cada semente.
    % Saida: resultados/escolha_<metodo>/etapa<N>_semente<S>.csv (uma linha por rede)

    % Opcoes. Os valores "escolhidos" sao os vencedores das etapas anteriores.
    o.metodo = 'energia';                  % corte das silabas: 'energia' ou 'tercos'
    o.sementes = 1:5;
    o.faixas_escolhidas = 32;              % etapa 1
    o.contexto_escolhido = [-4 -2 0 2 4];  % etapa 1
    o.normalizacao_escolhida = 'max';      % etapa 2
    o.ocultas_escolhidas = [64 32];        % etapa 3
    o = opcoes(o, varargin);

    % Valores de referencia, usados enquanto um fator ainda nao foi testado
    ref_ocultas = [64];  ref_ativacao = 'sigmoide';  ref_taxa = 0.5;

    switch n_etapa
        case 1   % entrada
            lista_faixas    = {32, 64};
            lista_contextos = {[0], [-4 -2 0 2 4]};
            lista_norm      = {'db'};
            lista_ocultas   = {ref_ocultas};
            lista_ativ_taxa = {{ref_ativacao, ref_taxa}};
        case 2   % normalizacao
            lista_faixas    = {o.faixas_escolhidas};
            lista_contextos = {o.contexto_escolhido};
            lista_norm      = {'max', 'db', 'zscore'};
            lista_ocultas   = {ref_ocultas};
            lista_ativ_taxa = {{ref_ativacao, ref_taxa}};
        case 3   % camadas ocultas (em funil: cada camada com metade da anterior)
            lista_faixas    = {o.faixas_escolhidas};
            lista_contextos = {o.contexto_escolhido};
            lista_norm      = {o.normalizacao_escolhida};
            lista_ocultas   = {[32], [64], [128], [64 32], [128 64], ...
                               [128 64 32], [256 128 64 32]};
            lista_ativ_taxa = {{ref_ativacao, ref_taxa}};
        case 4   % ativacao e taxa de aprendizado
            lista_faixas    = {o.faixas_escolhidas};
            lista_contextos = {o.contexto_escolhido};
            lista_norm      = {o.normalizacao_escolhida};
            lista_ocultas   = {o.ocultas_escolhidas};
            lista_ativ_taxa = {{'sigmoide', 0.1}, {'sigmoide', 0.3}, {'sigmoide', 0.5}, {'sigmoide', 1.0}, ...
                               {'relu', 0.003},   {'relu', 0.01},    {'relu', 0.03},    {'relu', 0.1}};
        otherwise
            error('etapa deve ser de 1 a 4');
    end

    % Parametros do treino (os mesmos de treinar_mlp.m)
    p.momento    = 0.9;
    p.epocas_max = 800;
    p.tam_lote   = 32;
    p.paciencia  = 200;
    p_rec.n_conf       = 1;
    p_rec.max_silencio = 0.300;
    p_rec.max_fora     = 0;      % as etapas foram medidas sem tolerancia

    pasta_script   = fileparts(mfilename('fullpath'));
    pasta_entradas = fullfile(pasta_script, 'entradas');
    pasta_saida    = fullfile(pasta_script, 'resultados', ['escolha_' o.metodo]);
    pasta_palavras = fullfile(pasta_script, '..', 'segmentacao', 'saida', 'palavras');
    if ~exist(pasta_saida, 'dir'), mkdir(pasta_saida); end

    pal = [];
    for s = o.sementes
        arq = fullfile(pasta_saida, sprintf('etapa%d_semente%d.csv', n_etapa, s));
        fid = fopen(arq, 'w');
        fprintf(fid, ['etapa;faixas;contexto;normalizacao;ocultas;ativacao;taxa;semente;acerto_treino;' ...
                      'acerto_validacao;silabas_validacao;di;rei;ta;es;quer;da;' ...
                      'palavras_validacao;melhor_epoca;tempo_s\n']);
        for i_f = 1:numel(lista_faixas)
         for i_c = 1:numel(lista_contextos)
            nb = lista_faixas{i_f};  ctx = lista_contextos{i_c};
            suf = '';  if ~isequal(ctx, 0), suf = '_contexto'; end
            D = load(fullfile(pasta_entradas, sprintf('entradas_%s_%d%s.mat', o.metodo, nb, suf)));
            if isempty(pal), [pal, fs_pal] = carregar_palavras(pasta_palavras, D); end
            txt_ctx = 'nao';  if ~isequal(ctx, 0), txt_ctx = 'sim'; end
            for i_n = 1:numel(lista_norm)
             for i_o = 1:numel(lista_ocultas)
              for i_a = 1:numel(lista_ativ_taxa)
                nm = lista_norm{i_n};  oc = lista_ocultas{i_o};
                at = lista_ativ_taxa{i_a}{1};  p.taxa = lista_ativ_taxa{i_a}{2};
                r = avaliar_configuracao(D, pal, fs_pal, oc, at, p, p_rec, s, nm);
                txt_oc = strjoin(arrayfun(@num2str, oc, 'UniformOutput', false), '-');
                fprintf(fid, '%d;%d;%s;%s;%s;%s;%g;%d;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%d;%.1f\n', ...
                    n_etapa, nb, txt_ctx, nm, txt_oc, at, p.taxa, s, r.ac_tr, r.ac_va, r.ac_silabas, ...
                    r.silabas, r.ac_palavras, r.epoca, r.tempo);
                fprintf('etapa %d semente %d | %2d faixas ctx %-3s %-6s oculta %-14s %-8s taxa %-5g | silabas valid %5.1f%% | palavras valid %5.1f%% | epoca %3d | %5.1f s\n', ...
                    n_etapa, s, nb, txt_ctx, nm, txt_oc, at, p.taxa, 100*r.ac_silabas, 100*r.ac_palavras, r.epoca, r.tempo);
              end
             end
            end
         end
        end
        fclose(fid);
    end
end


function r = avaliar_configuracao(D, pal, fs_pal, ocultas, ativacao, p, p_rec, semente, normalizacao)
    % AVALIAR_CONFIGURACAO  Treina uma rede e mede o desempenho dela so na
    % validacao. O conjunto de teste nao e usado aqui.
    %
    % Entradas:
    %   D        - conteudo de um arquivo entradas_*.mat
    %   pal      - palavras inteiras (carregar_palavras); usa as de validacao
    %   fs_pal   - taxa de amostragem das palavras
    %   ocultas  - neuronios por camada oculta, ex.: [64 32]
    %   ativacao - 'sigmoide' ou 'relu' (camadas ocultas)
    %   p        - parametros do treino (p.taxa, p.momento, ...; ver mlp.m)
    %   p_rec    - parametros do reconhecedor (reconhecer_palavra)
    %   semente  - semente do sorteio dos pesos iniciais e da ordem das
    %              amostras. Treinar a mesma configuracao com sementes
    %              diferentes mostra quanto do resultado e "sorte".
    %   normalizacao - 'max', 'db' ou 'zscore' (entrada.m)
    % Saida (r):
    %   ac_tr, ac_va - acerto por janela no treino e na validacao
    %   silabas      - acerto de cada silaba na validacao (1 x 6)
    %   ac_silabas   - media do acerto das 6 silabas na validacao
    %   ac_palavras  - fracao das palavras de validacao reconhecidas
    %   epoca, tempo - melhor epoca e tempo de treino (s)

    rng(semente);
    n_classes = numel(D.classes);
    Y = zeros(numel(D.y), n_classes);
    Y(sub2ind(size(Y), (1:numel(D.y))', D.y)) = 1;
    tr = D.conj == 1;  va = D.conj == 3;

    [Xtr, stats] = entrada('normalizar', D.X(tr, :), normalizacao);
    Xva = entrada('normalizar', D.X(va, :), normalizacao, stats);

    rede = mlp('criar', size(D.X, 2), ocultas, n_classes, ativacao);
    tic;
    [rede, hist] = mlp('treinar', rede, Xtr, Y(tr, :), Xva, Y(va, :), p);
    r.tempo = toc;
    r.epoca = hist.melhor_epoca;

    r.ac_tr = mean(mlp('classificar', rede, Xtr) == D.y(tr));
    prev = mlp('classificar', rede, Xva);
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


function [pal, fs_pal] = carregar_palavras(pasta_palavras, D)
    % CARREGAR_PALAVRAS  Le as palavras inteiras de validacao e de teste.
    %   Uma repeticao e de validacao/teste se a sua 1a silaba (di_/es_)
    %   estiver nesse conjunto no arquivo de entradas (extrair_entradas.m).
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
            pal(end+1) = struct('audio', mean(x, 2), 'palavra', nomes_pal{w}, 'conj', cj);
        end
    end
end


function resumo(n_etapa, metodo)
    % RESUMO  Junta os CSVs de uma etapa (todas as sementes) e mostra, para
    % cada configuracao, a media e o desvio padrao entre as sementes, da
    % melhor para a pior pela regra de escolha (palavras; desempate: silabas).
    % Saidas: resultados/escolha_<metodo>/resumo_etapa<N>.csv e .png

    if nargin < 2, metodo = 'energia'; end
    pasta_script = fileparts(mfilename('fullpath'));
    pasta_saida  = fullfile(pasta_script, 'resultados', ['escolha_' metodo]);

    % Le todos os CSVs desta etapa (um por semente)
    lista = dir(fullfile(pasta_saida, sprintf('etapa%d_semente*.csv', n_etapa)));
    chave = {};  M = [];      % chave da configuracao e numeros de cada linha
    for k = 1:numel(lista)
        fid = fopen(fullfile(pasta_saida, lista(k).name));
        fgetl(fid);                                          % cabecalho
        C = textscan(fid, '%f %f %s %s %s %s %f %f %f %f %f %f %f %f %f %f %f %f %f %f', ...
                     'Delimiter', ';');
        fclose(fid);
        for i = 1:numel(C{1})
            chave{end+1, 1} = sprintf('%2d faixas | ctx %-3s | %-6s | oculta %-14s | %-8s | taxa %g', ...
                C{2}(i), C{3}{i}, C{4}{i}, C{5}{i}, C{6}{i}, C{7}(i));
            % colunas: silabas, di..da, palavras, janelas valid, treino, epoca, tempo
            M(end+1, :) = [C{11}(i), C{12}(i), C{13}(i), C{14}(i), C{15}(i), C{16}(i), ...
                           C{17}(i), C{18}(i), C{10}(i), C{9}(i), C{19}(i), C{20}(i)];
        end
    end

    [confs, ~, g] = unique(chave);         % (a ordem final vem do sortrows abaixo)
    nc = numel(confs);
    med = zeros(nc, size(M, 2));  dp = med;  n = zeros(nc, 1);
    for c = 1:nc
        med(c, :) = mean(M(g == c, :), 1);
        dp(c, :)  = std(M(g == c, :), 0, 1);
        n(c) = sum(g == c);
    end
    % Regra de escolha: mais palavras; desempate: mais silabas
    [~, ordem] = sortrows([med(:, 8), med(:, 1)], [-1 -2]);

    fprintf('\n=== ETAPA %d: media +- desvio entre sementes (VALIDACAO) ===\n', n_etapa);
    fprintf('%-71s | %-13s | %-13s | %-13s | %4s %4s %4s %4s %4s %4s | %-9s | sementes\n', ...
        'configuracao', 'palavras', 'silabas', 'janelas', 'di', 'rei', 'ta', 'es', 'quer', 'da', 'epoca');
    fid = fopen(fullfile(pasta_saida, sprintf('resumo_etapa%d.csv', n_etapa)), 'w');
    fprintf(fid, 'configuracao;silabas_media;silabas_desvio;palavras_media;palavras_desvio;janelas_media;janelas_desvio;di;rei;ta;es;quer;da;treino;epoca_media;tempo_medio_s;sementes\n');
    for c = ordem'
        fprintf('%-71s | %5.1f +- %4.1f | %5.1f +- %4.1f | %5.1f +- %4.1f | %4.0f %4.0f %4.0f %4.0f %4.0f %4.0f | %4.0f      | %d\n', ...
            confs{c}, 100*med(c,8), 100*dp(c,8), 100*med(c,1), 100*dp(c,1), 100*med(c,9), 100*dp(c,9), ...
            100*med(c,2:7), med(c,11), n(c));
        fprintf(fid, '%s;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.1f;%.1f;%d\n', ...
            strtrim(confs{c}), med(c,1), dp(c,1), med(c,8), dp(c,8), med(c,9), dp(c,9), ...
            med(c,2:7), med(c,10), med(c,11), med(c,12), n(c));
    end
    fclose(fid);

    % Grafico: dois paineis (palavras e silabas). Barra = media entre as
    % sementes; traco preto = +- 1 desvio padrao. Da melhor para a pior.
    fig = figure('Visible', 'off', 'Position', [0 0 1600 250 + 45 * nc]);
    cols   = [8, 1];
    nomes  = {'palavras de VALIDACAO reconhecidas (%)', 'acerto medio das 6 silabas na VALIDACAO (%)'};
    cores  = {[0.85 0.55 0.3], [0.4 0.6 0.85]};
    ax = zeros(1, 2);
    for k = 1:2
        % posicao manual: margem larga a esquerda para o nome das configuracoes
        if k == 1, ax(k) = axes('Position', [0.30 0.12 0.32 0.78]);
        else,      ax(k) = axes('Position', [0.66 0.12 0.30 0.78]); end
        cl = cols(k);
        barh(1:nc, 100 * med(ordem, cl), 0.6, 'FaceColor', cores{k}); hold on;
        for i = 1:nc
            c = ordem(i);
            plot(100 * (med(c,cl) + [-1 1] * dp(c,cl)), [i i], 'k-', 'LineWidth', 1.5);
            text(100 * (med(c,cl) + dp(c,cl)) + 0.5, i, sprintf('%.1f +- %.1f', 100*med(c,cl), 100*dp(c,cl)));
        end
        if k == 1
            set(gca, 'YTick', 1:nc, 'YTickLabel', strtrim(confs(ordem)), 'YDir', 'reverse');
        else
            set(gca, 'YTick', 1:nc, 'YTickLabel', {}, 'YDir', 'reverse');
        end
        lo = 100 * min(med(:,cl) - dp(:,cl));  hi = 100 * max(med(:,cl) + dp(:,cl));
        xlim([max(0, floor(lo) - 3), min(100, ceil(hi)) + 8]);  ylim([0.4, nc + 0.6]);
        xlabel(nomes{k});
    end
    title(ax(1), sprintf('Etapa %d - media de %d sementes (barra) e +- 1 desvio (traco); ordem: palavras, depois silabas', n_etapa, max(n)));
    saveas(fig, fullfile(pasta_saida, sprintf('resumo_etapa%d.png', n_etapa)));
    close(fig);
    fprintf('\nResumo salvo em: %s\n', pasta_saida);
end


function validacao_cruzada(varargin)
    % VALIDACAO_CRUZADA  Mede uma configuracao da rede em 5 partes.
    %
    %   Por que: com so 27 palavras de validacao, cada palavra vale 3,7
    %   pontos e o resultado depende muito de quais palavras cairam na
    %   validacao.
    %
    %   Como: as palavras de teste (conj = 2) ficam de fora. As outras
    %   repeticoes (112 palavras e os silencios) sao divididas em 5 partes,
    %   sorteadas por repeticao. A rede e treinada 5 vezes: em cada vez, uma
    %   parte e a validacao e as outras 4 sao o treino. No fim, toda palavra
    %   foi validacao uma vez.
    %
    %   Para cada parte, mede as silabas e as palavras, com a maquina de
    %   estados tolerando 0, 1, 2 ou 3 janelas fora da sequencia.
    %
    % Saida: resultados/validacao_cruzada/<variante>_parte<K>.csv

    o.variante     = 'energia';                         % nome nos resultados
    o.arq_entradas = 'entradas_energia_32_contexto.mat';
    o.normalizacao = 'max';
    o.ocultas      = [64 32];
    o.ativacao     = 'sigmoide';
    o.taxa         = 0.5;
    o.partes       = 1:5;
    o = opcoes(o, varargin);
    n_partes   = 5;
    lista_fora = [0 1 2 3];          % janelas fora da sequencia toleradas

    p.taxa = o.taxa;  p.momento = 0.9;  p.epocas_max = 800;
    p.tam_lote = 32;  p.paciencia = 200;
    p_rec.n_conf = 1;  p_rec.max_silencio = 0.300;

    pasta_script   = fileparts(mfilename('fullpath'));
    pasta_palavras = fullfile(pasta_script, '..', 'segmentacao', 'saida', 'palavras');
    pasta_saida    = fullfile(pasta_script, 'resultados', 'validacao_cruzada');
    if ~exist(pasta_saida, 'dir'), mkdir(pasta_saida); end

    D = load(fullfile(pasta_script, 'entradas', o.arq_entradas));
    n_classes = numel(D.classes);

    % Sorteio das 5 partes (por repeticao, fora o teste)
    % Grupo de cada amostra: 1 = direita (di/rei/ta), 2 = esquerda, 3 = silencio
    grupo = 1 + (D.y >= 4) + (D.y == 7);
    num = cellfun(@(a) str2double(regexprep(a, '^.*_(\d+)\.wav$', '$1')), D.arquivos);
    parte = zeros(size(D.y));        % 0 = teste (fica de fora)
    rng(7);                          % sorteio fixo das partes
    for g = 1:3
        reps = unique(num(grupo == g & D.conj ~= 2));
        reps = reps(randperm(numel(reps)));
        for i = 1:numel(reps)
            % distribui as repeticoes embaralhadas pelas 5 partes, em rodizio
            parte(grupo == g & num == reps(i)) = mod(i - 1, n_partes) + 1;
        end
    end

    % Palavras inteiras de treino + validacao, com a parte de cada uma
    nomes = {'direita', 'esquerda'};
    pal = struct('audio', {}, 'palavra', {}, 'parte', {});
    for w = 1:2
        for r = unique(num(grupo == w & parte > 0))'
            [x, fs_pal] = audioread(fullfile(pasta_palavras, sprintf('%s_%03d.wav', nomes{w}, r)));
            k = find(grupo == w & num == r, 1);
            pal(end+1) = struct('audio', mean(x, 2), 'palavra', nomes{w}, 'parte', parte(k));
        end
    end

    % Treina uma rede por parte
    Y = zeros(numel(D.y), n_classes);
    Y(sub2ind(size(Y), (1:numel(D.y))', D.y)) = 1;
    m_rec = struct('n_bandas', D.n_bandas, 'normalizacao', o.normalizacao, ...
        'classes', {D.classes}, 'f_min', D.f_min, 'f_max', D.f_max, 'contexto', D.contexto);
    p_rec.janela = D.janela;  p_rec.passo = D.passo;

    for k = o.partes
        tr = parte > 0 & parte ~= k;     % treino: as outras 4 partes
        va = parte == k;                 % validacao: esta parte
        [Xtr, stats] = entrada('normalizar', D.X(tr, :), o.normalizacao);
        Xva = entrada('normalizar', D.X(va, :), o.normalizacao, stats);

        rng(1);                          % mesma semente em todas as partes
        rede = mlp('criar', size(D.X, 2), o.ocultas, n_classes, o.ativacao);
        [rede, hist] = mlp('treinar', rede, Xtr, Y(tr, :), Xva, Y(va, :), p);

        prev = mlp('classificar', rede, Xva);  yv = D.y(va);
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
        fprintf(fid, 'variante;parte;max_fora;palavras;certas;silabas;di;rei;ta;es;quer;da;janelas;melhor_epoca\n');
        for j = 1:numel(lista_fora)
            fprintf(fid, '%s;%d;%d;%d;%d;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%d\n', o.variante, k, ...
                lista_fora(j), numel(iv), certas(j), mean(silabas), silabas, janelas, hist.melhor_epoca);
        end
        fclose(fid);
        fprintf('%s parte %d | silabas %.1f%% | palavras %s de %d (tolerancia 0..3) | epoca %d\n', ...
            o.variante, k, 100 * mean(silabas), mat2str(certas), numel(iv), hist.melhor_epoca);
    end
end


function resumo_validacao_cruzada()
    % RESUMO_VALIDACAO_CRUZADA  Junta as 5 partes de cada variante: acerto
    % nas palavras (somando as 5 partes = todas as 112 palavras) e acerto
    % medio das silabas (media das 5 partes).
    % Saida: resultados/validacao_cruzada/resumo.csv

    pasta_script = fileparts(mfilename('fullpath'));
    pasta_saida  = fullfile(pasta_script, 'resultados', 'validacao_cruzada');
    lista = dir(fullfile(pasta_saida, '*_parte*.csv'));

    nomes = {};  L = [];   % L: variante, parte, fora, palavras, certas, silabas, di..da, janelas
    for k = 1:numel(lista)
        fid = fopen(fullfile(pasta_saida, lista(k).name));  fgetl(fid);
        C = textscan(fid, '%s %f %f %f %f %f %f %f %f %f %f %f %f %f', 'Delimiter', ';');
        fclose(fid);
        for i = 1:numel(C{1})
            [tf, iv] = ismember(C{1}{i}, nomes);
            if ~tf, nomes{end+1} = C{1}{i}; iv = numel(nomes); end
            L(end+1, :) = [iv, C{2}(i), C{3}(i), C{4}(i), C{5}(i), C{6}(i), ...
                           C{7}(i), C{8}(i), C{9}(i), C{10}(i), C{11}(i), C{12}(i), C{13}(i)];
        end
    end

    fid = fopen(fullfile(pasta_saida, 'resumo.csv'), 'w');
    fprintf(fid, 'variante;tolerancia;partes;palavras;certas;acerto_palavras;desvio_entre_partes;silabas;di;rei;ta;es;quer;da;janelas\n');
    fprintf('\n=== VALIDACAO CRUZADA (5 partes, palavras fora do teste) ===\n');
    fprintf('%-22s | tol | partes | palavras certas   | por parte (%%)        | silabas | di  rei  ta  es  quer da\n', 'variante');
    for v = 1:numel(nomes)
        for f = unique(L(L(:,1) == v, 3))'
            S = L(L(:,1) == v & L(:,3) == f, :);
            ac_parte = S(:,5) ./ S(:,4);
            tot = sum(S(:,5));  n = sum(S(:,4));
            sil = mean(S(:,6));  cada = mean(S(:,7:12), 1);
            fprintf('%-22s |  %d  |   %d    | %3d/%3d = %5.1f%% | %5.1f +- %4.1f        | %5.1f%%  | %s\n', ...
                nomes{v}, f, size(S,1), tot, n, 100*tot/n, 100*mean(ac_parte), 100*std(ac_parte), ...
                100*sil, sprintf('%3.0f ', 100*cada));
            fprintf(fid, '%s;%d;%d;%d;%d;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f;%.4f\n', nomes{v}, f, ...
                size(S,1), n, tot, tot/n, std(ac_parte), sil, cada, mean(S(:,13)));
        end
    end
    fclose(fid);
end
