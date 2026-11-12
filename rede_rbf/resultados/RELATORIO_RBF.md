# Rede RBF: como foi feita, testes e resultados

Documento de trabalho da rede RBF (base do relatório em PDF). Segue o enunciado "Reconhecimento de fonemas via rede de Kohonen ou RBF" e os slides da aula "Rede de Função de Base Radial" (06_RNA-M).

---

## 1. O que o professor pede e o que foi feito

| Pedido (enunciado / slides) | Como foi feito |
|---|---|
| Reconhecer as sílabas DI, REI, TA, ES, QUER, DA das palavras DIREITA e ESQUERDA | 6 sílabas + silêncio (7 classes), as mesmas da MLP |
| Separar as sílabas dos áudios | mesma segmentação da MLP (cortes nos vales de energia, automática) |
| **Treino 75%, validação 15%, teste 10%** | divisão por repetição da palavra: 51/10/7 "direita", 55/11/7 "esquerda", 86/17/11 silêncios; 2.963 / 590 / 408 janelas. Gravada em `rede_rbf/divisao_rbf.csv` |
| Ler os áudios com `audioread` e salvar em arquivo `.mat` | as mesmas entradas da MLP (`rede/entradas/*.mat`) |
| FFT e média das amplitudes por grupo de frequências | 32 faixas de 156 Hz, de 0 a 5 kHz, com contexto (janelas vizinhas) |
| Programa de treino e programa de reconhecimento das palavras | `treinar_rbf.m` e `programa2_reconhecer('rbf')` (a mesma máquina de estados da MLP) |
| Códigos comentados | sim |
| Algoritmo de treino (slide 14): normalizar → centros → aberturas → congelar → pesos da saída | `rbf.m`, função `treinar`, nessa ordem |
| Gaussiana: out_i = exp(−‖x − c_i‖² / 2σ_i²), norma euclidiana (slides 4 e 5) | `rbf.m`, função `ativar` |
| Uma única camada escondida, número de neurônios definido pelo projetista (slide 6) | uma camada; o número de neurônios é testado (etapa 3) |
| Normalização da entrada para [0, 1] ou [−1, 1] pelo mínimo e máximo (slide 9) | `minmax` e `minmax11` em `entrada.m`, testadas junto com max, db e zscore (etapa 2) |
| Centros pelo algoritmo WTA: c_i = c_i + η(x − c_i), repetir enquanto o erro de quantização E_q for grande (slides 10 e 11) | `rbf.m`, função `wta`; η testado (etapa 4); o k-means entra só como comparação |
| Abertura (slide 12): ① raio único σ = k·d_máx; ② metade da distância ao centro mais perto; ③ média das distâncias aos T centros mais perto | as três, com vários k e T (etapa 5) |
| Pesos da saída "igual ao treinamento da MLP": ΔW = η·e·f′·out, demais parâmetros congelados (slide 13) | `rbf.m`, função `regra_delta`, com saída linear (f′ = 1) ou sigmoide (f′ = y(1 − y)); várias taxas (etapa 6) |
| Taxa de aprendizado e número de neurônios definidos pelo projetista (slide 15) | escolhidos por teste, etapa por etapa |

Nenhuma função pronta de rede neural: o WTA, o k-means, as aberturas, a gaussiana, a regra delta e o Cholesky (usado só como comparação) estão escritos à mão em `rbf.m`.

## 2. Procedimento dos testes

O mesmo esquema da MLP:

- **uma coisa varia por etapa**, e o vencedor de cada etapa segue para a próxima;
- cada configuração é treinada com **5 sementes** (sorteios diferentes dos centros iniciais e da ordem das amostras), e comparamos média e desvio;
- tudo é medido na **validação** (21 palavras, 590 janelas), com a **tolerância de 2 janelas** do programa 2; o teste (14 palavras) fica para o final;
- **regra de escolha:** mais palavras reconhecidas; se a diferença for menor que o desvio, decidem as sílabas; se empatar também, a opção mais simples.

