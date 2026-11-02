# Escolha da configuração da rede — registro dos experimentos

Registro de cada etapa da escolha da rede, com protocolo, tabelas e conclusões.
Os dados brutos ficam nesta pasta:

- `etapa<N>_semente<S>.csv`: uma linha por rede treinada.
- `resumo_etapa<N>.csv`: média e desvio entre as sementes.
- `resumo_etapa<N>.png`: gráfico de barras com média ± desvio.

Scripts: [escolher_arquitetura.m](../../escolher_arquitetura.m) (treina) e
[resumir_escolha.m](../../resumir_escolha.m) (resume).

---

## 1. Dados e configuração fixa

| Item | Valor |
|---|---|
| Palavras gravadas | 68 "direita", 73 "esquerda", 114 trechos de silêncio |
| Segmentação das sílabas | método **energia**: cortes nos vales da curva de energia. No "direita", o corte rei\|ta fica no **fundo** do vale; nas demais fronteiras, no início do vale |
| Divisão (por repetição da palavra) | **60% treino / 20% validação / 20% teste**, sorteio fixo (`rng(42)`) |
| Amostras (janelas de 150 ms, passo de 25 ms) | treino 2.379, validação 796, teste 786 |
| Palavras inteiras | validação **27**, teste **29** |
| Entrada | espectro (FFT com janela de Hamming) de 0 a 5 kHz, dividido em faixas iguais |
| Saída | 7 classes: di, rei, ta, es, quer, da, silêncio |
| Treino | retropropagação, erro quadrático médio, momento 0,9, lote de 32, até 800 épocas, parada antecipada com **paciência de 200 épocas** (guarda a rede com menor erro de validação) |
| Reconhecimento de palavras | programa 2: janela deslizante + máquina de estados (di→rei→ta / es→quer→da), `n_conf = 1`, silêncio máximo de 0,3 s |

## 2. Protocolo

- **Sementes.** Cada configuração é treinada **5 vezes** (sementes 1 a 5). Muda o sorteio dos pesos iniciais e a ordem das amostras. Os resultados mostram **média ± desvio padrão**.
- **Só validação.** Tudo é medido no conjunto de **validação**. O **teste não é usado em nenhuma escolha**; ele fica reservado para a nota final.
- **Medidas:**
  - **palavras**: % das 27 palavras de validação reconhecidas pelo programa 2;
  - **sílabas**: média do acerto das 6 sílabas, janela a janela;
  - **janelas**: % de todas as janelas classificadas certo, incluindo o silêncio.

### Regra de escolha (definida antes dos experimentos)

1. Vence a configuração com mais **palavras** de validação (média das sementes).
2. Se a diferença for **menor que o desvio padrão**, as duas são consideradas empatadas e vence a **mais simples**.
3. No empate, decide o acerto médio das **sílabas**.

### Ordem das etapas

Da entrada ("o que a rede vê") para o treino ("como ela aprende"). Cada etapa usa os vencedores das anteriores.

| Etapa | Fator testado | Configuração fixa |
|---|---|---|
| 1 | contexto (sem/com) × faixas (32/64) | 1 camada de 64, sigmoide, taxa 0,5, db |
| 2 | normalização (max/db/zscore) | entrada vencedora da etapa 1 |
| 3 | arquitetura (camadas em funil) | entrada e normalização vencedoras, sigmoide, taxa 0,5 |
| 4 | ativação + taxa de aprendizado | arquitetura vencedora |
| 5 | confirmação: melhores arquiteturas com a ativação e a taxa finais | tudo |

---

## Etapa 1 — Entrada: contexto e número de faixas

**Fixo:** 1 camada oculta de 64, sigmoide, taxa 0,5, normalização db.

### Resumo (média ± desvio de 5 sementes, validação)

| Posição | Faixas | Contexto | Nº de entradas | Palavras (%) | Sílabas (%) | Janelas (%) |
|---|---|---|---|---|---|---|
| **1º** | **32** | **sim** | **160** | **80,7 ± 1,7** | **79,0 ± 1,2** | **84,0 ± 0,9** |
| 2º | 64 | sim | 320 | 69,6 ± 14,7 | 76,5 ± 5,3 | 81,9 ± 4,5 |
| 3º | 32 | não | 32 | 64,4 ± 6,7 | 70,7 ± 1,5 | 77,6 ± 1,2 |
| 4º | 64 | não | 64 | 63,0 ± 10,8 | 71,4 ± 0,8 | 78,1 ± 0,6 |

