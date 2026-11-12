# Escolha da configuração da rede

Cada escolha da rede (entrada, normalização, camadas, ativação, taxa de aprendizado, corte das sílabas e tolerância do programa 2) foi feita a partir dos resultados abaixo.

Dados brutos:

- `escolha_energia/`: etapas 1 a 4. `etapa<N>_semente<S>.csv` tem uma linha por rede treinada; `resumo_etapa<N>.csv` e `.png` têm a média e o desvio entre as sementes.
- `validacao_cruzada/`: uma planilha por variante e por parte, e o `resumo.csv`.
- `resultados.csv`, `matriz_confusao.png`, `curva_treino.png`, `programa2_fluxo.png` e `modelo_final.mat`: rede final.

---

## 1. Dados e configuração fixa

| Item | Valor |
|---|---|
| Palavras gravadas | 68 "direita", 73 "esquerda", 114 trechos de silêncio |
| Corte das sílabas | vales de energia. 1º corte: vale mais fundo da curva de 250–6000 Hz, entre 15% e 50% da palavra. 2º corte: vale da curva de 1–5 kHz, entre 45% e 95% da palavra; no "direita" fica no **fundo** do vale, no "esquerda" no **início** do vale |
| Entrada da rede | janela de 150 ms com passo de 25 ms; FFT de 0 a 5 kHz dividida em faixas iguais |
| Rótulo de cada janela | sílaba onde cai o centro da janela |
| Janelas por classe | di 414, rei 625, ta 385, es 601, quer 593, da 545, silêncio 798 |
| Divisão (por repetição da palavra) | 60% treino / 20% validação / 20% teste |
| Amostras | treino 2.379, validação 796, teste 786 janelas |
| Palavras inteiras | validação 27, teste 29 |
| Treino | retropropagação, erro quadrático médio, momento 0,9, lote de 32, até 800 épocas, parada antecipada com paciência de 200 épocas |
| Programa 2 | mesma janela deslizante + máquina de estados (di → rei → ta, es → quer → da), silêncio máximo de 0,3 s no meio da palavra |

## 2. Protocolo e regra de escolha

- Cada configuração foi treinada com **5 sementes** (pesos iniciais e ordem das amostras diferentes). As tabelas mostram média ± desvio entre as sementes.
- Tudo foi medido na **validação**. O teste só foi usado no final, uma vez.
- Uma etapa por vez, cada uma usando o que as anteriores escolheram: entrada → normalização → arquitetura → ativação e taxa.
- **Regra de escolha:**
  1. vence quem reconhece mais **palavras** de validação;
  2. se a diferença nas palavras for menor que o desvio (empate), decidem as **sílabas**, se a diferença nelas for maior que o desvio;
  3. se empatar também nas sílabas, vence a opção **mais simples**.

---

## 3. Etapa 1: contexto e número de faixas

**Fixo:** 1 camada de 64, sigmoide, taxa 0,5, normalização db.

"Contexto" = a entrada leva, além das faixas da janela atual, as faixas das janelas 50 e 100 ms antes e depois (5 janelas). Com 32 faixas são 32 × 5 = 160 entradas.

| Faixas | Contexto | Entradas | Palavras (%) | Palavras (de 27) | Sílabas (%) | Janelas (%) |
|---|---|---|---|---|---|---|
| **32** | **sim** | **160** | **77,0 ± 6,6** | **20,8** | **83,7 ± 0,5** | **86,5 ± 0,3** |
| 32 | não | 32 | 74,1 ± 3,7 | 20,0 | 78,5 ± 0,3 | 82,7 ± 0,3 |
| 64 | não | 64 | 73,3 ± 4,1 | 19,8 | 78,0 ± 0,7 | 82,4 ± 0,5 |
| 64 | sim | 320 | 61,5 ± 21,0 | 16,6 | 78,6 ± 7,6 | 83,1 ± 5,2 |

**Acerto por sílaba (%):**

| Faixas | Contexto | di | rei | ta | es | quer | da |
|---|---|---|---|---|---|---|---|
| 32 | sim | 86 | 86 | 91 | 72 | 70 | 97 |
| 32 | não | 73 | 86 | 86 | 63 | 71 | 92 |
| 64 | não | 71 | 86 | 85 | 64 | 70 | 92 |
| 64 | sim | 84 | 88 | 74 | 70 | 80 | 77 |

**Por semente (palavras de 27 / sílabas %):**

