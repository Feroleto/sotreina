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

1. **USB pro WSL**: instale o [usbipd-win](https://learn.microsoft.com/en-us/windows/wsl/connect-usb). Com o iPhone no cabo, rode no PowerShell **como administrador**:
   ```powershell
   usbipd list                       # ache o BUSID do "Apple Mobile Device"
   usbipd bind --busid <BUSID>       # uma vez
   usbipd attach --wsl --busid <BUSID>   # toda vez que reconectar o cabo
   ```
   Se o xtool der `AFCClient.Error.muxError`, use a alternativa de [repassar a conexão do iTunes](https://github.com/xtool-org/xtool/issues/19#issuecomment-2898986718) em vez do usbipd.
2. **Xcode 27**: baixe o `.xip` em <https://developer.apple.com/download/all/?q=Xcode> **pelo navegador** (pede login com Apple ID). Anote o caminho. Pelo WSL, `C:\Users\<você>\Downloads` vira `/mnt/c/Users/<você>/Downloads`.

### No WSL

3. **Swift 6.4**: siga <https://swift.org/install/linux> (Ubuntu 24.04). Confira com `swift --version`.
4. **usbmuxd + ferramentas**:
   ```bash
   sudo apt-get install usbmuxd libimobiledevice-utils
   ideviceinfo -k DeviceName    # deve mostrar o nome do iPhone (aceite "Confiar" no aparelho)
   ```
5. **xtool**:
   ```bash
   curl -fL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" -o xtool
   chmod +x xtool && sudo mv xtool /usr/local/bin/
   xtool setup
   ```
   - No login, escolha **1: Password** (Apple ID grátis). A opção API Key exige conta paga. Esse modo usa APIs privadas da Apple, e a própria documentação sugere um Apple ID descartável. O Apple ID de assinatura **não** precisa ser o que está logado no iPhone.
   - Depois ele pede o caminho do `Xcode.xip` e extrai o SDK (demora). Confira com `swift sdk list`, que deve listar `darwin`.

### No iPhone (na primeira instalação)

6. **Modo de Desenvolvedor**: Ajustes › Privacidade e Segurança › Modo de Desenvolvedor › ligar (o iPhone reinicia). A opção só aparece depois da primeira tentativa de instalar um app de desenvolvedor.
7. **Confiar no desenvolvedor**: Ajustes › Geral › VPN e Gerenciamento de Dispositivos › [seu Apple ID] › Confiar.

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

- [ ] `deploy.sh` instala e abre o app no iPhone
- [ ] **Live Activity**: "Iniciar descanso de 60s" mostra o timer na Dynamic Island e na tela bloqueada, contando sozinho. "+15s" atualiza, e "Encerrar" remove. **Critério decisivo.**
- [ ] Login com email/senha contra produção, e o nome aparece na tela inicial
- [ ] Fechar e reabrir o app mantém o login (token no Keychain)
- [ ] `logs.sh` mostra as linhas `GET auth/me → 200` do app
- [ ] Tempo de um ciclo editar → `deploy.sh` → app aberto: ____ s
