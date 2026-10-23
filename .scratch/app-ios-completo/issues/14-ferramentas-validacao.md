# Ferramentas da validação visual

Type: task
Status: resolved
Blocked by:

## Question

Montar o ferramental decidido em [Formato da validação visual por fase](12-validacao-visual.md): (1) opção `--iphone` no `.claude/skills/run-sotreina/driver.mjs` (393×852, `deviceScaleFactor: 3`, toque) e a menção no `SKILL.md`; (2) `ios/validation/` no `.gitignore`; (3) um gerador da galeria `ios/validation/<fase>/index.html` a partir das linhas do checklist da fase no `ios/README.md` (formato da linha a definir aqui, junto do gerador), sem dependência nova; (4) um checklist vazio de exemplo da Fase S no README, no formato decidido.

## Answer

Feito em 2026-10-22.

1. **Driver** (`.claude/skills/run-sotreina/driver.mjs`, fora do git como todo o `.claude/`): `--iphone` (393×852, `deviceScaleFactor: 3`, toque; implica `--mobile`) gera PNG de 1179×2556, igual ao `screenshot.sh`. Também entrou `--file <path.png>`, que grava a captura inicial num caminho exato, pra o par web cair direto em `ios/validation/<fase>/NN-web.png`. Os dois estão documentados no `SKILL.md`.
2. **`.gitignore`**: `ios/validation/`.
3. **Gerador** `ios/scripts/gallery.mjs <fase>` (Node puro, sem dependência): lê a tabela `### Fase <fase>` da seção `## Validação visual` do `ios/README.md` e escreve `ios/validation/<fase>/index.html`. Cada par mostra app | web, a legenda "tela · estado", os argumentos do driver e um selo de resultado (a conferir / ✓ / desvio aceito / bug). Imagem ausente vira "falta captura", e Web `—` vira "só app". A página segue claro/escuro do sistema.
   **Formato da linha**: `| # | Tela | Estado | Web | Resultado |`. O `#` é o prefixo das imagens (`03-app.png`, `03-web.png`). Web traz os argumentos do driver em crase, ou `—`. Resultado fica vazio, ou `✓`, `desvio aceito: <motivo>` ou `bug: <o quê>`.
4. **README**: seção "Validação visual" com o formato, os comandos (captura do app, captura da web, galeria e `explorer.exe` pra abrir no Windows) e a tabela vazia da Fase S.

De passagem, o `ios/scripts/screenshot.sh` passou a criar a pasta de destino (o `pymobiledevice3` falhava com o diretório inexistente).

**Conferido** de ponta a ponta numa cópia no scratchpad, com um README de teste de 3 linhas na Fase S e 1 na Fase T: par real (iPhone pelo cabo + web `--iphone --file`), os dois em 1179×2556, galeria renderizada com os três selos, a linha "só app", e nenhuma linha da Fase T vazando pra S.
