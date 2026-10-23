# Mapa — SoTreina completo no iPhone

## Destination

O app iOS (`ios/`) **implementado** conforme `.plans/app-ios-completo-spec.md`: Shell, Treino completo, Dieta, Corrida, Hoje e (se viável) Widgets, cada fase validada no iPhone com uso real, com a paridade web ↔ app em vigor para cada área portada.

## Notes

- **Este mapa carrega a execução** (exceção à regra "planejar, não fazer", decidida com o usuário em 2026-10-22): além de tickets de decisão, há tickets `task` que constroem partes do app. Um ticket `task` de construção se resolve com o código pronto, compilando, testado no Kit e conferido no iPhone, e com o `## Answer` dizendo o que foi feito e o que ficou pendente.
- **Fonte das decisões de produto**: `.plans/app-ios-completo-spec.md`. Contornos de build e ambiente: `ios/README.md` e a seção "App iOS" do `CLAUDE.md`. Vocabulário: `GLOSSARY.md`.
- **Skills a consultar**: `grilling` + `domain-modeling` nos tickets de decisão; `run-sotreina` pra screenshots da web mobile; `tdd` quando portar lógica da web pro `SoTreinaKit` (os testes da web viram testes Swift).
- **Preferências permanentes**:
  - Tudo que não desenha tela vai pro `SoTreinaKit`, com `swift test` no Linux.
  - Antes de adotar qualquer framework da Apple, checar se ele depende de ferramenta exclusiva do Xcode (macros, processadores de metadados). SwiftData e App Intents já caíram por isso.
  - O usuário commita; o agente não faz commit.
  - Deploy no iPhone: `ios/scripts/deploy.sh` com o Apple Devices aberto no Windows.
  - Mudanças de backend que exigem migration: migration no Neon antes do deploy do backend.
- **Fases em paralelo por git worktree** (decidido com o usuário em 2026-10-23): o Treino segue no working tree principal (`main`) e a Corrida num worktree próprio (`../strava_dashboard-corrida`, branch `fase-c`). A fila entre as fases era só de ferramenta (build, arquivos compartilhados, iPhone), não de domínio. Regras:
  - **O tracker é um só**: este `.scratch/` no working tree principal. Uma sessão no worktree edita os tickets pelo caminho absoluto `/home/ferol/projetos/strava_dashboard/.scratch/…` e nunca a cópia de dentro do worktree, que fica parada e não dá conflito no merge.
  - **Commit por ticket fechado**, nos dois branches (o usuário commita).
  - **Antes de cada `deploy.sh`, trazer o outro branch** (merge de `main` em `fase-c`, ou o contrário). Senão a instalação de uma fase some com as telas da outra no iPhone. A validação no aparelho é uma de cada vez.
  - Conflitos esperados e triviais: os blocos acrescentados no fim dos `.strings` (manter os dois), uma linha por fase em `AreaScreen.portedPages`, e cada fase com a própria seção no checklist do README.
- **Tracker**: markdown local. Tickets em `issues/NN-<slug>.md` com `Type:`, `Status:` (`open`/`claimed`/`resolved`) e `Blocked by:`.

## Decisions so far

<!-- uma linha por ticket resolvido -->