| Faixas | Contexto | Semente 1 | Semente 2 | Semente 3 | Semente 4 | Semente 5 |
|---|---|---|---|---|---|---|
| 32 | sim | 19 / 84,1 | 22 / 84,4 | 23 / 83,2 | 19 / 83,5 | 21 / 83,4 |
| 32 | não | 21 / 78,8 | 20 / 78,2 | 21 / 78,7 | 19 / 78,7 | 19 / 78,1 |
| 64 | não | 21 / 78,0 | 19 / 77,0 | 19 / 77,8 | 21 / 78,9 | 19 / 78,2 |
| 64 | sim | 22 / 83,7 | **11 / 70,9** | 19 / 84,9 | 21 / 83,9 | **10 / 69,8** |

**Conclusões:**

1. Nas palavras, com e sem contexto empatam (20,8 contra 20,0, diferença menor que o desvio).
2. Nas sílabas, o contexto é melhor: +5,2 pontos, e todas as sementes com contexto (83,2–84,4%) superam todas as sem contexto (78,1–78,8%). O maior ganho é no "di" (+13) e no "es" (+9).
3. 64 faixas com contexto é instável: em 2 das 5 sementes o treino falhou e parou cedo (10 e 11 palavras). Nas outras, o resultado é igual ao de 32 faixas.
4. **Vencedor: 32 faixas, com contexto.** A validação cruzada (seção 7) confirmou o contexto com mais palavras.

---

## 4. Etapa 2: normalização

**Fixo:** 32 faixas, com contexto, 1 camada de 64, sigmoide, taxa 0,5.

- **max:** divide cada janela pelo seu maior valor (fica entre 0 e 1).
- **db:** o mesmo, em decibéis, de −60 a 0 dB, levado para 0 a 1.
- **zscore:** para cada faixa, subtrai a média e divide pelo desvio do treino.

| Normalização | Palavras (%) | Palavras (de 27) | Sílabas (%) | Janelas (%) | Época média |
|---|---|---|---|---|---|
| **max** | 74,1 ± 5,2 | 20,0 | **86,5 ± 0,7** | **88,9 ± 0,6** | 266 |
| db | 77,0 ± 6,6 | 20,8 | 83,7 ± 0,5 | 86,5 ± 0,3 | 87 |
| zscore | 8,1 ± 18,2 | 2,2 | 53,8 ± 12,2 | 63,4 ± 9,0 | 39 |

**Acerto por sílaba (%):**

| Normalização | di | rei | ta | es | quer | da |
|---|---|---|---|---|---|---|
| max | 91 | 91 | 89 | 76 | 76 | 96 |
| db | 86 | 86 | 91 | 72 | 70 | 97 |
| zscore | 80 | 68 | 37 | 67 | 32 | 40 |

**Por semente (palavras de 27 / sílabas %):**

| Normalização | Semente 1 | Semente 2 | Semente 3 | Semente 4 | Semente 5 |
|---|---|---|---|---|---|
| max | 21 / 86,9 | 19 / 86,4 | 19 / 87,1 | 19 / 85,3 | 22 / 86,7 |
| db | 19 / 84,1 | 22 / 84,4 | 23 / 83,2 | 19 / 83,5 | 21 / 83,4 |
| zscore | 0 / 42,1 | 11 / 71,9 | 0 / 43,1 | 0 / 54,1 | 0 / 57,9 |

**Conclusões:**

1. zscore é descartado: em 4 das 5 sementes não reconheceu nenhuma palavra.
2. max contra db: nas palavras, empate (0,8 palavra de diferença, menor que o desvio). Nas sílabas, o max é melhor: +2,8 pontos, e todas as sementes do max (85,3–87,1%) superam todas as do db (83,2–84,4%).
3. **Vencedor: max.**

---

## 5. Etapa 3: camadas ocultas

**Fixo:** 32 faixas, com contexto, max, sigmoide, taxa 0,5. Todas as opções são em funil (cada camada com metade da anterior).

