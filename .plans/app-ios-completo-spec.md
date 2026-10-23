# Spec — SoTreina completo no iPhone (Treino, Dieta, Corrida e Hoje em SwiftUI)

Data: 2026-10-22 · Status: **planejada, nenhuma fase iniciada**
Base: o app de `ios/` com as Fases 0–2 de `.plans/app-ios-nativo-spec.md` (login Bearer, rotinas, sessão ao vivo, resumo, timer com notificação, aviso de expiração, Live Activity). Contornos de build em `ios/README.md`.

## 1. Objetivo e mudança de estratégia

A spec anterior limitava o nativo ao treino ao vivo e deixava o resto no PWA. **Isso muda**: o app nativo passa a ser o SoTreina principal no iPhone, com Treino, Dieta, Corrida e Hoje. O PWA continua existindo (desktop, e pra quem não tem o app), mas deixa de ser o caminho no iPhone.

Motivos do usuário, todos considerados:
- **Um app só**: alternar entre o PWA e o app do treino é ruim.
- **Sensação de app**: gestos, transições, teclado e rolagem nativos.
- **Recursos do iOS**: scanner de código de barras nativo e widgets.
- **Velocidade**: abrir mostrando dado na hora (cache), sem esperar a rede.

Custo aceito conscientemente: manter **duas interfaces completas** (web e SwiftUI) com paridade (§9), e reinstalar o app a cada 7 dias (Apple ID grátis — aceito pelo usuário).

## 2. Decisões

| Tema | Decisão |
|---|---|
| Áreas | Hoje, Corrida, Treino (completo), Dieta |
| Ordem | Shell → Treino → Dieta → Corrida → Hoje → Widgets |
| Visual | **Monolito com cara de iOS**: paleta, tipografia e hierarquia da web, com navegação, listas, sheets e gestos nativos |
| Navegação | `TabView` nativa: Hoje + áreas ativas + Perfil (mesma regra de `mobileTabsFor` da web) |
| Sub-páginas | Título grande da área + abas de texto no topo, trocando o conteúdo no lugar (como o header mobile da web) |
| Sessão de treino | Tela cheia sem tab bar, **minimizável**; barra "Treino em andamento · 12:05" acima da tab bar pra voltar |
| Entrada | Login email/senha (já existe) + **cadastro** + **esqueci a senha** + **escolha de áreas**. Sem login/conexão Strava no app |
| Perfil | Nome, áreas, metas, tema, idioma, unidades, sair. Strava (conectar/desconectar) e "adicionar senha" ficam na web |
| Tema | Auto/Claro/Escuro com seletor no Perfil (por dispositivo, como a web) |
| Idioma | PT e EN. Padrão = idioma do iPhone (outros caem em EN, como a web); seletor no Perfil sobrescreve. `Accept-Language` acompanha |
| Fontes | Geist + Geist Mono embutidas |
| Unidades | **Nova feature, web e app**: km/mi e kg/lb salvos na conta. Banco segue em km e kg |
| Cache | Arquivos JSON por endpoint (cache de leitura). Escritas exigem rede, com ⚠/reenviar |
| Gráficos | Swift Charts estilizado com a paleta |
| Mapa | MapKit (no lugar dos tiles OSM) |
| Scanner | VisionKit `DataScannerViewController` (no lugar do `html5-qrcode`) |
| Widgets | ~~Dieta do dia e Semana~~ **Fora (2026-10-22)**: inviáveis com xtool + Apple ID grátis (sem App Group nem Keychain compartilhado), ver `ios/README.md` |
| Strava | Mesmas regras da web (Powered by Strava, View on Strava, logos oficiais sem alteração) |
| Paridade | Obrigatória por área, a partir da fase em que a área chega ao app (§9) |
| Validação | Screenshot do iPhone pelo cabo comparado com a mesma tela da web mobile |

### Descartado (e por quê)