### Acerto por sílaba (%, média das sementes)

| Faixas | Contexto | di | rei | ta | es | quer | da |
|---|---|---|---|---|---|---|---|
| 32 | sim | 84 | 70 | 86 | 81 | 62 | 90 |
| 64 | sim | 85 | 73 | 70 | 80 | 61 | 91 |
| 32 | não | 75 | 61 | 79 | 72 | 49 | 87 |
| 64 | não | 74 | 62 | 81 | 72 | 54 | 86 |

### Por semente (palavras certas de 27 / sílabas %)

| Faixas | Contexto | Semente 1 | Semente 2 | Semente 3 | Semente 4 | Semente 5 |
|---|---|---|---|---|---|---|
| 32 | sim | 22 / 79,1 | 22 / 79,6 | 21 / 79,7 | 22 / 79,8 | 22 / 76,8 |
| 64 | sim | 21 / 78,9 | 19 / 78,9 | 20 / 80,2 | 22 / 77,1 | **12 / 67,1** (*) |
| 32 | não | 18 / 68,9 | 19 / 71,2 | 16 / 69,3 | 15 / 72,6 | 19 / 71,2 |
| 64 | não | 16 / 71,3 | 14 / 70,1 | 21 / 71,7 | 19 / 71,4 | 15 / 72,3 |

(*) Treino que falhou: parou na época 25, com acerto bem abaixo das outras sementes.

### Conclusões

1. **O contexto melhora muito.** Com 32 faixas, as palavras sobem de 64,4% para 80,7% (+16,3 pontos) e as sílabas de 70,7% para 79,0% (+8,3 pontos). As diferenças são muito maiores que o desvio.
   - Nenhuma das 10 redes sem contexto passou de 72,6% nas sílabas.
   - A pior rede com contexto e 32 faixas fez 76,8%.
   - Motivo: sem contexto, a janela de 150 ms do início do "es" contém só a vogal "e", igual à do "quer". As janelas vizinhas (±100 ms) trazem o "s" e o "r", que desfazem a confusão.
2. **32 faixas é melhor que 64.** Com contexto, 32 faixas teve mais palavras (80,7% contra 69,6%) e foi muito mais estável (desvio de 1,7 contra 14,7): todas as 5 sementes acertaram 21 ou 22 palavras.
   - Com 64 faixas (320 entradas), uma das sementes falhou no treino.
   - Mesmo sem essa semente, 64 faixas fica em ~76% nas palavras.
   - 32 faixas usa metade das entradas.
3. **Vencedor da etapa 1: 32 faixas, com contexto** (160 entradas).

---

## Etapa 2 — Normalização

**Fixo:** 32 faixas, com contexto, 1 camada oculta de 64, sigmoide, taxa 0,5.

| Normalização | Como funciona |
|---|---|
| max | divide cada vetor de entrada pelo seu maior valor → 0 a 1 (escala linear) |
| db | valor relativo ao maior, em decibéis, de −60 a 0 dB → 0 a 1 (escala logarítmica) |
| zscore | para cada faixa, subtrai a média e divide pelo desvio, calculados no treino |

### Resumo (média ± desvio de 5 sementes, validação)

| Posição | Normalização | Palavras (%) | Sílabas (%) | Janelas (%) | Época média |
|---|---|---|---|---|---|
| **1º** | **max** | **82,2 ± 3,1** | **82,5 ± 1,1** | **86,6 ± 0,9** | 215 |
| 2º | db | 80,7 ± 1,7 | 79,0 ± 1,2 | 84,0 ± 0,9 | 111 |
| 3º | zscore | 32,6 ± 18,4 | 60,6 ± 11,9 | 69,3 ± 11,6 | 75 |

### Acerto por sílaba (%, média das sementes)

| Normalização | di | rei | ta | es | quer | da |
|---|---|---|---|---|---|---|
| max | 86 | 79 | 90 | 83 | 68 | 90 |
| db | 84 | 70 | 86 | 81 | 62 | 90 |
| zscore | 84 | 52 | 71 | 73 | 28 | 56 |

### Por semente (palavras certas de 27 / sílabas %)