| Etapa | O que varia | Opções |
|---|---|---|
| 1 | Entrada | 32 ou 64 faixas × sem ou com contexto |
| 2 | Normalização | max, db, zscore, min-max [0, 1], min-max [−1, 1] |
| 3 | Número de neurônios escondidos | 25, 50, 100, 200, 400 |
| 4 | Centros | WTA com η = 0,01, 0,05, 0,1, 0,3; k-means (comparação) |
| 5 | Abertura | raio único k = 0,1, 0,2, 0,3, 0,5, 1; metade da distância; média dos T = 2, 3, 5 mais perto |
| 6 | Pesos da saída | regra delta linear (η = 0,005 a 0,05), regra delta sigmoide (η = 0,05 a 0,5), Cholesky |

Configuração de referência (usada enquanto um fator ainda não foi testado): 32 faixas com contexto, min-max [0, 1], 100 neurônios, WTA η = 0,05, raio único k = 0,3, saída por Cholesky.

## 3. Anotações importantes

- **Por que a saída das etapas 1 a 5 é o Cholesky.** A regra delta só converge se a taxa for menor que 2 / (maior autovalor de Φᵀ·Φ/n), onde Φ é a saída dos neurônios escondidos. Na configuração de referência esse autovalor é 39,3: a regra delta diverge com taxa acima de 0,051 (testado: com η = 0,1 os pesos explodiram na 1ª época e o acerto caiu para 13,6%). Esse limite muda com cada configuração (mais neurônios ou aberturas maiores aumentam o autovalor). Se as etapas 1 a 5 usassem a regra delta com uma taxa fixa, uma configuração poderia perder só porque a taxa divergiu nela, e não por ser pior. Com o Cholesky, que dá os pesos exatos de mínimos quadrados, cada etapa compara só a camada escondida. A regra delta da aula é escolhida na etapa 6, com taxas abaixo e perto do limite. É a observação do slide 15: valores altos aceleram, valores baixos evitam oscilações.
- **Conferências feitas antes dos testes:** o WTA achou os 3 centros de três nuvens de pontos 2D; o Cholesky resolveu um sistema 300 × 300 com erro de 6·10⁻¹⁴; a rede resolveu o XOR; a divisão saiu exatamente 75/15/10 em cada grupo.
- **Primeira versão (descartada).** Antes de conferir os slides, a RBF foi testada com divisão 60/20/20, centros por k-means e saída por Cholesky. Ela mostrou que a RBF chega ao nível da MLP, mas não seguia o que a aula pede (WTA, as três aberturas, regra delta, min-max, 75/15/10). Os resultados dela ficaram fora do projeto, e todos os testes foram refeitos.

---

## 4. Resultados por etapa

(preenchido a cada etapa)

### Etapa 1 — Entrada

Fixo: min-max [0, 1], 100 neurônios, WTA η = 0,05, raio único k = 0,3, Cholesky.

| Entrada | Palavras (%) | Sílabas (%) | Janelas (%) |
|---|---|---|---|
| **32 faixas, com contexto (160 entradas)** | **76,2 ± 3,4** | **72,4 ± 0,5** | 78,1 |
| 32 faixas, sem contexto (32 entradas) | 72,4 ± 2,1 | 62,6 ± 0,9 | 70,3 |
| 64 faixas, sem contexto (64 entradas) | 72,4 ± 4,0 | 61,0 ± 0,6 | 69,0 |
| 64 faixas, com contexto (320 entradas) | 70,5 ± 4,0 | 70,9 ± 0,7 | 77,0 |

Vencedor: **32 faixas com contexto**. Nas palavras, empata no máximo com 64 sem contexto (3,8 pontos, menos que o desvio de 4,0); nas sílabas ganha por 11 pontos. O contexto ajuda a RBF pelo mesmo motivo da MLP: separa sílabas com a mesma vogal. Os valores absolutos ainda são baixos porque a normalização e a abertura de referência não foram ajustadas.

### Etapa 2 — Normalização

Fixo: 32 faixas com contexto, 100 neurônios, WTA η = 0,05, raio único k = 0,3, Cholesky.