- **SwiftData**: era a escolha do usuário pro cache, mas **não compila com o xtool**. A macro `@Model` roda num plugin que só existe como binário de macOS (`libSwiftDataMacros.dylib`), e o `OpenAppleMacrosServer` do xtool só reimplementa macros de SwiftUI, Previews e FoundationModels. Alternativas avaliadas: GRDB (SQLite, roda no Linux) e Core Data (sem macros, mas sem testes no Linux). Escolhido JSON por endpoint, que basta pra cache de leitura; um banco (GRDB) só se vier a fila offline, e mesmo ela persiste operações pendentes, não um espelho do servidor.
- **Offline completo**: escrita offline com fila fica de fora (fase condicional da spec anterior continua valendo só pro treino).
- **Pílula flutuante custom da web**: a `TabView` nativa já é flutuante em vidro no iOS 26 e traz acessibilidade.
- **Login/conexão Strava no app**: exigiria OAuth com `ASWebAuthenticationSession` e o callback do backend devolvendo Bearer. Conta só-Strava (sem senha) **não entra no app** até adicionar senha pela web.
- **Botão de sync manual da Strava**: fora. Atividades novas chegam pelo cron de 6h (e o sync da web).
- **HealthKit, comida em onças, widgets "Próximo treino" e de tela bloqueada**: fora deste plano.

## 3. Fases

Cada fase termina com uso real por alguns dias, como na spec anterior. Toda fase começa portando a lógica pura da web pro `SoTreinaKit`, com os testes da web traduzidos (§5.3).

### Fase S — Shell (com spikes)

A casca que todas as áreas usam, mais os testes de viabilidade que podem mudar o plano. **Spikes primeiro**, cada um com resultado registrado no `ios/README.md`:

1. **App Group** (bloqueia widgets): declarar `com.apple.security.application-groups` no app e numa extensão de widget, escrever um arquivo no container compartilhado pelo app e ler no widget. Verificar se o xtool aplica entitlements customizados e se o perfil do Apple ID grátis aceita App Group. Se falhar, widgets saem do plano.
2. **Localização**: `Localizable.strings` em `pt.lproj`/`en.lproj` como recurso SwiftPM (o `.xcstrings` precisa do `xcstringstool` do Xcode, provavelmente indisponível — confirmar). Testar troca de idioma em runtime pelo seletor.
3. **Fontes**: Geist/Geist Mono como recurso, registradas em runtime com `CTFontManagerRegisterFontsForURL` (o `UIAppFonts` do Info.plist espera arquivo na raiz do bundle, e o SwiftPM põe recursos num sub-bundle). Conferir `Font.custom(_:size:relativeTo:)` acompanhando Dynamic Type.
4. **Screenshot pelo cabo**: `idevicescreenshot` no iOS 27 exige a Developer Disk Image montada (personalizada desde o iOS 17). Se o `libimobiledevice` do Ubuntu não montar, testar `pymobiledevice3`. Se nada funcionar, a validação volta a ser "o usuário descreve".

Depois dos spikes:
- **Tokens de design** (`DesignSystem`): cores claro/escuro espelhando `client/src/index.css` (neutros quentes, `--acc` mostarda `#D9A441`, `--acc-tx`, `--acc-fg`, `--bar`, `--neg`, `--pos`), raios, espaçamentos e estilos de texto (números de destaque em Geist Mono). **Texto sobre mostarda é sempre escuro** (`acc-fg`), regra da web. Troca do azul atual (`#3987E5`) pelo mostarda, incluindo a Live Activity.
- **Tema**: `preferredColorScheme` a partir do seletor (Auto/Claro/Escuro), persistido por dispositivo.
- **Navegação**: `TabView` (Hoje, áreas ativas, Perfil), header de área (título grande + abas de texto das sub-páginas) e push com `NavigationStack` pros drill-downs. Abas de áreas ainda não portadas mostram um aviso "Em breve no app — use a web" com link pro site.
- **Sessão minimizável**: a sessão atual vira `fullScreenCover`; "minimizar" fecha e mostra a barra de treino em andamento acima da tab bar.
- **Cache JSON** (§5.2) aplicado ao que já existe (rotinas, treino ativo).
- **Entrada**: cadastro (`POST /auth/register` e, em seguida, `POST /auth/token` com as mesmas credenciais pra obter o Bearer — sem mudar o backend), esqueci a senha (`POST /auth/forgot-password`; o link do email abre a web em `/redefinir-senha`, que já funciona), e escolha de áreas (`PATCH /users/me` com `enabledAreas`) quando a lista vier vazia.
- **Perfil**: nome (`EditName`), áreas, metas (semanais e diária de dieta), tema, idioma, unidades, sair.
- **Unidades (backend + web + app)**: §6.1.
- **Idioma no backend**: o app deixa de mandar `Accept-Language: pt` fixo e passa a mandar o idioma escolhido.

