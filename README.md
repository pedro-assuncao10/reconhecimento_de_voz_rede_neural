# reconhecimento_de_voz_rede_neural

Reconhecimento das palavras DIREITA e ESQUERDA com uma MLP escrita à mão (MATLAB/GNU Octave).

## Ordem de execução

1. `segmentacao/segmentar_audios.m` — encontra as palavras nas gravações e corta as 3 sílabas (métodos tercos e energia) + silêncio → `segmentacao/saida/`
2. `rede/extrair_entradas.m` — FFT em faixas de 0–5 kHz (32 e 64), janelas deslizantes, divisão 70/20/10 → `rede/entradas/`
3. `rede/treinar_mlp.m` — treina e compara todas as combinações → `rede/resultados/`
4. `rede/programa2_reconhecer.m` — programa 2: janela deslizante + máquina de estados

## Pastas

- `material do professor/` — enunciado, slides e gravações originais (.aac)
- `segmentacao/audios_wav/` — gravações convertidas para WAV (o Octave não lê .aac)
- `segmentacao/saida/` — palavras inteiras, sílabas cortadas, silêncios, CSV dos cortes e figuras
- `rede/` — funções da MLP (`mlp_*.m`), extração, treino e programa 2

## Rodar no VS Code

`Ctrl+Shift+B` roda o arquivo .m aberto no GNU Octave (`.vscode/tasks.json`).
O caminho do Octave nesse arquivo é o do PC onde foi configurado; em outro PC, ajuste o campo `command`.