| Normalização | Palavras (%) | Sílabas (%) | Janelas (%) |
|---|---|---|---|
| **db** | **78,1 ± 4,3** | **82,6 ± 0,5** | 85,6 |
| zscore | 77,1 ± 6,2 | 69,3 ± 1,2 | 76,0 |
| min-max [0, 1] (slide 9) | 76,2 ± 3,4 | 72,4 ± 0,5 | 78,1 |
| min-max [−1, 1] (slide 9) | 76,2 ± 3,4 | 72,4 ± 0,5 | 78,1 |
| max | 74,3 ± 8,0 | 73,7 ± 0,8 | 78,3 |

Vencedor: **db**. As cinco empatam nas palavras; nas sílabas o db ganha por 10 pontos.

Anotações:
- **min-max [0, 1] e [−1, 1] dão exatamente o mesmo resultado.** Passar de [0, 1] para [−1, 1] só multiplica cada entrada por 2 e desloca o zero; todas as distâncias dobram, o raio σ = k·d_máx dobra junto, e cada gaussiana responde igual. Para a RBF, as duas normalizações do slide são equivalentes.
- **Por que o db ganha:** a RBF decide por distância. O min-max olha cada faixa separadamente pelo mínimo e máximo do treino, e uma faixa com valores raros (picos) fica comprimida; o db compara cada faixa com a mais forte da própria janela, em escala logarítmica, o que deixa as janelas de uma mesma sílaba mais parecidas entre si.

### Etapa 3 — Número de neurônios escondidos

Fixo: 32 faixas com contexto, db, WTA η = 0,05, raio único k = 0,3, Cholesky.

| Neurônios | Palavras (%) | Sílabas (%) | Janelas (%) | Tempo de treino |
|---|---|---|---|---|
| 400 | 86,7 ± 4,0 | 83,2 ± 0,7 | 86,0 | 45,7 s |
| **200** | **83,8 ± 4,3** | **83,2 ± 1,1** | 86,0 | 14,3 s |
| 800 | 83,8 ± 2,6 | 82,8 ± 0,3 | 85,8 | 200,4 s |
| 50 | 80,0 ± 4,0 | 80,6 ± 1,0 | 84,0 | 3,8 s |
| 100 | 78,1 ± 4,3 | 82,6 ± 0,5 | 85,6 | 6,3 s |
| 25 | 78,1 ± 4,3 | 73,6 ± 1,8 | 78,9 | 1,5 s |

Vencedor: **200 neurônios**. 400, 200 e 800 empatam nas palavras e nas sílabas; 200 é o mais simples.

Anotações:
- A faixa começou em 25 a 400. Como o melhor ficou na ponta (400), a etapa foi refeita com 800 para conferir: com 800 a rede não melhora e o treino fica 14 vezes mais lento (o WTA percorre todas as amostras comparando com todos os centros). O pico está entre 200 e 400.
- Com poucos neurônios (25), a rede não tem centros suficientes para cobrir as 7 classes e cai 10 pontos nas sílabas.

### Etapa 4 — Centros dos neurônios escondidos

Fixo: 32 faixas com contexto, db, 200 neurônios, raio único k = 0,3, Cholesky.

| Centros | Palavras (%) | Sílabas (%) | Janelas (%) | Tempo de treino |
|---|---|---|---|---|
| **WTA, η = 0,05** | **83,8 ± 4,3** | **83,2 ± 1,1** | 86,0 | 12,8 s |
| WTA, η = 0,1 | 81,9 ± 4,0 | 83,0 ± 0,3 | 85,8 | 8,1 s |
| WTA, η = 0,3 | 81,0 ± 7,5 | 83,0 ± 0,7 | 85,8 | 3,5 s |
| k-means (comparação) | 81,0 ± 5,8 | 82,8 ± 0,6 | 85,7 | 2,0 s |
| WTA, η = 0,01 | 77,1 ± 2,1 | 82,7 ± 0,6 | 85,6 | 22,9 s |

Vencedor: **WTA com η = 0,05** (o algoritmo do slide 10). Empata com η = 0,1, η = 0,3 e o k-means nas palavras e nas sílabas; como nenhuma é mais simples, fica a que reconhece mais palavras.