### Fase T — Treino completo

Portar `features/gym/` inteiro, além da sessão que já existe:
- **Visão geral**: treinos da semana vs semana passada (Geist Mono grande), faixa Volume/Exercícios/Tempo, "Próximo treino" com Iniciar/Continuar, calendário mensal (`GymCalendar`), recorde por exercício com busca, lista de rotinas.
- **Rotinas**: lista, detalhe (somente leitura), detalhe do exercício (imagens do `free-exercise-db`, chips, instruções), **criar/editar rotina** (busca multi-seleção, steppers de séries/faixa de reps/descanso, reordenar com `.onMove`, confirmação ao descartar alterações, uma chamada só no Salvar — mesmo modelo do `useRoutineEditor`).
- **Histórico**: KPIs, barras de volume semanal (Swift Charts), "Recentes" agrupados por semana, detalhe do treino, detalhe do exercício na sessão com 1RM estimado (Epley).
- **Sessão**: o que existe, mais **atualizar rotina ao finalizar** (o prompt `syncTemplate` da web) e **treino livre** (`POST /workouts` sem `templateId`). **Treino livre é exceção registrada à paridade**: entra só no app por decisão do usuário.
- Pesos em kg ou lb (§6.1), com passos de ±2,5 kg / ±5 lb.

### Fase D — Dieta

- **Dia**: kcal em Geist Mono + barra (vira `--neg` acima da meta), faixa de macros com opacidades 1/.7/.45, refeições configuráveis com modo de edição (reordenar, renomear pelo vocabulário fechado, apagar com a contagem de `logCount`).
- **Adicionar refeição**: busca local com debounce, carrinho local, **QuantitySheet** (unidade/gramas, atalhos, prévia de kcal/macros, trocar de modo carrega o peso), editar item do carrinho e log já salvo (`PATCH` otimista), cadastro manual (normaliza pra 100 g, unidade opcional).
- **Scanner nativo**: `DataScannerViewController` restrito a EAN-13/EAN-8/UPC-A/UPC-E, `GET /foods/barcode/:code`, 404 → cadastro manual pré-preenchido. Exige `NSCameraUsageDescription` e checar `DataScannerViewController.isSupported`.
- **Refeições salvas**: lista, editor e aplicar ao dia.
- **Histórico 7/14 dias** (Swift Charts, linha tracejada da meta, seleção sincronizada com a lista) e **meta diária** (steppers com a faixa de validação de macros).
- Dia sempre em fuso local: o app manda `X-Time-Zone` com o fuso do iPhone (hoje só a web manda; o backend cai pra UTC sem ele).

### Fase C — Corrida

- **Visão geral**: totais all-time, calendário, recordes pessoais (12 distâncias, top 3 expansível, selo PR), tênis com progresso de 800 km.
- **Atividades**: resumo da semana (mobile da web: semana em Geist Mono comparada com a passada, 3 KPIs, barras de 12 semanas), lista agrupada por semana, filtro de período.
- **Detalhe**: stats, **mapa em MapKit** (polyline decodificada do `summaryPolyline`; placeholder pra esteira), tabela de voltas, "View on Strava".
- **Editor de voltas** (**fora da Fase C desde 2026-10-23**, decisão do usuário: corrigir voltas continua na web; ver `.scratch/app-ios-completo/issues/36-corrida-editor-voltas.md`): mesmo modelo da web com controles nativos — lista com `.onMove`, tamanho por distância ou tempo, `+ Volta`/`+ Repetições`, barra de cobertura ao vivo, Salvar só com cobertura completa, confirmação ao fechar com alterações. `lapBoundaryMath` portado pro Kit com os mesmos testes (inclusive a âncora de distância e a tolerância de 60 s).
- Distância e pace em km ou mi (§6.1).
- Análise continua fora (está desabilitada na web).