| Normalização | Semente 1 | Semente 2 | Semente 3 | Semente 4 | Semente 5 |
|---|---|---|---|---|---|
| max | 23 / 81,9 | 23 / 81,6 | 22 / 82,2 | 21 / 82,7 | 22 / 84,3 |
| db | 22 / 79,1 | 22 / 79,6 | 21 / 79,7 | 22 / 79,8 | 22 / 76,8 |
| zscore | 11 / 54,1 | 11 / 70,2 | **0 / 42,8** | 12 / 66,4 | 10 / 69,5 |

### Conclusões

1. **zscore é descartado.** O treino é instável: o desvio é enorme e uma semente não reconheceu nenhuma palavra.
   - O zscore normaliza cada faixa com a média do treino inteiro, e não janela por janela. Por isso a entrada continua dependendo do volume da fala.
   - O mesmo comportamento já tinha aparecido no teste antigo do projeto.
2. **max contra db.**
   - **Palavras: empate.** A diferença é de 1,5 ponto (cerca de 0,4 palavra), menor que o desvio (±3,1).
   - **Sílabas: o max é claramente melhor.** São +3,5 pontos (82,5% contra 79,0%), bem acima do desvio (±1,1 e ±1,2). O max ganhou em todas as 5 sementes. O maior ganho foi no "rei" (+9) e no "quer" (+6).
   - Pela regra, o empate nas palavras é decidido pelas sílabas, e o max também é a opção mais simples.
3. **Vencedor da etapa 2: max.**
   - Isso **corrige** a escolha anterior do db. Aquela escolha veio de um teste antigo, sem contexto, com 1 só semente e medido no teste.
   - Com contexto e medido na validação com 5 sementes, o max é melhor.
4. **Observação:** com o max, a rede atinge o menor erro de validação mais tarde (época média de 215 contra 111). Isso confirma que a paciência de 200 épocas é necessária.

---

## Etapa 3 — Arquitetura

**Fixo:** 32 faixas, com contexto (160 entradas), normalização max, sigmoide, taxa 0,5.

**Opções:** todas em funil, com cada camada tendo metade da anterior.

- Com 1 camada, varia a **largura**: [32], [64], [128].
- Com várias camadas, varia a **profundidade**: [64 32], [128 64], [128 64 32], [256 128 64 32].

**Regra prática:** neurônios ≈ √(entradas × saídas) = √(160 × 7) ≈ 33.

### Resumo (média ± desvio de 5 sementes, validação)

| Posição (palavras) | Camadas ocultas | Nº de camadas | Pesos | Palavras (%) | Palavras (de 27) | Sílabas (%) | Janelas (%) | Época média | Tempo médio de treino |
|---|---|---|---|---|---|---|---|---|---|
| 1º | [128 64] | 2 | 29.319 | **88,1 ± 6,6** | 23,8 | 82,5 ± 0,8 | 86,8 ± 0,7 | 195 | 115 s |
| 2º | **[32]** | 1 | **5.383** | 83,7 ± 8,1 | 22,6 | 82,5 ± 0,8 | 86,7 ± 0,6 | 172 | 36 s |
| 3º | [64 32] | 2 | 12.615 | 83,0 ± 5,6 | 22,4 | 82,5 ± 1,1 | 86,7 ± 0,9 | 159 | 67 s |
| 4º | [64] | 1 | 10.759 | 82,2 ± 3,1 | 22,2 | 82,5 ± 1,1 | 86,6 ± 0,9 | 215 | 51 s |
| 5º | [256 128 64 32] | 4 | 84.679 | 82,2 ± 1,7 | 22,2 | 82,1 ± 0,4 | 86,4 ± 0,4 | 283 | 280 s |
| 6º | [128] | 1 | 21.511 | 81,5 ± 3,7 | 22,0 | 82,7 ± 0,4 | 86,9 ± 0,3 | 231 | 77 s |
| 7º | [128 64 32] | 3 | 31.175 | 80,7 ± 7,1 | 21,8 | 81,9 ± 0,7 | 86,1 ± 0,7 | 196 | 124 s |

### Acerto por sílaba (%, média das sementes)