Anotações:
- O WTA para quando o erro de quantização E_q (slide 11) cai menos de 0,1% de uma passada pelo treino para a outra (no máximo 100 passadas).
- η grande (0,3) converge rápido, mas os centros "pulam" mais, e o resultado varia mais entre as sementes (desvio de 7,5). η pequeno (0,01) é lento e para antes de os centros chegarem ao lugar certo. É o compromisso do slide 15: valores altos aceleram, valores baixos evitam oscilações.
- O k-means chega a centros parecidos com os do WTA (mesmo acerto), por outro caminho: em vez de mover só o centro vencedor a cada amostra, move cada centro para a média das suas amostras.

### Etapa 5 — Abertura dos neurônios escondidos

Fixo: 32 faixas com contexto, db, 200 neurônios, WTA η = 0,05, Cholesky. As três regras do slide 12.

| Abertura | Palavras (%) | Sílabas (%) | Janelas (%) |
|---|---|---|---|
| **① raio único σ = k·d_máx, k = 0,5** | **84,8 ± 4,0** | **82,7 ± 0,5** | 85,6 |
| ① raio único, k = 0,3 | 83,8 ± 4,3 | 83,2 ± 1,1 | 86,0 |
| ① raio único, k = 1 | 82,9 ± 4,3 | 81,5 ± 0,6 | 84,7 |
| ③ média das distâncias aos T = 2 mais perto | 79,0 ± 2,6 | 83,4 ± 1,2 | 86,5 |
| ③ média aos T = 3 mais perto | 79,0 ± 2,6 | 83,3 ± 1,4 | 86,4 |
| ① raio único, k = 0,1 | 79,0 ± 5,4 | 79,8 ± 2,3 | 84,1 |
| ① raio único, k = 0,2 | 78,1 ± 5,4 | 83,3 ± 0,9 | 86,3 |
| ③ média aos T = 5 mais perto | 78,1 ± 2,6 | 83,3 ± 1,5 | 86,3 |
| ② metade da distância ao centro mais perto | 74,3 ± 2,6 | 76,8 ± 1,2 | 81,7 |

Vencedor: **raio único com k = 0,5**. Nas palavras empata com k = 0,3 e k = 1; nas sílabas, com k = 0,3; entre essas duas, nenhuma é mais simples, e fica a que reconhece mais palavras.

Anotações:
- A regra ② (metade da distância) foi a pior: com 200 centros, cada centro tem um vizinho muito perto, e a gaussiana fica estreita demais, respondendo só a amostras quase em cima do centro.
- As regras ③ dão aberturas um pouco maiores e acertam bem as sílabas (83,3–83,4%), mas reconhecem menos palavras que o raio único.
- O raio único é sensível ao k: pequeno demais (0,1) e a rede perde 6 pontos nas palavras; grande demais (1) e as gaussianas se sobrepõem, perdendo sílabas.

### Etapa 6 — Pesos da camada de saída

Fixo: 32 faixas com contexto, db, 200 neurônios, WTA η = 0,05, raio único k = 0,5.

**Primeira rodada (regra delta sem momento, até 1.000 épocas, paciência de 100):**

| Saída | Palavras (%) | Sílabas (%) | Melhor época (média) |
|---|---|---|---|
| Cholesky | 84,8 ± 4,0 | 82,7 ± 0,5 | — |
| delta linear, η = 0,01 | 79,0 ± 2,6 | 74,4 ± 0,5 | 979 |
| delta sigmoide, η = 0,5 | 78,1 ± 2,6 | 77,4 ± 0,7 | 948 |
| delta linear, η = 0,02 | 75,2 ± 6,2 | 74,2 ± 0,7 | 451 |
| delta sigmoide, η = 0,2 | 74,3 ± 2,6 | 76,5 ± 0,4 | 980 |
| delta linear, η = 0,005 | 73,3 ± 4,3 | 73,3 ± 0,6 | 990 |
| delta sigmoide, η = 0,1 | 70,5 ± 2,1 | 75,8 ± 0,6 | 985 |
| delta sigmoide, η = 0,05 | 68,6 ± 2,6 | 74,1 ± 0,7 | 985 |
| delta linear, η = 0,05 | 0,0 | 13,3 ± 7,5 | divergiu na 1ª época |

