# Reconhecimento de voz com rede neural

Reconhecimento das palavras DIREITA e ESQUERDA com redes neurais escritas à mão em MATLAB/GNU Octave: uma MLP (primeiro trabalho) e uma RBF (segundo trabalho). A rede reconhece as sílabas (di, rei, ta, es, quer, da e silêncio), e o programa 2 reconhece a palavra inteira a partir da sequência de sílabas.

## Como rodar

Cada rede tem a sua pasta e o seu próprio `rodar_projeto`: `rede_mlp/` (primeiro trabalho) e `rede_rbf/` (segundo trabalho). A pasta `segmentacao/` é a mesma para as duas.

**No Windows, com dois cliques:** abra o `rodar_projeto.bat` de dentro da pasta da rede. Ele procura o MATLAB ou o GNU Octave no computador, oferece instalar o Octave (pelo `winget`) se nenhum dos dois existir, pergunta se é para rodar só o programa 2 ou refazer tudo, e roda o projeto.

**Dentro do MATLAB ou do Octave:** abra a pasta da rede no MATLAB (R2016b ou mais novo) ou no GNU Octave (6 ou mais novo) e rode:

- `rodar_projeto`: confere o ambiente e roda o programa 2 com a rede já treinada (cerca de 3 minutos; se as palavras ainda não foram cortadas, roda a segmentação antes);
- `rodar_projeto('tudo')`: confere o ambiente e refaz tudo do zero, da segmentação ao programa 2 (cerca de 10 minutos).

O projeto usa só funções básicas (`audioread`, `fft`, `movmean`...), sem toolbox e sem pacote extra; não é preciso baixar nada. A divisão treino/validação/teste fica gravada em arquivo (`rede_mlp/entradas/divisao.csv` e `rede_rbf/divisao_rbf.csv`), para ser a mesma no MATLAB e no Octave. O treino sorteia os pesos iniciais, e o MATLAB sorteia números diferentes do Octave: ao refazer o treino no MATLAB, o acerto pode variar uma ou duas palavras.

## Ordem de execução (MLP)

1. `segmentacao/segmentar_audios.m`: encontra as palavras nas gravações e corta cada uma em 3 sílabas nos vales de energia, mais os trechos de silêncio → `segmentacao/saida/`
2. `rede_mlp/extrair_entradas.m`: janelas de 150 ms (passo de 25 ms), FFT de 0 a 5 kHz em faixas, divisão 60/20/20 por repetição → `rede_mlp/entradas/`
3. `rede_mlp/treinar_mlp.m`: treina a rede escolhida e mede o teste → `rede_mlp/resultados/`
4. `rede_mlp/programa2_reconhecer.m`: programa 2, com janela deslizante e máquina de estados

Experimentos usados para escolher a rede (não precisam ser rodados para usar o programa):

- `rede_mlp/experimentos.m`: etapas 1 a 4 (entrada, normalização, camadas, ativação e taxa) e validação cruzada com 112 palavras. Ex.: `experimentos('etapa', 1)`, `experimentos('resumo', 1)`, `experimentos('validacao_cruzada')`

Os resultados e as justificativas de cada escolha estão em `rede_mlp/resultados/RELATORIO.md`.

## Rede RBF (segundo trabalho)

A pasta `rede_rbf/` tem a RBF (`rbf.m`: centros pelo WTA, aberturas, gaussiana e regra delta), o treino (`treinar_rbf.m`), os experimentos (`experimentos_rbf.m`) e as suas próprias cópias da extração das entradas e do programa 2. A divisão é 75/15/10, como pede o enunciado. A rede final tem 200 neurônios gaussianos e reconheceu 12 das 14 palavras de teste (85,7%) e 13 de 14 na fala contínua (92,9%). Os detalhes estão em `rede_rbf/resultados/RELATORIO_RBF.md` e no `relatorio/relatorio_rbf.pdf`.

## Rede final (MLP)

| Item | Escolha |
|---|---|
| Corte das sílabas | vales de energia |
| Entrada | 32 faixas da janela atual e de 4 vizinhas (±50 e ±100 ms) = 160 entradas |
| Normalização | cada janela dividida pelo seu maior valor |
| Camadas | 160 → 64 → 32 → 7, sigmoide |
| Treino | retropropagação com momento, taxa 0,5 |
| Programa 2 | di → rei → ta / es → quer → da, ignorando até 2 janelas soltas fora da sequência |
| Teste (29 palavras) | 24 reconhecidas (82,8%), nenhuma trocada; fala contínua 27 de 29 (93,1%) |

## Pastas

- `material do professor/`: enunciado, slides e gravações originais (.aac)
- `segmentacao/audios/`: as duas gravações em FLAC, sem perda (o Octave não lê .aac)
- `segmentacao/saida/`: palavras inteiras, sílabas, silêncios, CSV dos cortes e figuras
- `rede_mlp/`: a MLP (`mlp.m`), a entrada da rede (`entrada.m`: FFT em faixas, contexto e normalização), extração, treino, programa 2, experimentos e `rodar_projeto`
- `rede_mlp/resultados/`: rede final, figuras, relatório e dados dos experimentos
- `rede_rbf/`: a RBF, com a mesma organização (resultados em `rede_rbf/resultados/`)
- `relatorio/`: os relatórios em PDF das duas redes

## Rodar no VS Code

`Ctrl+Shift+B` roda o arquivo .m aberto no GNU Octave (`.vscode/tasks.json`). O caminho do Octave nesse arquivo é o do PC onde foi configurado; em outro PC, ajuste o campo `command`.