| Camadas ocultas | di | rei | ta | es | quer | da |
|---|---|---|---|---|---|---|
| [128 64] | 85 | 74 | 87 | 89 | 71 | 90 |
| [32] | 83 | 78 | 89 | 86 | 66 | 92 |
| [64 32] | 87 | 78 | 84 | 86 | 69 | 92 |
| [64] | 86 | 79 | 90 | 83 | 68 | 90 |
| [256 128 64 32] | 90 | 76 | 81 | 89 | 67 | 90 |
| [128] | 84 | 78 | 90 | 85 | 66 | 93 |
| [128 64 32] | 89 | 76 | 81 | 86 | 69 | 91 |

### Por semente (palavras certas de 27 / sílabas %)

| Camadas ocultas | Semente 1 | Semente 2 | Semente 3 | Semente 4 | Semente 5 |
|---|---|---|---|---|---|
| [128 64] | 22 / 82,3 | 25 / 82,4 | 24 / 82,3 | 22 / 81,7 | 26 / 83,9 |
| [32] | 25 / 81,6 | 25 / 82,7 | 21 / 83,8 | 21 / 82,3 | 21 / 82,0 |
| [64 32] | 23 / 82,3 | 24 / 82,2 | 22 / 81,0 | 23 / 83,8 | 20 / 83,4 |
| [64] | 23 / 81,9 | 23 / 81,6 | 22 / 82,2 | 21 / 82,7 | 22 / 84,3 |
| [256 128 64 32] | 22 / 81,6 | 22 / 82,2 | 22 / 82,6 | 23 / 82,3 | 22 / 82,0 |
| [128] | 23 / 82,4 | 22 / 83,1 | 21 / 83,0 | 23 / 82,7 | 21 / 82,3 |
| [128 64 32] | 21 / 81,6 | 19 / 81,6 | 24 / 82,7 | 23 / 81,0 | 22 / 82,4 |

### Conclusões

1. **Nas sílabas, todas as arquiteturas empatam.** Elas ficam entre 81,9% e 82,7%, uma faixa de 0,8 ponto, menor que o desvio de cada uma. Uma rede de 1 camada com 32 neurônios (5.383 pesos) tem o mesmo acerto de sílabas que uma de 4 camadas (84.679 pesos, 16 vezes mais).
2. **Nas palavras, as diferenças também ficam dentro da variação.**
   - A [128 64] teve a maior média: 23,8 de 27 palavras, contra 22,6 da [32]. São 1,2 palavra a mais.
   - Essa diferença (4,4 pontos) é **menor que o desvio** das duas (±6,6 e ±8,1).
   - Nas sementes individuais, a [32] fez de 21 a 25 palavras, e a [128 64] fez de 22 a 26.
   - Um teste t de Welch sobre as palavras das 5 sementes dá p = 0,37 entre a [128 64] e a [32], e p = 0,12 entre a [128 64] e a [64]. Nenhuma diferença é estatisticamente significativa (p < 0,05).
3. **Profundidade não ajudou.** As redes de 3 e 4 camadas ficaram em 5º e 7º nas palavras. Elas também precisaram de mais épocas e de muito mais tempo de treino: a [256 128 64 32] levou 280 s por treino, contra 36 s da [32].
4. Pela regra (empate → opção mais simples), a vencedora seria a [32]: 1 camada de 32 neurônios, que também coincide com a regra prática (≈ 33 neurônios).
5. **Decisão do grupo: seguir com a [128 64]** (2 camadas, 128 e 64 neurônios).
   - Motivo: ela teve a **maior média de palavras** (23,8 de 27), que é a medida principal do trabalho, e foi a única com uma semente acertando 26 de 27.
   - Ela empata com as demais nas sílabas.
   - A vantagem nas palavras não é estatisticamente significativa (p = 0,37 contra a [32]).
   - Por isso a [32] continua como finalista e será comparada de novo com a [128 64] na etapa 5, já com a ativação e a taxa finais.
6. Uma rodada da etapa 4 com a [32] chegou a ser iniciada antes dessa decisão e foi interrompida (7 de 8 configurações). Os dados estão guardados em `parcial_etapa4_rede32/` e não foram usados na escolha.

## Etapa 4 — Ativação e taxa de aprendizado

**Fixo:** 32 faixas, com contexto, normalização max, camadas ocultas [128 64]. A camada de saída é sempre sigmoide.

A ativação e a taxa são testadas **juntas**, para que cada ativação seja comparada na sua melhor taxa. A ReLU não é limitada a [0, 1] e precisa de taxas bem menores que a sigmoide; por isso as faixas de taxa testadas são diferentes.