O que essa rodada mostrou:
- **A regra delta não terminou de aprender:** a melhor época ficou perto de 1.000, o limite. Com saída linear, a regra delta minimiza o mesmo erro quadrático que o Cholesky resolve de uma vez; com épocas suficientes, chegaria ao mesmo resultado.
- **Limite de estabilidade, medido nesta configuração:** o maior autovalor de Φᵀ·Φ/n é 85,6, então a regra delta linear só converge com η < 2/85,6 ≈ 0,023. Confere com o que aconteceu: η = 0,05 divergiu, η = 0,02 (perto do limite) oscilou e parou cedo (época 451), η = 0,01 convergiu, mas devagar demais.
- Por isso a etapa foi refeita com **momento 0,9**, como no treino da MLP (o slide 13 diz "igual ao treinamento da MLP"), e **até 5.000 épocas** (paciência de 200). Com momento, o limite sobe para cerca de 2·(1 + 0,9)/85,6 ≈ 0,044, e os passos ficam efetivamente 10 vezes maiores.

**Rodada completa (todas as opções, as de momento com até 5.000 épocas e paciência de 200):**

| Saída | Palavras (%) | Sílabas (%) | Janelas (%) | Melhor época (média) | Tempo |
|---|---|---|---|---|---|
| **Cholesky** | **84,8 ± 4,0** | **82,7 ± 0,5** | 85,6 | — | 14 s |
| delta linear, η = 0,02, momento 0,9 | 81,9 ± 2,1 | 78,7 ± 0,8 | 82,9 | 640 | 51 s |
| delta sigmoide, η = 0,1, momento 0,9 | 81,0 ± 0,0 | 80,0 ± 0,4 | 83,9 | 1.867 | 103 s |
| delta sigmoide, η = 0,05, momento 0,9 | 81,0 ± 0,0 | 79,7 ± 0,7 | 83,6 | 2.752 | 161 s |
| delta linear, η = 0,01, momento 0,9 | 80,0 ± 2,1 | 78,9 ± 1,1 | 83,0 | 971 | 64 s |
| delta linear, η = 0,005, momento 0,9 | 80,0 ± 2,1 | 78,5 ± 0,8 | 82,7 | 1.628 | 93 s |
| delta sigmoide, η = 0,02, momento 0,9 | 79,0 ± 2,6 | 77,5 ± 0,4 | 82,2 | 3.195 | 182 s |
| delta linear, η = 0,01, sem momento | 79,0 ± 2,6 | 74,4 ± 0,5 | 80,2 | 979 | 58 s |
| delta linear, η = 0,002, momento 0,9 | 79,0 ± 2,6 | 77,5 ± 0,4 | 82,1 | 2.676 | 142 s |
| delta sigmoide, η = 0,5, sem momento | 78,1 ± 2,6 | 77,4 ± 0,7 | 82,0 | 981 | 68 s |
| delta sigmoide, η = 0,2, sem momento | 74,3 ± 2,6 | 76,5 ± 0,4 | 81,4 | 980 | 68 s |
| delta linear, η = 0,02, sem momento | 74,3 ± 5,4 | 75,3 ± 0,9 | 80,7 | 884 | 60 s |
| delta linear, η = 0,005, sem momento | 73,3 ± 4,3 | 73,3 ± 0,6 | 79,4 | 990 | 49 s |
| delta sigmoide, η = 0,1, sem momento | 70,5 ± 2,1 | 75,8 ± 0,6 | 80,7 | 985 | 65 s |
| delta sigmoide, η = 0,05, sem momento | 68,6 ± 2,6 | 74,1 ± 0,7 | 79,4 | 985 | 66 s |
| delta linear, η = 0,05, sem momento | 0,0 | 13,3 ± 7,5 | 14,5 | divergiu | 23 s |