### Fase H — Hoje

Cópia da web: status do dia por área, barras dos últimos 7 dias, "Por área" contra as metas (lápis abre as metas semanais), feed misto, e a versão de uma área só (`TodaySingleArea`). Toda derivação portada de `todayStatus.ts` pro Kit com testes.

### Fase W — Widgets (descartada em 2026-10-22)

> **Descartada.** O teste do App Group mostrou que o xtool remove o entitlement em conta grátis e sobrescreve o grupo de Keychain, então não há como o widget obter dados do app. O usuário preferiu tirar os widgets a manter um patch no xtool. Detalhes em `ios/README.md` › Widgets e no ticket do mapa `.scratch/app-ios-completo`.

Extensão de widget (separada da Live Activity ou no mesmo `WidgetBundle`):
- **Dieta do dia** (pequeno/médio): kcal vs meta e macros.
- **Semana** (pequeno/médio): km corridos e treinos vs metas semanais.

O app grava um resumo no container do App Group a cada atualização e chama `WidgetCenter.reloadTimelines`; o widget só lê, sem rede e sem token.

## 4. Fora de escopo

Login/conexão/desconexão Strava, adicionar senha, sync manual, Análise da corrida, HealthKit, escrita offline, comida em onças, widgets de tela bloqueada e "Próximo treino", notificações push remotas. Continuam na web o que estiver nessa lista.

## 5. Arquitetura

### 5.1 Módulos

- **App** (`Sources/SoTreina/`): `App/` (entrada, gate de sessão, abas), `Core/` (API, cache, sessão, tema, idioma, unidades, fontes), `DesignSystem/` (tokens e componentes: header de área, abas de texto, KPI, número grande, barra de progresso, chips, stepper), `Features/{Today,Run,Gym,Diet,Profile,Auth}/`.
- **`SoTreinaKit`**: modelos `Codable` de todos os endpoints usados, formatação, conversão de unidades e toda a lógica portada da web. Continua sem UIKit/SwiftUI/rede, testado com `swift test` no Linux.
- **Extensões**: `SoTreinaLiveActivity` (existente) e, na Fase W, os widgets.

### 5.2 Dados

- Um `@Observable` store por área (como o `WorkoutStore`), dono do fetch e das mutações daquela área. Mutações continuam devolvendo o objeto completo e substituindo o estado; as que podem chegar fora de ordem rodam em fila.
- **Cache JSON**: `ResponseCache` grava a última resposta de cada `GET` em `Caches/<userId>/<chave>.json`. Abrir uma tela mostra o cache na hora e busca por trás (stale-while-revalidate). O cache é por usuário e é apagado no logout e no 401. Chave = path + query normalizada. Sem expiração por tempo: a resposta nova sempre substitui.
- **Escritas exigem rede**. Falha mostra ⚠ com reenvio, no padrão do treino. Registros diários (log de comida) usam o mesmo raciocínio de idempotência quando houver risco de duplicar num reenvio (avaliar `clientId` em `POST /food-logs` na Fase D).

### 5.3 Port da lógica da web

Toda função pura que a web tem pra uma tela entra no Kit **com os testes da web traduzidos** (Vitest → Swift Testing), pra que as duas interfaces calculem igual. Lista inicial: `todayStatus.ts`, `bins.ts`, `historyBins.ts`, `quantityFormat.ts`, `lapBoundaryMath.ts`, `routineFormat.ts`, `relativeTime.ts` (já portado), `activityFormat.ts`, `prSnapshot.ts`, `polyline.ts`.