| Ativação | Fórmula | Taxas testadas |
|---|---|---|
| sigmoide | 1 / (1 + e^(−z)), saída entre 0 e 1 | 0,1 / 0,3 / 0,5 / 1,0 |
| ReLU | max(0, z) | 0,003 / 0,01 / 0,03 / 0,1 |

### Resumo (média ± desvio de 5 sementes, validação)

| Posição (palavras) | Ativação | Taxa | Palavras (%) | Palavras (de 27) | Sílabas (%) | Janelas (%) | Época média | Tempo médio |
|---|---|---|---|---|---|---|---|---|
| **1º** | **ReLU** | **0,03** | **88,9 ± 2,6** | **24,0** | **83,3 ± 0,6** | 87,4 ± 0,5 | 135 | 80 s |
| 2º | ReLU | 0,003 | 88,9 ± 3,7 | 24,0 | 82,1 ± 0,4 | 86,4 ± 0,4 | 792 (*) | 205 s |
| 3º | sigmoide | 0,5 | 88,1 ± 6,6 | 23,8 | 82,5 ± 0,8 | 86,8 ± 0,7 | 195 | 110 s |
| 4º | sigmoide | 0,3 | 85,9 ± 1,7 | 23,2 | 82,3 ± 0,6 | 86,6 ± 0,4 | 234 | 121 s |
| 5º | ReLU | 0,01 | 85,9 ± 4,8 | 23,2 | 83,3 ± 0,5 | 87,3 ± 0,4 | 326 | 117 s |
| 6º | sigmoide | 1,0 | 83,0 ± 4,2 | 22,4 | 82,0 ± 1,0 | 86,2 ± 0,9 | 168 | 99 s |
| 7º | ReLU | 0,1 | 81,5 ± 3,7 | 22,0 | 82,1 ± 0,7 | 86,5 ± 0,5 | 79 | 54 s |
| 8º | sigmoide | 0,1 | 80,0 ± 4,2 | 21,6 | 81,7 ± 0,7 | 86,2 ± 0,5 | 544 | 190 s |

(*) Com a taxa 0,003, a ReLU ainda estava melhorando no limite de 800 épocas. O treino não chegou ao fim: a taxa é pequena demais.

### Acerto por sílaba (%, média das sementes)

| Ativação | Taxa | di | rei | ta | es | quer | da |
|---|---|---|---|---|---|---|---|
| ReLU | 0,03 | 87 | 78 | 92 | 85 | 66 | 92 |
| ReLU | 0,003 | 87 | 77 | 89 | 83 | 65 | 92 |
| sigmoide | 0,5 | 85 | 74 | 87 | 89 | 71 | 90 |
| sigmoide | 0,3 | 82 | 76 | 89 | 88 | 67 | 90 |
| ReLU | 0,01 | 88 | 79 | 91 | 84 | 66 | 92 |
| sigmoide | 1,0 | 85 | 78 | 85 | 86 | 69 | 90 |
| ReLU | 0,1 | 87 | 77 | 86 | 88 | 62 | 93 |
| sigmoide | 0,1 | 81 | 76 | 86 | 89 | 66 | 92 |

### Por semente (palavras certas de 27 / sílabas %)

| Ativação | Taxa | Semente 1 | Semente 2 | Semente 3 | Semente 4 | Semente 5 |
|---|---|---|---|---|---|---|
| ReLU | 0,03 | 23 / 82,7 | 24 / 84,0 | 24 / 83,0 | 24 / 84,1 | 25 / 83,0 |
| ReLU | 0,003 | 23 / 82,7 | 24 / 82,1 | 23 / 82,1 | 25 / 82,2 | 25 / 81,4 |
| sigmoide | 0,5 | 22 / 82,3 | 25 / 82,4 | 24 / 82,3 | 22 / 81,7 | 26 / 83,9 |
| sigmoide | 0,3 | 23 / 82,4 | 24 / 82,0 | 23 / 81,6 | 23 / 82,2 | 23 / 83,2 |
| ReLU | 0,01 | 22 / 83,1 | 23 / 83,2 | 24 / 83,6 | 25 / 83,9 | 22 / 82,5 |
| sigmoide | 1,0 | 24 / 83,3 | 22 / 82,3 | 23 / 82,3 | 21 / 80,6 | 22 / 81,7 |
| ReLU | 0,1 | 21 / 82,3 | 23 / 82,9 | 22 / 81,0 | 23 / 82,2 | 21 / 82,1 |
| sigmoide | 0,1 | 22 / 81,4 | 22 / 82,0 | 23 / 82,1 | 20 / 82,5 | 21 / 80,7 |

