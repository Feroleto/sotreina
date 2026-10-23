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
│   ├── SoTreinaDesign/        # design system Monolito (cores, fontes, componentes), usado pelo app e pela extensão
│   └── SoTreinaLiveActivity/  # extensão WidgetKit: UI da Live Activity
├── SoTreinaKit/           # pacote local de lógica pura, testável no Linux
└── scripts/               # deploy.sh (instalar), logs.sh (ver logs), screenshot.sh (capturar tela), gallery.mjs (galeria de validação)
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
   # screenshot.sh: pymobiledevice3 num venv do usuário (sem pipx no Ubuntu)
   python3 -m venv ~/.local/share/pymobiledevice3
   ~/.local/share/pymobiledevice3/bin/pip install pymobiledevice3
   ln -s ~/.local/share/pymobiledevice3/bin/pymobiledevice3 ~/.local/bin/
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
ios/scripts/screenshot.sh [saida.png]   # screenshot do iPhone pelo cabo
ios/scripts/launch.sh [CHAVE=VALOR ...]  # reabre o app com variáveis de ambiente
idevicecrashreport -e -k /tmp/sotreina-crashes   # puxar crash logs
```

**Desinstalar um app do xtool** exige o bundle ID **com o prefixo que o xtool acrescenta** na conta grátis (`XTL-<team>.`, ex. `XTL-KBVDP58W3Z.com.feroleto.sotreina`). Com o ID do `xtool.yml`, `xtool uninstall` responde `Success!` sem remover nada. O ID real aparece em `pymobiledevice3 apps list -t User`.

O app expira **7 dias** depois de cada instalação (Apple ID grátis). Rodar o `deploy.sh` de novo reinstala por cima e mantém os dados (token no Keychain, URL da API).

### Screenshot pelo cabo

Testado em 2026-10-22 (iPhone 15, iOS 27.0.1, pymobiledevice3 11.43.1): `screenshot.sh` devolve um PNG na resolução nativa (1179×2556) em cerca de 1,7 s, **sem root e sem montar a Developer Disk Image à mão**. O `idevicescreenshot` do libimobiledevice **não funciona**: o serviço `screenshotr` do lockdown não existe mais desde o iOS 17 (`Could not start screenshotr service!`). O script usa o serviço DVT do Instruments por um túnel CoreDevice em espaço de usuário (`pymobiledevice3 developer dvt screenshot --userspace`), pelo mesmo usbmux do Windows que o `deploy.sh` usa. Precisa do Modo de Desenvolvedor ligado e da tela desbloqueada pra mostrar o app.

### Abrir o app com variáveis de ambiente

Testado em 2026-10-22 (iPhone 15, iOS 27.0.1): `scripts/launch.sh [CHAVE=VALOR ...]` encerra o app se estiver aberto e o abre de novo pelo mesmo túnel do `screenshot.sh` (`pymobiledevice3 developer dvt launch --userspace --env ...`), em ~5 s. **As variáveis chegam ao processo**: com `CFNETWORK_DIAGNOSTICS=3` o log do app passou a ter linhas `CFNetwork Diagnostics`, e sem a variável não teve nenhuma. Elas valem só pra esse lançamento. Abrir o app pela Tela de Início depois disso não passa variável nenhuma.

- O bundle ID é o que o xtool instala (`XTL-KBVDP58W3Z.com.feroleto.sotreina`), não o do `xtool.yml`. Pra trocar, use `SOTREINA_BUNDLE_ID`.
- O `deploy.sh` builda em **debug** por padrão (`xtool dev run`), então um modo de validação atrás de `#if DEBUG` existe no app instalado.
- O app lê `SOTREINA_SCREEN`/`SOTREINA_THEME`/`SOTREINA_LANG` (ver "Modo de validação" em "Validação visual").

### Testar contra a API local

O campo "Servidor" da tela de login aceita outra URL. O iPhone não alcança o `localhost` do WSL. É preciso expor o NestJS na rede local: `netsh interface portproxy` no Windows, apontando a porta 3000 do IP de LAN do PC pro IP do WSL. Depois, use `http://<IP-do-PC>:3000`. HTTP sem TLS exige uma exceção de ATS no Info.plist, o que ainda não foi feito. Por isso o caminho mais simples na Fase 0 é testar contra produção.

## Live Activity