### 5.4 Strava

Assets oficiais copiados sem alteração de `client/src/assets/strava/` pra `ios/Resources/`. "Powered by Strava" nos mesmos pontos da web (rodapé de Atividades, Visão geral e detalhe; claro/escuro conforme o tema) e "View on Strava" (texto literal, `#FC5200`, bold) no detalhe da atividade. Conta só-Strava não entra no app (§2), então o app nunca precisa do fluxo de conexão.

## 6. Mudanças fora do app

### 6.1 Unidades (backend + web + app)

- **Backend**: `User.distanceUnit` (`KM`/`MI`, default `KM`) e `User.weightUnit` (`KG`/`LB`, default `KG`), no mesmo `PATCH /users/me` e no `MeResponse`. Migration DDL com defaults (compatível com o código antigo).
- **Banco continua em km e kg**. Conversão só na exibição e na entrada: `weightKg` é `Decimal(6,2)`, então 45 lb → 20,41 kg → exibido 45,0 lb. Volume, PRs e propostas de série comparam sempre em kg.
- **Escopo**: lb só na musculação (séries, volume, PRs, recordes por exercício). mi afeta distância e pace da corrida e as metas semanais de km. Comida continua em gramas.
- **Web**: o "Quilômetros (km)" estático do Perfil vira seletor real, e as telas de corrida e academia passam a respeitar a preferência (paridade).
- **Kit**: `UnitConversion` com testes de ida e volta (arredondamento de exibição, passos de ±2,5 kg / ±5 lb).

### 6.2 Outros

- `Accept-Language` segue o idioma do app; `X-Time-Zone` passa a ser enviado pelo app.
- Nenhum endpoint novo previsto além das unidades. O cadastro usa `register` + `token`.

## 7. Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| App Group indisponível com xtool/Apple ID grátis | Sem widgets | Spike na Fase S; widgets saem do plano se falhar |
| `.xcstrings` não compila sem Xcode | Localização mais trabalhosa | `.strings` em `.lproj` (spike) |
| Screenshot pelo cabo não funciona no iOS 27 | Validação visual mais lenta | `pymobiledevice3`; senão o usuário descreve |
| Duas UIs completas divergem | Bugs e telas diferentes entre web e app | Paridade obrigatória (§9) e lógica compartilhada portada com os mesmos testes |
| Ferramentas exclusivas do Xcode (macros, metadados) | Feature não compila ou não funciona, como SwiftData e App Intents | Antes de adotar um framework novo, checar se depende de plugin/processador do Xcode |
| Reinstalação semanal de um app principal | App não abre se esquecer | Banner e notificação de expiração (já existem) |
| Escopo grande sem simulador | Ciclo lento | Máximo de lógica no Kit; uma área por fase |

## 8. Validação

- Lógica: `swift test` no Kit, com os testes portados da web.
- Visual: por tela, screenshot do iPhone (`idevicescreenshot` ou `pymobiledevice3`) lado a lado com a mesma tela da web mobile (skill `run-sotreina --mobile`), nos dois temas.
- Cada fase fecha com um checklist no `ios/README.md`, como a Fase 0.

## 9. Paridade web ↔ app

- **Regra**: a partir do fim da fase em que uma área chega ao app, toda mudança de comportamento ou tela nela entra **no backend, na web e no iOS** na mesma fatia vertical. Áreas ainda não portadas não bloqueiam a web.
- **Exceções registradas**: treino livre (só no app, por decisão do usuário). Novas exceções precisam ser registradas aqui e no `CLAUDE.md`.
- Ao fim de cada fase, o `CLAUDE.md` ganha a área na seção "App iOS" e a regra passa a valer pra ela.

## 10. Convenções

As da spec anterior continuam: tudo que não desenha tela vai pro `SoTreinaKit`; strings voltadas ao usuário em PT e EN; textos sobre mostarda em `acc-fg`; nenhum framework que dependa de ferramenta exclusiva do Xcode sem spike antes.