### Conclusões

1. **A taxa de aprendizado importa mais que a ativação.** Nas duas ativações, a taxa ruim custa de 2 a 2,5 palavras.
   - **Taxa alta demais** (sigmoide 1,0, ReLU 0,1): o treino "pula" o mínimo. Ele para cedo (79 a 168 épocas) e acerta menos palavras.
   - **Taxa baixa demais** (sigmoide 0,1, ReLU 0,003): o treino fica lento. Leva de 544 a 800 épocas, e no caso da ReLU 0,003 não chega a terminar.
   - A melhor taxa fica no meio: **0,5 para a sigmoide** e **0,03 para a ReLU**.
2. **Na melhor taxa de cada uma, ReLU e sigmoide empatam nas palavras.** A ReLU 0,03 fez 24,0 de 27 e a sigmoide 0,5 fez 23,8. A diferença (0,8 ponto) é menor que o desvio.
3. **Pela regra (desempate pelas sílabas), vence a ReLU com taxa 0,03:** 83,3% nas sílabas, contra 82,5% da sigmoide 0,5. Outras vantagens:
   - é **mais estável**: desvio de ±2,6 contra ±6,6, e as 5 sementes acertaram de 23 a 25 palavras;
   - **treina mais rápido**: 135 épocas contra 195;
   - empata com a ReLU 0,003 nas palavras, mas é melhor nas sílabas e treina 6 vezes mais rápido (135 épocas contra 792).
4. **Vencedor da etapa 4: ReLU, taxa 0,03.**

## Etapa 5 — Confirmação

**Objetivo:** conferir se a arquitetura escolhida na etapa 3 ([128 64]) continua melhor que a finalista ([32]), agora com a ativação e a taxa finais.

**Fixo:** 32 faixas, com contexto, normalização max, ReLU, taxa 0,03.

### Resumo (média ± desvio de 5 sementes, validação)

| Camadas ocultas | Pesos | Palavras (%) | Palavras (de 27) | Sílabas (%) | Janelas (%) | Época média | Tempo médio |
|---|---|---|---|---|---|---|---|
| **[128 64]** | 29.319 | **88,9 ± 2,6** | **24,0** | **83,3 ± 0,6** | **87,4 ± 0,5** | **135** | 79 s |
| [32] | 5.383 | 84,4 ± 7,6 | 22,8 | 82,5 ± 1,2 | 86,7 ± 0,9 | 445 | 66 s |

### Acerto por sílaba (%, média das sementes)

| Camadas ocultas | di | rei | ta | es | quer | da |
|---|---|---|---|---|---|---|
| [128 64] | 87 | 78 | 92 | 85 | 66 | 92 |
| [32] | 86 | 78 | 88 | 86 | 64 | 93 |

### Por semente (palavras certas de 27 / sílabas %)

| Camadas ocultas | Semente 1 | Semente 2 | Semente 3 | Semente 4 | Semente 5 |
|---|---|---|---|---|---|
| [128 64] | 23 / 82,7 | 24 / 84,0 | 24 / 83,0 | 24 / 84,1 | 25 / 83,0 |
| [32] | 22 / 81,4 | 25 / 83,2 | 21 / 84,2 | 25 / 81,5 | 21 / 82,0 |

### Conclusões

1. **A [128 64] confirma a vantagem.** Ela foi melhor nas palavras (24,0 contra 22,8), nas sílabas (83,3% contra 82,5%) e nas janelas.
2. **A principal vantagem é a estabilidade.**
   - As 5 sementes da [128 64] acertaram de 23 a 25 palavras (desvio ±2,6).
   - As da [32] variaram de 21 a 25 (desvio ±7,6).
   - A [128 64] também converge em menos épocas: 135 contra 445.
3. A diferença na média de palavras ainda não é estatisticamente significativa (teste t de Welch, p = 0,27). Com 27 palavras de validação, cada palavra vale 3,7 pontos.
4. **Reprodutibilidade:** os resultados da [128 64] são idênticos aos da etapa 4 (mesmas sementes → mesmos números).
5. **Configuração final: energia, 32 faixas, com contexto, max, [128 64], ReLU, taxa 0,03.**