| Camadas ocultas | Nº de camadas | Pesos | Palavras (%) | Palavras (de 27) | Sílabas (%) | Janelas (%) | Época média | Tempo médio |
|---|---|---|---|---|---|---|---|---|
| [256 128 64 32] | 4 | 84.679 | **87,4 ± 4,2** | **23,6** | 85,3 ± 1,0 | 88,2 ± 1,0 | 401 | 365 s |
| [128 64 32] | 3 | 31.175 | 85,9 ± 1,7 | 23,2 | 85,5 ± 0,6 | 88,2 ± 0,6 | 251 | 141 s |
| **[64 32]** | **2** | **12.615** | **85,9 ± 6,1** | **23,2** | **87,2 ± 1,0** | **89,5 ± 0,8** | 187 | 68 s |
| [32] | 1 | 5.383 | 83,7 ± 5,0 | 22,6 | 86,7 ± 0,7 | 89,0 ± 0,5 | 194 | 38 s |
| [128 64] | 2 | 29.319 | 83,0 ± 4,2 | 22,4 | 87,2 ± 0,9 | 89,5 ± 0,6 | 242 | 118 s |
| [64] | 1 | 10.759 | 74,1 ± 5,2 | 20,0 | 86,5 ± 0,7 | 88,9 ± 0,6 | 266 | 57 s |
| [128] | 1 | 21.511 | 65,9 ± 19,1 | 17,8 | 83,6 ± 6,2 | 87,1 ± 3,7 | 340 | 97 s |

**Acerto por sílaba (%):**

| Camadas ocultas | di | rei | ta | es | quer | da |
|---|---|---|---|---|---|---|
| [256 128 64 32] | 92 | 90 | 80 | 79 | 76 | 95 |
| [128 64 32] | 92 | 88 | 83 | 78 | 81 | 93 |
| [64 32] | 91 | 91 | 89 | 79 | 79 | 95 |
| [32] | 92 | 87 | 90 | 77 | 79 | 95 |
| [128 64] | 90 | 90 | 88 | 78 | 81 | 95 |
| [64] | 91 | 91 | 89 | 76 | 76 | 96 |
| [128] | 92 | 92 | 70 | 76 | 76 | 95 |

**Por semente (palavras de 27 / sílabas %):**

| Camadas ocultas | Semente 1 | Semente 2 | Semente 3 | Semente 4 | Semente 5 |
|---|---|---|---|---|---|
| [256 128 64 32] | 24 / 85,2 | 25 / 86,7 | 24 / 84,8 | 23 / 85,8 | 22 / 84,0 |
| [128 64 32] | 23 / 85,5 | 23 / 85,3 | 23 / 86,5 | 24 / 84,9 | 23 / 85,2 |
| [64 32] | 22 / 86,9 | 25 / 86,6 | 24 / 88,9 | 21 / 86,3 | 24 / 87,4 |
| [32] | 22 / 87,6 | 24 / 86,2 | 24 / 87,4 | 22 / 86,0 | 21 / 86,6 |
| [128 64] | 23 / 87,4 | 22 / 87,1 | 22 / 88,5 | 21 / 86,4 | 24 / 86,4 |
| [64] | 21 / 86,9 | 19 / 86,4 | 19 / 87,1 | 19 / 85,3 | 22 / 86,7 |
| [128] | 21 / 86,1 | **9 / 72,5** | 22 / 87,4 | 18 / 85,5 | 19 / 86,6 |

**Conclusões:**

1. Mais de uma camada ajuda nas palavras: as redes de 2, 3 e 4 camadas ficaram entre 22,4 e 23,6 palavras; as de 1 camada larga ([64], [128]) ficaram entre 17,8 e 20,0.
2. As 5 primeiras empatam nas palavras: estão a no máximo 1,2 palavra uma da outra, dentro do desvio.
3. Nas sílabas, as redes de 2 camadas são as melhores (87,2%). As de 3 e 4 camadas ficam em 85,3–85,5%, cerca de 2 pontos abaixo, além do desvio.
4. **Vencedor: [64 32].** Empata nas palavras com a de 4 camadas (23,2 contra 23,6), ganha nas sílabas (87,2% contra 85,3%), tem 7 vezes menos pesos e treina 5 vezes mais rápido. Empata em tudo com a [128 64] e é a mais simples das duas.

---

## 6. Etapa 4: função de ativação e taxa de aprendizado

**Fixo:** 32 faixas, com contexto, max, [64 32]. Cada ativação foi testada com 4 taxas, para ser comparada na sua melhor taxa. A camada de saída é sempre sigmoide.