- **Botões são links, não App Intents.** `Button(intent:)` precisa dos metadados de App Intents (`Metadata.appintents`) que o Xcode extrai no build, e o xtool não gera (PR xtool#217 com um gerador pra Linux foi fechada sem merge). Testado em 2026-10-22: o toque não faz nada, e a extensão loga `Failed to fetch metadata`. Por isso **+15s**, **Pular** e **✓** são `sotreina://` (`ActivityLink` no `SoTreinaKit`) que abrem o app na ação — com o iPhone bloqueado, pede Face ID. Se o xtool passar a gerar os metadados, dá pra voltar a botões que agem sem desbloquear.
- **Problema conhecido**: quando o descanso acaba com o iPhone bloqueado, a contagem fica parada em `0:00` em vez de voltar pra "Em série". O `staleDate` marcado no fim do descanso não faz o iOS redesenhar na hora, e o app suspenso não consegue mandar o update. Aceito por enquanto.

## Localização (PT/EN)

Testado em 2026-10-22 num app mínimo à parte, instalado no iPhone e depois removido:

- **`.xcstrings` não funciona.** O build chama o `xcstringstool` do Xcode, que o xtool não tem (`xtool/.xtool-tmp/xcstringstool is not an executable file`).
- **`Localizable.strings` + `Localizable.stringsdict` em `pt.lproj`/`en.lproj` funcionam**, como recurso SwiftPM (`resources: [.process("Resources")]`). Os arquivos são copiados como estão pro bundle do módulo (`<App>.app/<Pacote>_<Target>.bundle/{pt,en}.lproj/`), e o plural via `.stringsdict` resolve certo (`1 série`/`2 séries`, `1 set`/`2 sets`).
- **O idioma troca em runtime, sem reiniciar.** Um seletor Auto/PT/EN (`@AppStorage`) na raiz atualiza a tela na hora, com qualquer uma destas três formas:
  - `Text("chave", bundle: .module)` com `.environment(\.locale, Locale(identifier: lang))` na raiz. O SwiftUI escolhe o `.lproj` pelo `\.locale`. É a forma mais simples pras views.
  - `Text("chave", bundle: bundleDoIdioma)`, em que `bundleDoIdioma` é `Bundle(path: Bundle.module.path(forResource: lang, ofType: "lproj")!)`.
  - `String(localized: "chave", bundle: bundleDoIdioma)` **fora das views** (mensagens de erro, notificações). Aqui o `\.locale` não chega, então só o bundle do `.lproj` garante o idioma escolhido.
- O "Auto" escolhe pelo `Locale.preferredLanguages.first`: começa com `pt` → PT; qualquer outro idioma → EN, a mesma regra da web. A escolha é sempre explícita, então o `defaultLocalization` do pacote não decide o fallback.
- Não testado: a Live Activity (outro processo, não vê o `@AppStorage` do app) e o seletor de idioma por app nos Ajustes do iOS (exigiria `CFBundleLocalizations` no Info.plist).

## Design system (Monolito)

Target `SoTreinaDesign` (`Sources/SoTreinaDesign/`), dependência do app **e** da extensão da Live Activity. Não é produto: o xtool copia o bundle de recursos dele pros dois (`SoTreina.app/SoTreina_SoTreinaDesign.bundle` e `PlugIns/SoTreinaLiveActivity.appex/SoTreina_SoTreinaDesign.bundle`), então a extensão registra as fontes no próprio processo. Conferido no iPhone em 2026-10-22: a Live Activity aparece em Geist/Geist Mono e mostarda.

- **Cores**: os valores são do Kit (`Monolito`, hex claro/escuro). O `MonolitoTests` lê o `client/src/index.css` e falha se algum token espelhado divergir da web. `--acc-tx` do claro é derivado com `color-mix` na web, então fica pré-calculado (`#674C1A`) e travado por teste. No app, `Colors.swift` expõe `Color.pageBg`, `.fg`, `.card`, `.mutedFg`, `.border`, `.chip`, `.bar`, `.acc`, `.accFg`, `.accTx`, `.accBg`, `.pos`, `.neg`, cores dinâmicas por `UITraitCollection`. **Texto sobre `acc` é sempre `accFg`**, nunca branco.
- **Tema**: `ThemePreference` (Kit) com os mesmos valores do `localStorage.theme` da web (`auto`/`light`/`dark`), em `@AppStorage("theme")`, por dispositivo. `.monolitoTheme()` na raiz aplica a escolha via `overrideUserInterfaceStyle` nas janelas, e não via `preferredColorScheme`, que não alcança sheets direito e não volta do `nil`. Ele também põe `accTx` como tint, Geist como fonte padrão e títulos da barra de navegação em Geist. `ThemePicker` é o seletor Auto/Claro/Escuro (hoje na tela Conta).
- **Não pôr `foregroundStyle` na raiz**: ele passa por cima do tint de todo botão (ações da toolbar, vermelho destrutivo). Visto no iPhone.
- **Tipografia**: `DSFont` com os tamanhos da web mobile (título 28, número grande Mono 64, KPI Mono 20, linha 17/14,5, legenda 12…), todos com Dynamic Type.
- **Componentes**: `BigNumber`, `KPIStrip`/`KPI`, `ProgressLine` (vira `--neg` acima de 100%), `Hairline`, `Chip`, `Badge`, `ValueStepper`, `SectionTitle`; estilos de botão `.primary` (bloco mostarda), `.pill` ("Iniciar") e `.chip` (secundário), com o `press` da web (0,96, desligado com Reduzir Movimento); `.monolitoList()` (lista plana com linhas finas) e `.monolitoForm()` (formulário agrupado sobre o fundo da página).
- **Catálogo**: Conta › Desenvolvimento › Design system mostra todos os componentes numa tela, pra conferir claro/escuro e Dynamic Type no iPhone.

## Fontes (Geist e Geist Mono)

Testado em 2026-10-22 no iPhone, dentro do próprio app:

- **Os arquivos são os TTF variáveis do pacote npm `geist`** (1.4.2, `dist/fonts/geist-sans/Geist-Variable.ttf` e `geist-mono/GeistMono-Variable.ttf`), não os da web. O `@fontsource-variable/geist*` da web só tem `.woff2` cortados por faixa de Unicode (latin, latin-ext, cyrillic…), cada um com só parte dos caracteres. A família e os desenhos são os mesmos. Licença OFL 1.1, copiada como `Resources/Fonts/OFL.txt` (a OFL permite embutir num app, com a licença junto).
- **Recurso SwiftPM + registro em runtime funcionam**, sem `UIAppFonts` no Info.plist: `resources: [.copy("Resources/Fonts")]`, hoje no target `SoTreinaDesign` (ver "Design system"). O xtool copia a pasta pro bundle do módulo (`SoTreina.app/SoTreina_SoTreinaDesign.bundle/Fonts/`), e `CTFontManagerRegisterFontsForURL(url, .process, …)` registra. Tudo isso fica em `Sources/SoTreinaDesign/Fonts.swift`, que registra as duas fontes no primeiro uso de `Font.geist(_:relativeTo:)` ou `Font.geistMono(_:relativeTo:)`.
- **A fonte variável responde ao `.fontWeight`**: `Font.custom("Geist", …)` com `.fontWeight(.light)` até `.black` deu seis pesos distintos. Por isso bastam 2 arquivos (~250 KB), sem precisar dos TTF estáticos por peso.
- **O Dynamic Type funciona** com `Font.custom(_:size:relativeTo:)`: o texto acompanha o tamanho de texto do sistema, inclusive o número grande em Mono.
- Nomes de família pro `Font.custom`: `Geist` e `Geist Mono` (constantes em `AppFonts`).
- **Live Activity**: ver "Design system".
- As fontes moraram no target `SoTreina` até o design system; hoje ficam no `SoTreinaDesign`, então os `.lproj` do app não disputam a mesma pasta de recursos com elas.
- **Peso no UIKit (barra de navegação)**: a fonte variável ignora o traço de peso do `UIFontDescriptor`. O peso vai pelo eixo de variação `wght` (`kCTFontVariationAttribute`), em `AppFonts.uiFont(_:weight:relativeTo:)`, com peso CSS (600 = semibold). No SwiftUI, `.weight(...)` funciona direto.

## Widgets: inviáveis com Apple ID grátis

Testado em 2026-10-22 (`.scratch/app-ios-completo/issues/01-teste-app-group.md`): não há canal entre o app e um widget da Tela de Início.
- **App Group**: o xtool marca o recurso como pago (`AppGroupEntitlement` → `isFree: false`) e **remove o entitlement em silêncio** numa conta grátis. O provisionamento passa sem erro, mas o perfil sai sem `com.apple.security.application-groups`, e `containerURL(forSecurityApplicationGroupIdentifier:)` devolve nil (`client is not entitled`). Ele também reescreveria o ID pra `group.XTL-<team>.com.feroleto.sotreina`.
- **Keychain compartilhado**: o perfil até concede `keychain-access-groups = KBVDP58W3Z.*`, mas o xtool **sobrescreve** o entitlement com `TEAM.<bundle ID do alvo>`, então app e extensão ficam em grupos diferentes.
- A Live Activity não sofre disso: o ActivityKit entrega o estado à extensão.
- Reabrir só com conta paga ou um patch no xtool que preserve grupos de Keychain declarados.

## Validação visual

Cada tela portada é comparada com a web mobile por **pares de capturas**: o app pelo cabo e a web no `run-sotreina`, na mesma largura e escala (1179×2556). O par compara **estrutura, não dados**: layout, hierarquia, cores, tipografia e estados. O app roda contra produção e a web contra o banco local, então os números não batem e não precisam bater. As regras (matriz de estados, classes de diferença, quem aprova) estão no ticket "Formato da validação visual por fase" do mapa em `.scratch/app-ios-completo/`.

**O checklist de cada fase, logo abaixo, é a lista de capturas.** O agente escreve as linhas quando o ticket que constrói a tela começa. Cada linha da tabela segue este formato:

```
| # | Tela | Estado | App | Web | Resultado |
| 03 | Perfil | escuro · PT | `SOTREINA_SCREEN=profile SOTREINA_THEME=dark SOTREINA_LANG=pt` | `--page profile --theme dark` | ✓ |
| 04 | Perfil | Dynamic Type máx. | `SOTREINA_SCREEN=profile` | — | desvio aceito: rótulo quebra em 2 linhas |
```

- **#**: número da linha e prefixo das imagens: `ios/validation/<fase>/03-app.png` e `03-web.png`.
- **Estado**: tema, idioma, vazio/com dado, ou "Dynamic Type máx." (último degrau da régua normal, só no app).
- **App**: argumentos do `scripts/launch.sh` que abrem o app nesse estado (ver "Modo de validação" abaixo). Use `manual` quando a tela não tem destino próprio (ex.: Live Activity, um sheet aberto) e o usuário precisa levar o app até ela.
- **Web**: argumentos do driver do `run-sotreina` (`--page`, `--theme`, `--lang`, `--steps`). Use `—` para superfície sem web (Live Activity, notificação, sheet nativo, Dynamic Type), comparada com a spec e o design system.
- **Resultado**: vazio enquanto não foi conferido, `✓`, `desvio aceito: <motivo>` ou `bug: <o quê>` (bug é corrigido antes de fechar o ticket).

**Quem navega é o agente**, linha por linha: `launch.sh` com os argumentos da coluna App, depois `screenshot.sh`, depois a próxima linha. O usuário só desbloqueia o iPhone, ajusta o Dynamic Type quando uma linha pede (é ajuste do sistema, não tem variável), leva o app às linhas `manual` e aprova a galeria.

### Modo de validação

Num build de debug (o que o `deploy.sh` instala), o app lê três variáveis de ambiente na abertura (`ValidationLaunch` no Kit). Elas **sobrepõem a preferência salva sem gravá-la**: abrir de novo sem elas volta ao que o usuário escolheu (conferido em 2026-10-22: tema forçado claro com o seletor ainda em "Auto", e escuro de novo na abertura seguinte). Valor desconhecido é ignorado.

- `SOTREINA_SCREEN`: um `AppPage` (`runOverview`, `runActivities`, `gymOverview`, `gymRoutines`, `gymHistory`, `dietOverview`, `dietHistory`), que abre a aba dele já nessa sub-página, mesmo que ela ainda não tenha sido portada; uma aba (`today`, `run`, `gym`, `diet`, `profile`), que abre a raiz dela; `session` (o treino aberto em tela cheia); ou `sessionMinimized` (o treino na barra acima das abas). Com treino aberto, todo destino que não é `session` abre com ele minimizado, senão a sessão cobriria a tela. Sem treino aberto, `session`/`sessionMinimized` não abrem nada além da aba salva. O resumo do treino não tem destino: só existe logo depois de finalizar.
- `SOTREINA_THEME`: `light` ou `dark`.
- `SOTREINA_LANG`: `pt` ou `en`.

Capturar e montar a galeria (`ios/validation/` fica fora do git):

```bash
# app: abre no estado da linha e captura (iPhone desbloqueado)
ios/scripts/launch.sh SOTREINA_SCREEN=profile SOTREINA_THEME=dark SOTREINA_LANG=pt && sleep 6
ios/scripts/screenshot.sh ios/validation/S/03-app.png
# web: mesma tela, viewport do iPhone 15
node .claude/skills/run-sotreina/driver.mjs --iphone --page profile --theme dark --file ios/validation/S/03-web.png
# galeria app | web, uma linha por par, gerada desta tabela
node ios/scripts/gallery.mjs S
explorer.exe "$(wslpath -w ios/validation/S/index.html)"
```

### Fase S

| # | Tela | Estado | App | Web | Resultado |
|---|------|--------|-----|-----|-----------|
| 01 | Treino › Rotinas (header da área, abas de texto, tab bar) | claro · EN | `SOTREINA_SCREEN=gymRoutines SOTREINA_THEME=light SOTREINA_LANG=en` | `--page gym/workouts --lang en` | ok (manual, 2026-10-22) |
| 02 | Treino › Rotinas (header da área, abas de texto, tab bar) | escuro · EN | `SOTREINA_SCREEN=gymRoutines SOTREINA_THEME=dark SOTREINA_LANG=en` | `--page gym/workouts --theme dark --lang en` | ok (manual, 2026-10-22) |
| 03 | Corrida › Atividades (aviso "Em breve no app") | claro · PT | `SOTREINA_SCREEN=runActivities SOTREINA_THEME=light SOTREINA_LANG=pt` | — | ok (manual, 2026-10-22) |
| 04 | Treino minimizado (barra acima da tab bar) | claro · PT | `SOTREINA_SCREEN=sessionMinimized SOTREINA_THEME=light SOTREINA_LANG=pt` (precisa de treino aberto) | — | ok (manual, 2026-10-22) |
| 05 | Perfil (aba, conteúdo provisório da Conta) | claro · PT | `SOTREINA_SCREEN=profile SOTREINA_THEME=light SOTREINA_LANG=pt` | — | ok (manual, 2026-10-22) |
| 06 | Treino › Rotinas | Dynamic Type máx. | `SOTREINA_SCREEN=gymRoutines` | — | ok (manual, 2026-10-22) |
| 07 | Perfil (substitui a 05) | claro · PT | `SOTREINA_SCREEN=profile SOTREINA_THEME=light SOTREINA_LANG=pt` | `--page profile` | ok (2026-10-23; fim da página em `07b-app.png`) |
| 08 | Perfil | escuro · PT | `SOTREINA_SCREEN=profile SOTREINA_THEME=dark SOTREINA_LANG=pt` | `--page profile --theme dark` | ok (2026-10-23) |
| 09 | Perfil | claro · EN | `SOTREINA_SCREEN=profile SOTREINA_THEME=light SOTREINA_LANG=en` | `--page profile --lang en` | ok (2026-10-23) |
| 10 | Perfil com uma área só (chave travada, só a meta dela) | claro · PT | usuário desliga duas áreas | `--page profile` (conta com uma área) | ok (2026-10-23; abas viram Hoje + Perfil, como a web) |
| 11 | Perfil › Dados pessoais | claro · PT | usuário toca na linha do nome | `--page profile` + toque no nome | ok (2026-10-23; campos em cartão como o login do app: nativo) |
| 12 | Perfil › Metas semanais (em mi) | claro · PT | usuário troca pra mi e toca na meta da Corrida | `--page profile` + toque na meta | ok (usuário testou em mi depois do deploy, 2026-10-23) |
| 13 | Perfil › Meta diária (fora da meta, em vermelho) | escuro · PT | usuário toca na meta da Dieta | `--page profile --theme dark` + toque na meta | ok (2026-10-23) |
| 14 | Perfil | Dynamic Type máx. | `SOTREINA_SCREEN=profile` | — | ok (2026-10-23; os seletores segmentados não crescem com o texto: nativo; fim em `14b-app.png`) |

### Fase T

Peso em lb (`.scratch/app-ios-completo/issues/19-peso-lb-sessao.md`): as linhas 01–07 pedem um treino aberto e a conta em lb (Perfil › Unidades). A Sessão também cobre a conferência em EN que ficou pendente no ticket das strings da Navegação.

Treino livre e atualizar rotina (`.scratch/app-ios-completo/issues/20-sessao-livre-atualizar-rotina.md`): linhas 09–11.

Rotinas, leitura (`.scratch/app-ios-completo/issues/21-rotinas-leitura.md`): linhas 12–17.

Editor de rotina (`.scratch/app-ios-completo/issues/22-editor-rotina.md`): linhas 18–26.

Histórico (`.scratch/app-ios-completo/issues/23-historico-treino.md`): linhas 27–34. A lista tem destino próprio (`gymHistory`); os detalhes são por toque. As capturas da web saem de um `--steps` que abre os editores e nunca toca em Salvar. As telas empilhadas não têm destino próprio no modo de validação: o agente abre Rotinas e o usuário toca. As capturas da web saem de um `--steps` que só navega (abre "Upper" e o primeiro exercício). O aviso de rotinas vazias também ganhou "Começar treino livre", mas não entra na lista: a conta de teste tem rotinas.

| # | Tela | Estado | App | Web | Resultado |
|---|------|--------|-----|-----|-----------|
| 01 | Sessão em lb (séries, proposta no placeholder, "última vez") | claro · EN | `SOTREINA_SCREEN=session SOTREINA_THEME=light SOTREINA_LANG=en` (treino aberto, conta em lb) | `--page gym/workouts --lang en` (sessão aberta, conta em lb) | ok (2026-10-23; web em grade e app em lista é anterior a este ticket) |
| 02 | Sessão em lb | escuro · PT | `SOTREINA_SCREEN=session SOTREINA_THEME=dark SOTREINA_LANG=pt` | `--page gym/workouts --theme dark` (sessão aberta, conta em lb) | ok (2026-10-23) |
| 03 | Sessão › editar série em lb (sheet) | claro · EN | manual: tocar numa série registrada | — | ok (2026-10-23; 44.1 → 45 lb salvo voltou "45 lb × 5") |
| 04 | Sessão › diálogos Finalizar e Cancelar | claro · EN | manual | — | ok (2026-10-23; Cancelar em `04b-app.png`) |
| 05 | Treino minimizado (barra acima das abas) | claro · EN | `SOTREINA_SCREEN=sessionMinimized SOTREINA_THEME=light SOTREINA_LANG=en` | — | ok (2026-10-23) |
| 06 | Live Activity em lb (tela bloqueada, proposta e "✓") | — | manual: bloquear o iPhone com o treino aberto | — | ok (2026-10-23) |
| 07 | Resumo em lb (volume em k lb, PRs) | claro · PT | manual: finalizar o treino | `--page gym/workouts` (resumo, conta em lb) | ok (2026-10-23; recorde "45 lb × 5 · antes 44,1 lb × 5" conferido num resumo anterior em EN; a web escreve "0.2" com ponto em PT, o app "0,2") |
| 08 | Sessão de volta em kg (regressão) | claro · PT | `SOTREINA_SCREEN=session SOTREINA_THEME=light SOTREINA_LANG=pt` (conta em kg) | — | ok (2026-10-23) |
| 09 | Rotinas com a linha "Treino livre" no fim | claro · PT | `SOTREINA_SCREEN=gymRoutines SOTREINA_THEME=light SOTREINA_LANG=pt` | `--page gym/workouts` (a web não tem treino livre: exceção registrada) | ok (2026-10-23) |
| 10 | Sessão de treino livre, ainda sem exercício | claro · EN | manual: "Iniciar" na linha "Treino livre" | — | ok (2026-10-23; capturada no escuro, o app seguia o sistema) |
| 11 | Finalizar uma rotina que mudou: "Atualizar rotina / Manter rotina / Voltar" | claro · PT | manual: tirar ou acrescentar um exercício de uma rotina e tocar em Finalizar | `--page gym/workouts` (sessão divergente + "Finalizar treino") | desvio aceito: folha de ações nativa no lugar do cartão da web, como os diálogos da linha 04 (2026-10-23; capturada no escuro) |
| 12 | Rotina › detalhe (chips, exercícios com metas, "Iniciar treino") | claro · PT | `SOTREINA_SCREEN=gymRoutines SOTREINA_THEME=light SOTREINA_LANG=pt` + tocar em "upper" | `--page gym/workouts` + tocar em "Upper" | ok (2026-10-23; chips do app maiores: `Chip` do design system) |
| 13 | Rotina › detalhe | escuro · EN | `SOTREINA_SCREEN=gymRoutines SOTREINA_THEME=dark SOTREINA_LANG=en` + tocar em "upper" | `--page gym/workouts --theme dark --lang en` + tocar em "Upper" | ok (2026-10-23) |
| 14 | Rotina › confirmação de excluir | claro · PT | como a 12 + lixeira | — (a web confirma numa faixa inline) | desvio aceito: folha de ações nativa no lugar da faixa inline da web (2026-10-23; exclusão real conferida pelo usuário) |
| 15 | Exercício › detalhe (foto, chips, metas, peso anterior em lb, como executar) | claro · PT | como a 12 + tocar no primeiro exercício | `--page gym/workouts` + "Upper" + primeiro exercício | ok (2026-10-23; peso anterior em lb no app, kg no banco local da web) |
| 16 | Exercício › detalhe | escuro · EN | como a 13 + tocar no primeiro exercício | `--page gym/workouts --theme dark --lang en` + "Upper" + primeiro exercício | ok (2026-10-23) |
| 17 | Rotina › detalhe | Dynamic Type máx. | `SOTREINA_SCREEN=gymRoutines` + tocar em "upper" | — | ok (2026-10-23; nome longo corta com "…", como na web) |
| 18 | Rotinas com "N rotinas salvas · + Nova" no topo | claro · PT | `SOTREINA_SCREEN=gymRoutines SOTREINA_THEME=light SOTREINA_LANG=pt` | `--page gym/workouts` | ok (2026-10-23) |
| 19 | Nova rotina, vazia | claro · PT | como a 18 + "+ Nova" | `--page gym/workouts` + "Nova rotina" | ok (2026-10-23) |
| 20 | Editar rotina (nome, exercícios com metas, + Adicionar exercício) | claro · PT | como a 18 + "upper" + lápis | `--page gym/workouts` + "Upper" + lápis | desvio aceito: linhas finas em vez de cartões (padrão das listas do app, arraste nativo), "≡" no lugar dos seis pontos, Cancelar/Salvar na barra (2026-10-23) |
| 21 | Editar exercício (séries, faixa de reps, descanso) | claro · PT | como a 20 + tocar no primeiro exercício | como a 20 + primeiro exercício | ok (2026-10-23) |
| 22 | Adicionar exercício: chip "Legs", selecionados | escuro · EN | `SOTREINA_SCREEN=gymRoutines SOTREINA_THEME=dark SOTREINA_LANG=en` + "upper" + lápis + "Add exercise" + "Legs" | `--page gym/workouts --theme dark --lang en` + "Upper" + lápis + "Add exercise" + "Legs" | desvio aceito: folha sobre o editor em vez de tela cheia; chip selecionado com contorno (`Chip`) (2026-10-23) |
| 23 | Editar rotina | escuro · EN | como a 22, antes de "Add exercise" | `--page gym/workouts --theme dark --lang en` + "Upper" + lápis | ok (2026-10-23) |
| 24 | Cancelar com alteração: "Descartar alterações?" | claro · PT | como a 20 + mudar o nome + Cancelar | — (a web confirma numa faixa inline) | desvio aceito: folha de ações nativa no lugar da faixa inline (2026-10-23) |
| 25 | Editar rotina | Dynamic Type máx. | como a 20 | — | ok (2026-10-23) |
| 26 | Funcional: criar uma rotina, reordenar arrastando, mudar metas e salvar; editar e salvar uma existente | — | manual | — | ok (usuário, 2026-10-23: criou, arrastou, mudou metas, salvou; editou removendo um exercício; ordem e metas conferidas no detalhe) |
| 27 | Histórico (KPIs, barras semanais, Recentes por semana) | claro · PT | `SOTREINA_SCREEN=gymHistory SOTREINA_THEME=light SOTREINA_LANG=pt` | `--page gym/history` | ok (2026-10-23; cartões de KPI com 150 pt como na web) |
| 28 | Histórico › barra tocada (leitura da semana) | claro · PT | como a 27 + tocar na barra da semana atual | — | ok (2026-10-23) |
| 29 | Treino finalizado › detalhe (data, 4 stats, exercícios com médias) | claro · PT | como a 27 + primeira linha | `--page gym/history` + primeira linha | ok (2026-10-23; "1 séries" sem plural também na web) |
| 30 | Exercício no treino (séries, volume, 1RM est., série a série, melhor série) | claro · PT | como a 29 + primeiro exercício | como a 29 + primeiro exercício | ok (2026-10-23; tabela de séries espalhada como na web) |
| 31 | Histórico | escuro · EN | `SOTREINA_SCREEN=gymHistory SOTREINA_THEME=dark SOTREINA_LANG=en` | `--page gym/history --theme dark --lang en` | ok (2026-10-23) |
| 32 | Treino finalizado › detalhe | escuro · EN | como a 31 + primeira linha | como a 31 + primeira linha | ok (2026-10-23) |
| 33 | Exercício no treino | escuro · EN | como a 32 + primeiro exercício | como a 32 + primeiro exercício | ok (2026-10-23) |
| 34 | Histórico | Dynamic Type máx. | `SOTREINA_SCREEN=gymHistory` | — | ok (2026-10-23); desvios aceitos por enquanto na fase: sem animação de entrada das barras/semanas, barras desenhadas à mão (não Swift Charts) |

### Fase C

Atividades (`.scratch/app-ios-completo/issues/34-corrida-atividades.md`, no working tree principal): linhas 01–07. Detalhe da atividade (`35-corrida-detalhe.md`): linhas 08–13. Visão geral (`37-corrida-visao-geral.md`): linhas 14–20. O app roda contra produção e a web contra o banco local, então semanas e números não batem: o par compara a estrutura.

| # | Tela | Estado | App | Web | Resultado |
|---|------|--------|-----|-----|-----------|
| 01 | Corrida › Atividades (semana, barras de 12 semanas, lista, "Powered by Strava") | claro · PT | `SOTREINA_SCREEN=runActivities SOTREINA_THEME=light SOTREINA_LANG=pt` | `--page run/activities` |  ok (2026-10-23; números com vírgula em PT, a web escreve "12.4"; a tab bar nativa no lugar da pílula é o desvio já aceito na Navegação) |
| 02 | Corrida › Atividades | escuro · EN | `SOTREINA_SCREEN=runActivities SOTREINA_THEME=dark SOTREINA_LANG=en` | `--page run/activities --theme dark --lang en` |  ok (2026-10-23) |
| 03 | Barra tocada (leitura da semana em cima) | claro · PT | manual: tocar numa barra | — |  ok (2026-10-23) |
| 04 | Sheet de período (atalhos + início/fim, até 3 meses) | claro · PT | manual: tocar em "Personalizado" | — (a web usa um calendário de dois toques, sem equivalente nativo) |  desvio aceito: sheet nativo com atalhos + Início/Fim no lugar do calendário de dois toques da web |
| 05 | Período aplicado (chip, barras e lista do período) | claro · PT | manual: escolher "Mês Passado" | — |  ok (2026-10-23; "Últimos 3 Meses": 14 semanas, chip "9 corridas · 54,6 mi · 93 dias") |
| 06 | Corrida › Atividades em mi | claro · PT | `SOTREINA_SCREEN=runActivities SOTREINA_THEME=light SOTREINA_LANG=pt` (conta em mi) | — |  ok (2026-10-23; coberta pelas linhas 01–05, todas com a conta em mi) |
| 07 | Corrida › Atividades | Dynamic Type máx. | `SOTREINA_SCREEN=runActivities` | — |  ok (2026-10-23; saiu no escuro, que era o tema do sistema) |
| 08 | Detalhe de corrida com GPS (badge, stats, mapa, voltas, "View on Strava") | claro · PT | manual: tocar numa corrida com mapa | `--page run/activities --steps …` (abrir a primeira) |  ok (2026-10-23; mapa MapKit estático, com o logo "Maps"/"Legal" obrigatórios no lugar da atribuição Leaflet/OSM; selo do tipo na barra de navegação no lugar do "← Voltar"; "Km N" com mi como na web) |
| 09 | Detalhe de corrida com GPS | escuro · EN | manual: idem | `--page run/activities --theme dark --lang en --steps …` |  ok (2026-10-23; o mapa escuro é o estilo escuro do MapKit, mais azulado que o OSM filtrado da web) |
| 10 | Detalhe de esteira (grade "Sem dados de GPS") | claro · PT | manual: tocar numa esteira | — |  pulada pelo usuário: conferir no Uso real da Fase C |
| 11 | Detalhe de intervalado (badge mostarda, "Tiro N"/"Rec.") | claro · PT | manual: tocar num intervalado | — |  ok (2026-10-23; selo mostarda, "Aquecimento N"/"Tiro N"/"Rec. N") |
| 12 | "View on Strava" abre a atividade na Strava | — | manual: tocar no link | — |  ok (2026-10-23; abriu a atividade no app da Strava) |
| 13 | Detalhe | Dynamic Type máx. | manual | — |  ok (2026-10-23; a tabela de voltas para de crescer em `.xLarge` e a coluna FC média ficou com 52 pt; o resto da tela segue o Dynamic Type) |
| 14 | Corrida › Visão geral (totais, calendário, início dos recordes) | claro · PT | `SOTREINA_SCREEN=runOverview SOTREINA_THEME=light SOTREINA_LANG=pt` | `--page run/overview` |  ok (2026-10-23; vírgula decimal em PT, a web escreve "2080.8") |
| 15 | Corrida › Visão geral | escuro · EN | `SOTREINA_SCREEN=runOverview SOTREINA_THEME=dark SOTREINA_LANG=en` | `--page run/overview --theme dark --lang en` |  ok (2026-10-23) |
| 16 | Recordes (1k/5k/10k + mais longa), tênis e "Powered by Strava" | claro · PT | manual: rolar até o fim | `--page run/overview` rolada |  ok (2026-10-23) |
| 17 | "Ver todos": 12 distâncias, 5k expandido (2º/3º) | claro · PT | manual: "Ver todos" → 5k | sheet "Ver todos" |  ok (2026-10-23; sheet nativo; nome e data em linhas separadas, como a web) |
| 18 | Calendário num mês com corridas, dia tocado no rodapé | claro · PT | manual: voltar até agosto, tocar num dia | — |  ok (2026-10-23) |
| 19 | Visão geral | Dynamic Type máx. | manual | — |  ok (2026-10-23; com o texto grande, nome e data dos recordes vão pra linhas separadas, o texto do chip para em `.large` e a meta do tênis quebra em duas linhas) |
| 20 | Recorde novo: selo "Novo" + pop em mola no chip | claro · PT | só com um recorde real: Uso real da Fase C | — |  pendente: precisa de um recorde real, fica pro Uso real da Fase C (a regra está testada no Kit) |

## Checklist da Fase 0 (go/no-go)

- [x] `deploy.sh` instala e abre o app no iPhone
- [x] **Live Activity**: "Iniciar descanso de 60s" mostra o timer na Dynamic Island e na tela bloqueada, contando sozinho. "+15s" atualiza, e "Encerrar" remove. **Critério decisivo.**
- [x] Login com email/senha contra produção, e o nome aparece na tela inicial
- [x] Fechar e reabrir o app mantém o login (token no Keychain)
- [x] `logs.sh` mostra as linhas `GET auth/me -> 200` do app (só `.notice` pra cima: `.info`/`.debug` não passam pelo `idevicesyslog`)
- [ ] Tempo de um ciclo editar → `deploy.sh` → app aberto: ____ s