---

## Resultado final no teste

O [treinar_mlp.m](../../treinar_mlp.m) treina a configuração final com as mesmas 5 sementes e **guarda a rede com mais palavras de validação**: a semente 5, com 25 de 27. O **conjunto de teste é usado aqui pela primeira vez**.

### As 5 sementes no teste (só para mostrar a variação; a escolha foi pela validação)

| Semente | Palavras de validação (de 27) | Palavras de teste (de 29) | Sílabas no teste (%) | Janelas no teste (%) | Janelas no treino (%) | Época |
|---|---|---|---|---|---|---|
| 1 | 23 | 25 | 85,7 | 89,1 | 95,0 | 120 |
| 2 | 24 | 25 | 85,0 | 88,7 | 94,6 | 123 |
| 3 | 24 | 26 | 83,5 | 87,8 | 96,6 | 173 |
| 4 | 24 | 22 | 83,4 | 87,5 | 95,0 | 132 |
| **5 (escolhida)** | **25** | **25** | **85,1** | **88,3** | **95,2** | **126** |
| **Média ± desvio** | 24,0 ± 0,7 | **24,6 ± 1,5 (84,8%)** | **84,5 ± 1,0** | **88,3 ± 0,6** | 95,3 ± 0,8 | 135 |

### Rede escolhida (semente 5)

| Medida | Treino | Validação | Teste |
|---|---|---|---|
| Acerto por janela | 95,2% | 86,9% | **88,3%** |
| Palavras reconhecidas (programa 2) | — | 92,6% (25/27) | **86,2% (25/29)** |
| Acerto médio das 6 sílabas | — | — | **85,1%** |

### Matriz de confusão (janelas de teste; linha = sílaba dita, coluna = resposta da rede)

| dita \ rede | di | rei | ta | es | quer | da | silêncio | **acerto** |
|---|---|---|---|---|---|---|---|---|
| **di** | **89** | 2 | 0 | 3 | 3 | 0 | 0 | **92%** |
| **rei** | 3 | **64** | 6 | 0 | 0 | 0 | 0 | **88%** |
| **ta** | 0 | 9 | **91** | 1 | 1 | 1 | 0 | **88%** |
| **es** | 3 | 0 | 0 | **110** | 10 | 0 | 0 | **89%** |
| **quer** | 0 | 0 | 0 | 27 | **64** | 8 | 0 | **65%** |
| **da** | 0 | 0 | 6 | 2 | 5 | **115** | 2 | **88%** |
| **silêncio** | 0 | 0 | 0 | 0 | 0 | 0 | **161** | **100%** |

Figura: [matriz_confusao.png](../matriz_confusao.png).

### Programa 2 — reconhecimento de palavras de teste

**Parte 1, palavras isoladas:**

| Palavra dita | Reconheceu "direita" | Reconheceu "esquerda" | Não reconheceu | Acerto |
|---|---|---|---|---|
| direita (14) | **13** | 0 | 1 | 92,9% |
| esquerda (15) | 0 | **12** | 3 | 80,0% |
| **Total (29)** | | | | **86,2% (25/29)** |

**Parte 2, fala contínua** (todas as palavras de teste emendadas num único áudio, com silêncios entre elas):

| Faladas | Reconhecidas certas | Trocadas | Perdidas | Falsos alarmes | Acerto |
|---|---|---|---|---|---|
| 29 | 26 | **0** | 3 | **0** | **89,7%** |

Figura: [programa2_fluxo.png](../programa2_fluxo.png).

### Observações

1. **O sistema nunca troca uma palavra pela outra** e **nunca reconhece uma palavra no silêncio**. Todos os erros são palavras "perdidas": a máquina de estados não completou a sequência.
2. **O ponto fraco é o "quer"** (65%). Ele é confundido com o "es" (27 janelas), porque os dois têm a mesma vogal "e". É por isso que a maioria das palavras perdidas é "esquerda" (3 de 4).
3. **Generalização:** o acerto por janela cai de 95% no treino para 88% no teste. A diferença é moderada, e validação (86,9%) e teste (88,3%) ficam próximos, o que indica que a rede não decorou o treino.
4. **O resultado do teste é coerente com a validação:** média de 84,8% de palavras nas 5 sementes. A rede escolhida (86,2%) não é um caso de sorte isolado.