| Ativação | Taxa | Palavras (%) | Palavras (de 27) | Sílabas (%) | Janelas (%) | Época média |
|---|---|---|---|---|---|---|
| **sigmoide** | **0,5** | **85,9 ± 6,1** | **23,2** | **87,2 ± 1,0** | **89,5 ± 0,8** | 187 |
| sigmoide | 0,3 | 85,9 ± 6,1 | 23,2 | 87,1 ± 0,5 | 89,3 ± 0,5 | 228 |
| ReLU | 0,003 | 85,9 ± 4,1 | 23,2 | 85,7 ± 0,8 | 88,2 ± 0,6 | 783 (*) |
| ReLU | 0,01 | 85,9 ± 4,8 | 23,2 | 85,6 ± 0,8 | 88,2 ± 0,6 | 306 |
| sigmoide | 1,0 | 84,4 ± 3,1 | 22,8 | 86,3 ± 1,4 | 88,8 ± 1,1 | 179 |
| ReLU | 0,03 | 83,7 ± 7,7 | 22,6 | 86,9 ± 0,7 | 89,1 ± 0,5 | 162 |
| ReLU | 0,1 | 82,2 ± 3,1 | 22,2 | 86,4 ± 0,9 | 88,8 ± 0,6 | 105 |
| sigmoide | 0,1 | 79,3 ± 4,2 | 21,4 | 86,9 ± 0,7 | 89,2 ± 0,6 | 567 |

(*) Com taxa 0,003 a rede ainda estava melhorando no limite de 800 épocas.

**Acerto por sílaba (%):**

| Ativação | Taxa | di | rei | ta | es | quer | da |
|---|---|---|---|---|---|---|---|
| sigmoide | 0,5 | 91 | 91 | 89 | 79 | 79 | 95 |
| sigmoide | 0,3 | 93 | 90 | 88 | 77 | 77 | 96 |
| ReLU | 0,003 | 92 | 87 | 86 | 75 | 79 | 95 |
| ReLU | 0,01 | 91 | 89 | 85 | 76 | 77 | 95 |
| sigmoide | 1,0 | 93 | 90 | 85 | 81 | 76 | 92 |
| ReLU | 0,03 | 93 | 89 | 90 | 79 | 75 | 95 |
| ReLU | 0,1 | 92 | 89 | 86 | 79 | 78 | 94 |
| sigmoide | 0,1 | 91 | 90 | 87 | 77 | 81 | 95 |

**Por semente (palavras de 27 / sílabas %):**

| Ativação | Taxa | Semente 1 | Semente 2 | Semente 3 | Semente 4 | Semente 5 |
|---|---|---|---|---|---|---|
| sigmoide | 0,5 | 22 / 86,9 | 25 / 86,6 | 24 / 88,9 | 21 / 86,3 | 24 / 87,4 |
| sigmoide | 0,3 | 25 / 87,1 | 22 / 87,1 | 22 / 86,9 | 22 / 86,6 | 25 / 88,0 |
| ReLU | 0,003 | 25 / 85,2 | 22 / 86,8 | 23 / 85,0 | 23 / 85,4 | 23 / 86,3 |
| ReLU | 0,01 | 25 / 85,2 | 24 / 86,6 | 23 / 84,6 | 22 / 85,2 | 22 / 86,2 |
| sigmoide | 1,0 | 22 / 86,2 | 24 / 87,1 | 23 / 84,5 | 22 / 85,3 | 23 / 88,1 |
| ReLU | 0,03 | 23 / 87,4 | 24 / 87,4 | 19 / 86,1 | 23 / 86,0 | 24 / 87,4 |
| ReLU | 0,1 | 22 / 85,5 | 22 / 87,3 | 23 / 87,0 | 23 / 86,7 | 21 / 85,2 |
| sigmoide | 0,1 | 23 / 86,6 | 21 / 88,0 | 20 / 86,2 | 22 / 86,3 | 21 / 87,1 |

**Conclusões:**

1. A taxa de aprendizado pesa mais que a ativação. Taxa baixa demais (sigmoide 0,1, ReLU 0,003) leva de 567 a 800 épocas; taxa alta demais (ReLU 0,1, sigmoide 1,0) acerta menos palavras.
2. Nas palavras, 4 configurações empatam com 23,2 de 27: sigmoide 0,5, sigmoide 0,3, ReLU 0,003 e ReLU 0,01.
3. Nas sílabas, a sigmoide é melhor que a ReLU: 87,2% contra 85,7%, diferença maior que o desvio.
4. **Vencedor: sigmoide, taxa 0,5.** Empata com a 0,3 em tudo e converge em menos épocas (187 contra 228).

Como a ativação e a taxa vencedoras são as mesmas usadas na etapa 3, não foi preciso repetir a comparação das camadas: com as mesmas sementes, os números seriam os mesmos da etapa 3.

**Configuração escolhida: 32 faixas, com contexto, max, [64 32], sigmoide, taxa 0,5** (160 → 64 → 32 → 7).

---