Anotações:
- **O momento resolveu a convergência da regra delta:** com ele, as palavras subiram de 68–79% para 79–82% e as sílabas de 73–77% para 77–80%, e a melhor época ficou bem antes do limite de 5.000.
- **Pela regra de escolha, o Cholesky vence:** empata nas palavras com as três melhores regras delta com momento (diferenças de 2,9 e 3,8, menores que o desvio de 4,0) e ganha nas sílabas por pelo menos 2,7 pontos.
- **Entre as regras delta, a melhor é a sigmoide com η = 0,1 e momento 0,9:** empata nas palavras com a linear η = 0,02 e ganha nas sílabas (80,0 contra 78,7). É a fórmula exata do slide 13, com f′ = y(1 − y), e todas as 5 sementes reconheceram as mesmas 17 de 21 palavras (desvio zero).
- **Por que o Cholesky fica à frente:** com saída linear, os dois minimizam o mesmo erro quadrático, mas a regra delta para pela validação (parada antecipada) antes de chegar ao mínimo exato, que o Cholesky calcula direto. Com saída sigmoide, o erro minimizado é outro, e não existe solução direta.

**Decisão da etapa 6: regra delta sigmoide, η = 0,1, momento 0,9 (até 5.000 épocas).** Pela regra de escolha o Cholesky venceria (+2,7 pontos nas sílabas, empate nas palavras), mas os slides pedem a regra delta para os pesos da saída (slide 13: "igual ao treinamento da rede MLP", ΔW = η·e·f′·out; slide 14, passo 5; slide 15: taxa de aprendizado definida pelo projetista). O Cholesky não aparece nos slides e fica no relatório só como comparação: ele mostra o mínimo exato do erro quadrático, que a regra delta quase alcança. A regra delta escolhida empata com ele nas palavras.

**RBF escolhida:** 32 faixas com contexto (160 entradas), normalização db, 200 neurônios escondidos com centros pelo WTA (η = 0,05), raio único σ = 0,5·d_máx, pesos da saída pela regra delta com saída sigmoide (η = 0,1, momento 0,9). Pesos: 200 × 160 (centros) + 201 × 7 (saída) = 33.407.

---

## 5. Validação cruzada (127 palavras)

As 14 palavras de teste ficam de fora. As outras 127 (e os silêncios) são divididas em 5 partes, sorteadas por repetição; a RBF escolhida é treinada 5 vezes, cada vez validando numa parte diferente. Assim, cada uma das 127 palavras é reconhecida por uma rede que nunca a viu. Mede-se o reconhecimento com tolerância de 0 a 3 janelas.

| Tolerância (janelas) | Palavras reconhecidas | Sílabas (%) |
|---|---|---|
| 0 | 101 de 127 (79,5%) | 86,7 |
| 1 | 105 (82,7%) | 86,7 |
| **2 (usada no programa 2)** | **108 (85,0%)** | 86,7 |
| 3 | 110 (86,6%) | 86,7 |

| Parte | Palavras | Sem tolerância | Tolerância 2 | Sílabas (%) |
|---|---|---|---|---|
| 1 | 27 | 22 | 24 | 84,5 |
| 2 | 25 | 24 | 24 | 86,5 |
| 3 | 25 | 17 | 20 | 83,5 |
| 4 | 25 | 18 | 19 | 87,2 |
| 5 | 25 | 20 | 21 | 91,6 |

Acerto por sílaba (média das partes): di 85%, rei 91%, ta 83%, es 77%, quer 89%, da 96%.

Anotações:
- Com 127 palavras, o acerto da RBF fica em **85,0%** com a tolerância de 2 janelas (79,5% sem tolerância). A tolerância acrescenta 7 palavras.
- O "es" continua sendo a sílaba mais difícil (77%), como na MLP: o começo dele é a mesma vogal do "quer".

---

## 6. Resultado final no teste (14 palavras, medido uma única vez)

A RBF escolhida foi treinada com 5 sementes; a escolhida é a de mais palavras na validação (as 5 empataram em 17 de 21; o desempate foi pelo acerto das janelas de validação: semente 4). Só depois as 14 palavras de teste foram usadas.

| Semente | Palavras validação (de 21) | Palavras teste (de 14) | Janelas teste | Sílabas teste | Tempo de treino |
|---|---|---|---|---|---|
| 1 | 17 | 12 | 90,2% | 88,5% | 52 s |
| 2 | 17 | 13 | 90,0% | 87,7% | 53 s |
| 3 | 17 | 13 | 88,0% | 85,5% | 41 s |
| **4 (escolhida)** | **17** | **12** | 89,0% | 87,1% | 56 s |
| 5 | 17 | 13 | 89,7% | 87,5% | 53 s |
| Média | 17,0 (81,0%) | **12,6 (90,0%)** | 89,4% | 87,3% | 51 s |

