# SoTreina iOS

App nativo do treino ao vivo + Live Activity. É construído com [xtool](https://github.com/xtool-org/xtool) no WSL, sem Mac e sem Xcode. O plano completo está em `../.plans/app-ios-nativo-spec.md`.

**Status: Fase 0 (spike).** O app tem login (email/senha → `POST /auth/token` → JWT no Keychain) e uma tela que inicia, estende e encerra uma Live Activity de descanso. Nada de treino real ainda.

## Estrutura

```
ios/
├── Package.swift          # pacote SwiftPM que o xtool builda (só iOS)
├── xtool.yml              # bundle ID, ícone, Info.plist, extensão
├── Support/               # Info.plist do app (NSSupportsLiveActivities) e da extensão
├── Resources/AppIcon.png  # 1024×1024, sem alfa
├── Sources/
│   ├── SoTreina/              # app (SwiftUI)
│   └── SoTreinaLiveActivity/  # extensão WidgetKit: UI da Live Activity
├── SoTreinaKit/           # pacote local de lógica pura, testável no Linux
└── scripts/               # deploy.sh (instalar), logs.sh (ver logs)
```

`SoTreinaKit` é um **pacote separado** de propósito. O pacote raiz só compila pra iOS, e não existe simulador fora do macOS. Então a lógica sem tela fica onde `swift test` roda no Linux:

```bash
cd ios/SoTreinaKit && swift test
```

## Setup (uma vez)

Os passos seguem a [documentação oficial](https://github.com/xtool-org/xtool/blob/main/Documentation/xtool.docc/Installation-Linux.md) (xtool 1.22).

### No Windows

1. **iPhone pro WSL, via serviço da Apple no Windows** ([origem](https://github.com/xtool-org/xtool/issues/19#issuecomment-2898986718)): o iPhone fica no Windows e o WSL fala com o usbmux da Apple pela rede. Instale o **Apple Devices** (Microsoft Store), abra, conecte o cabo e aceite "Confiar". No PowerShell **como administrador**:
   ```powershell
   # uma vez
   New-NetFirewallRule -DisplayName "WSL" -Direction Inbound -InterfaceAlias "vEthernet (WSL (Hyper-V firewall))" -Action Allow
   # de novo se o IP mudar (reboot): é o `ip route list default | awk '{print $3}'` do WSL
   netsh interface portproxy set v4tov4 listenport=27015 listenaddress=172.24.96.1 connectport=27015 connectaddress=127.0.0.1
   ```
   `scripts/usbmux.sh` (usado por `deploy.sh`/`logs.sh`) aponta `USBMUXD_SOCKET_ADDRESS` pra esse IP sozinho. Pra rodar `ideviceinfo`/`xtool` na mão, exporte `USBMUXD_SOCKET_ADDRESS="$(ip route list default | awk '{print $3}'):27015"`.
   - **Não use usbipd-win** (testado em 2026-10-22): o `ideviceinfo` funciona, mas o `xtool dev run` trava em `[Connecting] 100%` e o iPhone passa a responder `Mux error (-8)`. Se o iPhone estiver `Attached` no `usbipd list`, rode `usbipd detach --busid <BUSID>` pra ele voltar pro Windows.
2. **Xcode 27**: baixe o `.xip` em <https://developer.apple.com/download/all/?q=Xcode> **pelo navegador** (pede login com Apple ID). Anote o caminho. Pelo WSL, `C:\Users\<você>\Downloads` vira `/mnt/c/Users/<você>/Downloads`.

### No WSL

3. **Swift 6.4**: siga <https://swift.org/install/linux> (Ubuntu 24.04). Confira com `swift --version`.
4. **Ferramentas** (o `usbmuxd` do WSL não é usado, ver passo 1):
   ```bash
   sudo apt-get install libimobiledevice-utils
   USBMUXD_SOCKET_ADDRESS="$(ip route list default | awk '{print $3}'):27015" ideviceinfo -k DeviceName   # nome do iPhone
   ```
5. **xtool**:
   ```bash
   curl -fL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" -o xtool
   chmod +x xtool && sudo mv xtool /usr/local/bin/
   xtool setup
   ```
   - No login, escolha **1: Password** (Apple ID grátis). A opção API Key exige conta paga. Esse modo usa APIs privadas da Apple, e a própria documentação sugere um Apple ID descartável. O Apple ID de assinatura **não** precisa ser o que está logado no iPhone.
   - Depois ele pede o caminho do `Xcode.xip` e extrai o SDK (demora). Confira com `swift sdk list`, que deve listar `darwin`.
   - O SDK também instala **sem login**: `xtool sdk install /mnt/c/Users/<você>/Downloads/Xcode_27.xip`. Rode num shell que tenha o Swift do swiftly no PATH (`source ~/.local/share/swiftly/env.sh`): sem o `swiftc` no PATH ele extrai tudo e só falha no fim (`Could not find executable 'swiftc'`), e o `swift sdk list` continua vazio.
   - **Login por senha quebrado no xtool 1.22.2 (2026-10-21)**: depois do 2FA dá `This action cannot be completed at this time. (-80046)`, e tentativas seguintes nem recebem o código (às vezes `HTTP 403` em `verify/phone/put`). A Apple passou a recusar clientes que se identificam como Android ([xtool#378](https://github.com/xtool-org/xtool/issues/378)). Não insistir (risco de a Apple travar a conta).
   - **Contornado em 2026-10-22** com um build do [PR #380](https://github.com/xtool-org/xtool/pull/380) (anisette de Mac via `mac-ani.jkcoxson.com`), ainda sem release. O build nativo falha (libimobiledevice do Ubuntu velha demais), então foi feito com o Dockerfile do repo: `docker build --target build-xtool -t xtool-pr380-build .` na branch `omnisette-mac`, depois `docker cp` de `/xtool/Linux/packages/xtool-x86_64.AppImage`. O binário está em `~/.local/bin/xtool` (e `xtool-pr380`), o 1.22.2 guardado como `xtool-1.22.2`. Quando sair release com o fix, trocar pelo AppImage oficial.
   - O login precisa de um **terminal de verdade**: dentro do `!` do Claude Code o prompt falha com `Operation unsupported`. Use `xtool auth login --mode password` num terminal WSL, sem `-p` (a senha ficaria no histórico).

### No iPhone (na primeira instalação)

6. **Modo de Desenvolvedor**: Ajustes › Privacidade e Segurança › Modo de Desenvolvedor › ligar (o iPhone reinicia). A opção só aparece depois da primeira tentativa de instalar um app de desenvolvedor.
7. **Confiar no desenvolvedor**: Ajustes › Geral › VPN e Gerenciamento de Dispositivos › [seu Apple ID] › Confiar.

**Extensão vazia / `Can't find free space of LoadCommands for CodeSignature!`**: o linker descartava todo o código da Live Activity (entry point é o `_NSExtensionMain` da Foundation, nada referencia o nosso `@main`), e o zsign aborta numa extensão sem `__text`. O `Package.swift` força `-u _main` no target `SoTreinaLiveActivity` ([xtool#379](https://github.com/xtool-org/xtool/issues/379), fix upstream no [PR #320](https://github.com/xtool-org/xtool/pull/320)). Conferir: `llvm-objdump --section-headers xtool/SoTreina.app/PlugIns/SoTreinaLiveActivity.appex/SoTreinaLiveActivity | grep __text`.

## Uso

```bash
ios/scripts/deploy.sh   # build + assinatura + instalação (toda semana)
ios/scripts/logs.sh     # stream de logs do app e da extensão
idevicecrashreport -e -k /tmp/sotreina-crashes   # puxar crash logs
```

O app expira **7 dias** depois de cada instalação (Apple ID grátis). Rodar o `deploy.sh` de novo reinstala por cima e mantém os dados (token no Keychain, URL da API).

### Testar contra a API local

O campo "Servidor" da tela de login aceita outra URL. O iPhone não alcança o `localhost` do WSL. É preciso expor o NestJS na rede local: `netsh interface portproxy` no Windows, apontando a porta 3000 do IP de LAN do PC pro IP do WSL. Depois, use `http://<IP-do-PC>:3000`. HTTP sem TLS exige uma exceção de ATS no Info.plist, o que ainda não foi feito. Por isso o caminho mais simples na Fase 0 é testar contra produção.

## Checklist da Fase 0 (go/no-go)

- [x] `deploy.sh` instala e abre o app no iPhone
- [x] **Live Activity**: "Iniciar descanso de 60s" mostra o timer na Dynamic Island e na tela bloqueada, contando sozinho. "+15s" atualiza, e "Encerrar" remove. **Critério decisivo.**
- [x] Login com email/senha contra produção, e o nome aparece na tela inicial
- [x] Fechar e reabrir o app mantém o login (token no Keychain)
- [x] `logs.sh` mostra as linhas `GET auth/me -> 200` do app (só `.notice` pra cima: `.info`/`.debug` não passam pelo `idevicesyslog`)
- [ ] Tempo de um ciclo editar → `deploy.sh` → app aberto: ____ s