## 7. Validação cruzada (5 partes, 112 palavras)

**Por que:** com 27 palavras de validação e 29 de teste, cada palavra vale de 3,4 a 3,7 pontos, e o resultado depende de quais palavras caíram em cada conjunto. Na primeira medida do teste, a rede escolhida acertou 86% das palavras na validação e só 69% no teste. Para saber qual número era o verdadeiro, as comparações mais importantes foram refeitas com mais palavras.

**Como:** as 29 palavras de teste ficam de fora. As outras 112 palavras (e os silêncios) são divididas em 5 partes, sorteadas por repetição. A rede é treinada 5 vezes; a cada vez, uma parte é a validação e as outras 4 são o treino. No fim, cada uma das 112 palavras foi validação uma vez. Em todas as variantes, as partes e a semente são as mesmas.

Em cada parte, as palavras também foram medidas com a máquina de estados tolerando 0, 1, 2 ou 3 janelas seguidas fora da sequência antes de abandonar a palavra (ver seção 8).

### Variantes comparadas

| Variante | Corte das sílabas | Entrada | Rede |
|---|---|---|---|
| **energia** (escolhida) | vales de energia, rei\|ta no fundo do vale | 32 faixas + contexto | [64 32], sigmoide 0,5, max |
| energia, rei no início | vales de energia, rei\|ta no início do vale | 32 faixas + contexto | igual |
| energia sem contexto | igual à escolhida | 32 faixas, só a janela atual | igual |
| terços | 3 pedaços de mesma duração | 32 faixas + contexto | [128 64], ReLU 0,03, max (a rede escolhida para terços nas mesmas etapas) |

### Palavras reconhecidas (das 112)

| Tolerância (janelas) | energia | energia, rei no início | energia sem contexto | terços |
|---|---|---|---|---|
| 0 | 90 (80,4%) | 85 (75,9%) | 73 (65,2%) | 91 (81,2%) |
| 1 | 96 (85,7%) | 92 (82,1%) | 84 (75,0%) | 96 (85,7%) |
| **2** | **102 (91,1%)** | 97 (86,6%) | 88 (78,6%) | 99 (88,4%) |
| 3 | 102 (91,1%) | 98 (87,5%) | 91 (81,2%) | 100 (89,3%) |

### Por parte (palavras certas, tolerância 0 / tolerância 2)

| Parte | Palavras | energia | energia, rei no início | energia sem contexto | terços |
|---|---|---|---|---|---|
| 1 | 23 | 18 / 23 | 18 / 21 | 17 / 18 | 20 / 21 |
| 2 | 23 | 18 / 20 | 16 / 17 | 15 / 18 | 18 / 18 |
| 3 | 23 | 17 / 17 | 16 / 19 | 14 / 16 | 17 / 20 |
| 4 | 22 | 20 / 21 | 18 / 20 | 15 / 20 | 18 / 19 |
| 5 | 21 | 17 / 21 | 17 / 20 | 12 / 16 | 18 / 21 |

### Acerto das sílabas (média das 5 partes, %)

| Variante | di | rei | ta | es | quer | da | **Média** |
|---|---|---|---|---|---|---|---|
| **energia** | 88 | 86 | 87 | 79 | 87 | 96 | **87,1** |
| energia, rei no início | 88 | 84 | 89 | 79 | 83 | 95 | 86,2 |
| energia sem contexto | 67 | 82 | 80 | 68 | 74 | 90 | 76,8 |
| terços | 86 | 79 | 88 | 79 | 71 | 93 | 82,7 |

### Conclusões

1. **Com 112 palavras, a rede de energia acerta 80,4% sem tolerância**, e não 69%. As partes variam de 74% a 87%: os 69% vieram de um conjunto pequeno de 29 palavras que, por acaso, foi difícil para essa rede.
2. **Energia contra terços:** empate nas palavras sem tolerância (90 contra 91, uma palavra de diferença), energia melhor com tolerância 2 (102 contra 99) e nas sílabas (87,1% contra 82,7%; no "quer", +16). Energia corta onde a boca fecha na consoante; terços corta num ponto fixo. **Fica energia.**
3. **O corte rei|ta no fundo do vale é melhor que no início:** +5 palavras sem tolerância e com tolerância 2. Isso confirma o ajuste feito ouvindo os trechos (no início do vale o "rei" ficava curto demais).
4. **O contexto é necessário:** sem ele, a rede perde 17 palavras sem tolerância (65,2% contra 80,4%) e 14 com tolerância 2 (78,6% contra 91,1%), em todas as 5 partes. Nas sílabas a perda é de 10,3 pontos, maior no "di" (−21), no "quer" (−13) e no "es" (−11).
5. **Tolerar 2 janelas soltas** dá +12 palavras na energia (80,4% → 91,1%). Tolerar 3 não acrescenta nada. A tolerância não substitui o contexto: sem contexto e com tolerância 3, a rede (81,2%) fica no nível da rede com contexto sem tolerância (80,4%).