| Medida (rede escolhida) | Resultado |
|---|---|
| Palavras isoladas de teste | **12 de 14 (85,7%)**: direita 7/7, esquerda 5/7; nenhuma trocada, 2 não reconhecidas |
| Fala contínua (14 palavras emendadas) | **13 de 14 (92,9%)**: 0 trocadas, 1 perdida, 0 falsos alarmes |
| Janelas: treino / validação / teste | 91,8% / 84,2% / 89,0% |
| Acerto médio das 6 sílabas (teste) | 87,1% |

Matriz de confusão das janelas de teste (linha: sílaba dita; coluna: resposta da rede):

| dito \ resposta | di | rei | ta | es | quer | da | silêncio | acerto |
|---|---|---|---|---|---|---|---|---|
| di | **31** | 2 | 0 | 0 | 0 | 0 | 0 | 94% |
| rei | 9 | **59** | 1 | 0 | 0 | 0 | 0 | 86% |
| ta | 0 | 2 | **40** | 0 | 0 | 3 | 0 | 89% |
| es | 0 | 0 | 0 | **52** | 8 | 0 | 0 | 87% |
| quer | 1 | 6 | 1 | 4 | **46** | 3 | 0 | 75% |
| da | 0 | 1 | 3 | 0 | 1 | **58** | 0 | 92% |
| silêncio | 0 | 0 | 0 | 0 | 0 | 0 | **77** | 100% |

Anotações:
- A troca mais comum é "rei" respondido como "di" (9 janelas) e "quer" respondido como "es" ou "rei": sílabas vizinhas, como na MLP.
- Com só 14 palavras de teste (10% pedidos no enunciado), cada palavra vale 7 pontos: entre as sementes o teste varia de 12 a 13 palavras. A validação cruzada com 127 palavras (85,0% com tolerância 2) é a medida mais confiável.

---

## 7. MLP × RBF

As duas redes usam as mesmas janelas, a mesma entrada (32 faixas com contexto) e o mesmo programa 2. As divisões são diferentes (MLP: 60/20/20, como definido no primeiro trabalho; RBF: 75/15/10, como pede o enunciado da RBF), então os testes não são as mesmas palavras.

| Medida | MLP | RBF |
|---|---|---|
| Estrutura | 160 → 64 → 32 → 7, sigmoide | 160 → 200 gaussianas → 7, saída sigmoide |
| Treino | retropropagação em todas as camadas | WTA nos centros, abertura fixa, regra delta só na saída |
| Normalização escolhida | max | db |
| Pesos | 12.615 | 33.407 |
| Validação cruzada, tolerância 2 | 91,1% (102 de 112) | 85,0% (108 de 127) |
| Validação cruzada, sem tolerância | 80,4% | 79,5% |
| Sílabas (validação cruzada) | 87,1% | 86,7% |
| Palavras de teste (rede escolhida) | 24/29 (82,8%) | 12/14 (85,7%) |
| Palavras de teste (média das 5 sementes) | 83,4% | 90,0% |
| Fala contínua (teste) | 27/29 (93,1%) | 13/14 (92,9%) |
| Trocas direita ↔ esquerda | 0 | 0 |

- **Sem tolerância e nas sílabas, as duas redes empatam** (80,4% contra 79,5% das palavras; 87,1% contra 86,7% das sílabas).
- **Com a tolerância de 2 janelas, a MLP vai melhor** (91,1% contra 85,0%): a tolerância corrige mais os erros da MLP, que são janelas soltas.
- **No teste, a RBF fica à frente**, mas com 14 palavras (contra 29 da MLP) a diferença não é conclusiva.
- **A RBF precisou de mais neurônios** (200 contra 64 + 32) porque cada neurônio dela cobre só uma região do espaço de entrada (a gaussiana em torno do centro), enquanto um neurônio da MLP divide o espaço inteiro.