- [Teste: fontes Geist e Geist Mono embutidas](issues/03-teste-fontes.md): funciona — TTF variáveis do npm `geist` como recurso SwiftPM, registro em runtime, pesos e Dynamic Type ok; `Core/AppFonts.swift` pronto, Live Activity não testada
- [Teste: screenshot do iPhone pelo cabo](issues/04-teste-screenshot.md): funciona sem root via `pymobiledevice3 developer dvt screenshot --userspace` (~1,7 s, PNG nativo); `idevicescreenshot` morreu no iOS 17. Script `ios/scripts/screenshot.sh`.
- [Teste: localização PT/EN sem Xcode](issues/02-teste-localizacao.md): `.strings`/`.stringsdict` em `.lproj` (o `.xcstrings` não compila); idioma troca em runtime via `\.locale` + bundle do `.lproj`
- [Teste: App Group com xtool e Apple ID grátis](issues/01-teste-app-group.md): não há App Group nem Keychain compartilhado com xtool + conta grátis (o xtool filtra/sobrescreve os entitlements); widgets fora do plano
- [Cache JSON de leitura](issues/08-cache-json.md): `ResponseCache` no Kit + `CachedAPI` no app; restaura do cache só na primeira carga e grava o estado de mutações; aplicado a rotinas e treino ativo — padrão pras próximas áreas
- [Unidades km/mi e kg/lb (backend + web + Kit)](issues/05-unidades.md): feito — colunas `distanceUnit`/`weightUnit` (migration pendente no Neon), web convertendo na borda via `lib/units.ts`, `UnitConversion` no Kit; Análise e editor de voltas da web ficam em km, app ainda mostra kg
- [Formato da validação visual por fase](issues/12-validacao-visual.md): par app × web compara estrutura (não dados), 393 pt @3x, claro/escuro + EN + vazio + Dynamic Type; usuário navega, agente captura e tria, usuário aprova; validação por ticket, checklist no README é a lista
- [Idioma PT/EN no app](issues/09-idioma.md): infraestrutura pronta (`Lang`/`AppLanguage` no Kit, formatadores PT/EN, `AppLanguageStore` com locale na raiz, `Accept-Language`/`X-Time-Zone`, idioma no estado da Live Activity); migração das telas virou [Strings das telas em PT/EN](issues/15-strings-telas.md)
- [Ferramentas da validação visual](issues/14-ferramentas-validacao.md): driver `--iphone` (1179×2556) + `--file`, `ios/validation/` no `.gitignore`, `ios/scripts/gallery.mjs <fase>` gera a galeria app | web a partir da tabela `| # | Tela | Estado | Web | Resultado |` do README (Fase S vazia pronta)
- [Design system Monolito no app (tokens, tema, fontes)](issues/06-design-system.md): target `SoTreinaDesign` compartilhado com a Live Activity (fontes e mostarda conferidas lá), paleta no Kit com teste contra o `index.css`, componentes + catálogo, telas migradas
- [Strings das telas em PT/EN](issues/15-strings-telas.md): `.strings`/`.stringsdict` no `SoTreinaDesign` (app + Live Activity), `Text(…, bundle: .l10n)` / `L10n.string(_:lang:)`, chaves da web; login, resumo, descanso, picker, expiração e Live Activity migrados, telas da Navegação ficaram pra [Strings das telas da Navegação em PT/EN](issues/17-strings-telas-navegacao.md)
- [Teste: app abre numa tela via `dvt launch --env`](issues/13-teste-launch-env.md): passou — variáveis chegam ao processo (`ios/scripts/launch.sh`); o app ainda precisa lê-las, ver [Modo de validação por variáveis de ambiente](issues/16-modo-validacao-env.md)
- [Modo de validação por variáveis de ambiente](issues/16-modo-validacao-env.md): feito — `ValidationLaunch` no Kit (debug only) sobrepõe tela/tema/idioma sem gravar; o agente navega pela coluna App do checklist (`launch.sh` → `screenshot.sh`); `session`/`sessionMinimized` ainda não conferidos no aparelho
- [Navegação: abas, header de área e sessão minimizável](issues/07-navegacao.md): feito e validado no iPhone — `AppTab` no Kit (regra do `mobileTabsFor`), `AppShell` + `AreaScreen` com header de área e "Em breve no app", sessão em `fullScreenCover` minimizável pra barra acima das abas; cada fase registra suas páginas em `AreaScreen.portedPages`
- [Fatiamento da Fase T (Treino completo)](issues/18-fatiamento-fase-t.md): sete tarefas em fila — lb no que existe → Sessão (livre + atualizar rotina) → Rotinas leitura → Editor → Histórico → Visão geral → Uso real; nenhuma mexe no backend
- [Entrada: cadastro, esqueci a senha e escolha de áreas](issues/10-entrada.md): feito e conferido no iPhone — `LoginView` com Entrar/Criar conta (`register` + `token`), `ForgotPasswordView`, `AreaPickerView` com gate no `RootView` quando `enabledAreas` vazio; `SessionStore.saveAreas` serve ao Perfil; regras no Kit (`Entry.swift`)
- [Perfil do app](issues/11-perfil.md): feito e validado — `ProfileView` + nome/metas semanais/meta diária, `MeSettings`/`ProfileRules` no Kit, saves otimistas que atualizam o `Me` da sessão; fixou os padrões de lista plana (fundo, título como linha, separador desde a borda)
- [Strings das telas da Navegação em PT/EN](issues/17-strings-telas-navegacao.md): feito — Shell, Rotinas, Sessão, barra ativa e mensagens do `WorkoutStore` no L10n, grep limpo; conferido em EN no iPhone só Rotinas e "Em breve", a Sessão ficou pra [Peso em lb na sessão, no resumo e na Live Activity](issues/19-peso-lb-sessao.md)
- [Peso em lb na sessão, no resumo e na Live Activity](issues/19-peso-lb-sessao.md): feito e validado — `WorkoutFormat` com `unit:`, entrada convertida pra kg na borda, sheet de edição preserva o kg intacto, volume do resumo como na web ("1,8 t"/"0,2 k lb"), unidade no estado da Live Activity; corrigiu o "última vez" preso depois de finalizar
- [Sessão: treino livre e atualizar rotina ao finalizar](issues/20-sessao-livre-atualizar-rotina.md): feito e validado — linha "Treino livre" no fim de Rotinas (só no app), diálogo Atualizar/Manter/Voltar a partir do `template-drift` do servidor (`FinishPrompt` no Kit); trocar o idioma com treino aberto agora recarrega os nomes dos exercícios
- [Rotinas: detalhe da rotina e detalhe do exercício](issues/21-rotinas-leitura.md): feito e validado — toque na linha empilha o detalhe (metas, "Iniciar treino", excluir com confirmação; editar entra com o editor), detalhe do exercício com foto/chips/peso anterior/instruções; `FlowLayout`/`CapsTitle` no design system; botão de voltar agora diz o nome da aba
- [Fatiamento da Fase D (Dieta)](issues/26-fatiamento-fase-d.md): seis tarefas em fila depois da Visão geral do Treino (junto do Uso real da Fase T): o dia + edição → adicionar Registros → manual + scanner → Refeições salvas → histórico → Uso real; `clientId` nos Registros (único backend da fase)
- [Fatiamento da Fase C (Corrida)](issues/33-fatiamento-fase-c.md): cinco tarefas em fila depois do histórico da Dieta (junto do Uso real da Fase D): Atividades → detalhe com MapKit → editor de voltas (fica em metros/segundos, sem mi) → Visão geral (com a comemoração de recorde) → Uso real; sem backend

## Not yet specified

- **Proposta de série depois de um exercício pulado**: `GET /exercises/:id/last-performance` devolve o último treino finalizado com o exercício mesmo sem séries, então pular um exercício apaga a proposta dele no treino seguinte (web e app). Decidir se o backend deve pular treinos sem série; mexe no backend, que a Fase T deixou de fora.

## Out of scope

- **Fase W (Widgets da Tela de Início)**: sem canal app↔widget com xtool + Apple ID grátis; o usuário preferiu tirar a remendar o xtool ([Teste: App Group com xtool e Apple ID grátis](issues/01-teste-app-group.md)).
- Login/conexão/desconexão Strava, adicionar senha, sync manual, Análise da corrida, HealthKit, escrita offline, comida em onças, widgets de tela bloqueada e "Próximo treino", push remoto (spec §4).
