# Modo de validação por variáveis de ambiente

Type: task
Status: resolved
Blocked by: 15

## Question

Fazer o app ler, só em build de debug (`#if DEBUG`), variáveis de ambiente passadas pelo `ios/scripts/launch.sh` e abrir direto no estado pedido. Assim o agente percorre o checklist da validação visual sozinho: `launch.sh` → `screenshot.sh` → próxima linha. O resultado do [Teste: app abre numa tela via `dvt launch --env`](13-teste-launch-env.md) mostrou que as variáveis chegam ao processo.

- **Variáveis**: `SOTREINA_SCREEN` (um `AppPage` do Kit, ou um destino além das abas, como sessão ou resumo), `SOTREINA_THEME` (`light`/`dark`) e `SOTREINA_LANG` (`pt`/`en`). Elas sobrepõem a preferência salva **sem gravá-la**: um lançamento normal depois volta ao que o usuário escolheu.
- O parse e o mapeamento nome → destino ficam no Kit, com teste (`ValidationLaunch` ou parecido). O app só aplica o resultado na raiz.
- Dynamic Type não entra: é ajuste do sistema, e o usuário muda à mão uma vez por fase.
- Quando fechar, a decisão 4 do [Formato da validação visual por fase](12-validacao-visual.md) passa a ser "o agente navega". Atualizar o README ("Validação visual") e a coluna/comando de captura do app no checklist.

Bloqueado por [Strings das telas em PT/EN](15-strings-telas.md), que está mexendo na raiz do app e no idioma.

## Answer

**Feito e conferido no iPhone (2026-10-22).** Quem navega na validação agora é o agente.

- **Kit**: `ValidationLaunch.swift`.
  - `ValidationLaunch(environment:)` lê `SOTREINA_SCREEN`/`SOTREINA_THEME`/`SOTREINA_LANG`. Valor desconhecido é ignorado, e `auto` não sobrepõe nada.
  - `Destination` pode ser `.tab(AppTab)`, `.page(AppPage)`, `.session` ou `.sessionMinimized`, e `.tab`/`.startsSessionMinimized` são derivados dela. `AppPage.tab` diz a aba de cada página.
  - `ValidationLaunch.current` lê o `ProcessInfo` só com `#if DEBUG`, e fica vazio em release.
  - 7 testes em `ValidationLaunchTests`. O Kit tem 107 testes, todos passando.
- **App**: cada uso lê `ValidationLaunch.current` na hora, e nada é gravado.
  - **Idioma**: `AppLanguageStore.lang` e `.current`. O `Accept-Language` segue junto.
  - **Tema**: `MonolitoTheme.applyTheme`. Fica no target de design, então vale também pra segunda aplicação, a do `fullScreenCover`.
  - **Aba**: `AppShell`, num `onAppear` único. `SceneStorage(wrappedValue:)` não serve, porque um valor já salvo ganha dele.
  - **Sub-página**: `AreaScreen.init`, inclusive pra página ainda não portada.
  - **Minimizado**: `WorkoutStore.launchMinimizedPending`, aplicado ao primeiro treino que aparece no processo.
- **Conferido no aparelho**: com `runActivities` + `dark` + `en`, abriu Run › Activities escuro e em inglês. Com `profile` + `light` + `pt`, abriu o Perfil claro, com o seletor ainda em "Auto", ou seja, nada foi gravado. Abrir sem variáveis voltou à aba salva e ao tema do sistema.
- **README**: em "Validação visual", entrou a regra "quem navega é o agente" e a seção "Modo de validação" (lista de destinos e limitações). O checklist ganhou a coluna **App**, com os argumentos do `launch.sh`, e a Fase S está preenchida. O `gallery.mjs` passou a ler as 6 colunas.
- **Decisão 4** do [Formato da validação visual por fase](12-validacao-visual.md): marcada como substituída.

**Não testado:** `session`/`sessionMinimized`. Abrir um treino em produção só pra testar criaria dado real, e a lógica é a mesma do minimizar, que já foi validado à mão. A primeira linha da Fase T que tiver treino aberto confere isso.

**Limitações:** o resumo do treino não tem destino, porque só existe logo depois de finalizar. Dynamic Type continua manual.