As 27 palavras de validação usadas nas etapas 1 a 4 fazem parte das 112, então esses números podem ser um pouco otimistas, igualmente para todas as variantes. As 29 palavras de teste não foram usadas.

---

## 8. Tolerância no programa 2

O programa 2 classifica o áudio janela por janela (uma a cada 25 ms). Uma sílaba falada ocupa de 6 a 10 janelas seguidas, por exemplo:

```
di di di di di | rei rei rei QUER rei rei rei rei | ta ta ta ta ta
```

Sem tolerância, uma única janela errada no meio da palavra (o "QUER" acima) faz a máquina de estados abandonar a palavra. Com tolerância de 2, ela ignora até 2 janelas seguidas fora da sequência (50 ms) e continua esperando a sílaba certa.

- A ordem exigida pelo enunciado não muda: di → rei → ta e es → quer → da.
- Uma sílaba trocada de verdade ("di quer ta", "di quer rei ta") continua reprovada: o "quer" falado dura mais de 2 janelas.
- Ganho medido na validação cruzada: 90 → 102 palavras de 112.

**Decisão:** o programa 2 usa tolerância de 2 janelas (`p.max_fora = 2`). As etapas 1 a 4 foram medidas sem tolerância.

---

## 9. Resultado final no teste

Configuração: corte por energia, 32 faixas com contexto, max, [64 32], sigmoide, taxa 0,5, tolerância de 2 janelas. Cinco sementes treinadas; a escolhida é a de mais palavras na validação (semente 5, 26 de 27). Depois da escolha, as 29 palavras de teste foram medidas uma única vez.

### As 5 sementes

| Semente | Palavras validação (de 27) | Palavras teste (de 29) | Janelas teste | Sílabas teste | Época |
|---|---|---|---|---|---|
| 1 | 25 | 24 | 87,2% | 83,9% | 185 |
| 2 | 25 | 24 | 88,7% | 85,7% | 209 |
| 3 | 24 | 24 | 85,9% | 82,6% | 220 |
| 4 | 23 | 25 | 86,4% | 82,9% | 178 |
| **5 (escolhida)** | **26** | **24** | 85,5% | 82,4% | 142 |
| Média | 24,6 (91,1%) | **24,2 (83,4%)** | 86,7% | 83,5% | |

O teste varia só entre 24 e 25 palavras de uma semente para outra.

### Rede escolhida (semente 5)

| Medida | Resultado |
|---|---|
| Janelas: treino / validação / teste | 95,6% / 89,6% / 85,5% |
| Palavras isoladas de teste | **24 de 29 (82,8%)**: direita 12 de 14, esquerda 12 de 15; nenhuma trocada, 5 não reconhecidas |
| Fala contínua (palavras de teste emendadas com silêncio) | **27 de 29 (93,1%)**: 0 trocadas, 2 perdidas, 0 falsos alarmes |

### Matriz de confusão (janelas de teste)

| dito \ resposta | di | rei | ta | es | quer | da | silêncio | acerto |
|---|---|---|---|---|---|---|---|---|
| di | **64** | 10 | 0 | 5 | 3 | 0 | 0 | 78% |
| rei | 5 | **101** | 0 | 2 | 7 | 0 | 0 | 88% |
| ta | 0 | 5 | **69** | 0 | 2 | 0 | 0 | 91% |
| es | 7 | 2 | 0 | **99** | 12 | 0 | 0 | 82% |
| quer | 3 | 5 | 1 | 32 | **76** | 6 | 0 | 62% |
| da | 0 | 0 | 1 | 0 | 4 | **102** | 2 | 94% |
| silêncio | 0 | 0 | 0 | 0 | 0 | 0 | **161** | 100% |

A troca mais comum é "quer" respondido como "es" (32 janelas): são sílabas vizinhas da mesma palavra, e a fronteira entre elas é a menos nítida.

O teste (83,4% na média das sementes) ficou próximo da validação cruzada com a mesma tolerância (91,1% em 112 palavras). A diferença que sobra é de poucas palavras num conjunto de 29.
