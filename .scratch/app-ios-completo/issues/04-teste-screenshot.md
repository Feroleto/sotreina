# Teste: screenshot do iPhone pelo cabo

Type: task
Status: resolved
Blocked by:

## Question

Dá pra tirar screenshot do iPhone a partir do WSL (`idevicescreenshot` do libimobiledevice, ou `pymobiledevice3` se a Developer Disk Image personalizada do iOS 27 não montar)? A resposta define como cada fase é validada: screenshot do app lado a lado com a web mobile, ou o usuário descrevendo (spec §3, Fase S, teste 4; §8).

## Answer

**Sim, pelo cabo, sem root.** Testado em 2026-10-22 no iPhone 15 (iOS 27.0.1).

- `idevicescreenshot` (libimobiledevice 1.3.0) **não funciona**: o `screenshotr` do lockdown não existe mais desde o iOS 17 (`Could not start screenshotr service!`).
- `pymobiledevice3 developer dvt screenshot --userspace` (11.43.1) **funciona**: usa o serviço DVT do Instruments por um túnel CoreDevice em Python puro, pelo mesmo usbmux do Windows (`USBMUXD_SOCKET_ADDRESS`). Não precisa de root nem de montar a Developer Disk Image personalizada à mão. Leva ~1,7 s e gera um PNG nativo de 1179×2556.
- Feito: `ios/scripts/screenshot.sh [saida.png]` (faz `source` de `usbmux.sh`, igual ao `logs.sh`); `pymobiledevice3` instalado num venv em `~/.local/share/pymobiledevice3` com link em `~/.local/bin`; setup e resultado registrados no `ios/README.md` (passo 4 do setup, "Uso", "Screenshot pelo cabo").
- Consequência para a validação das fases: o agente consegue capturar a tela do app sozinho, e não depende de o usuário descrever o que vê. A comparação pode ser screenshot do app ao lado da web mobile (`run-sotreina`). O app precisa estar aberto na tela certa e o iPhone, desbloqueado; navegar no iPhone continua sendo papel do usuário.
