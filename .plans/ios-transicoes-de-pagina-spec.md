# Transições de página no app iOS — spec

_Entrevista em 2026-10-26. Área: `ios/` (ler `docs/claude/ios.md` antes). Ao terminar, atualizar `docs/claude/ios.md` (pílula, `AreaScreen`, "Hoje")._

## 1. Problema

No app iOS, trocar de "página" é seco:

- **Aba pela pílula** (Hoje ↔ Corrida ↔ Treino ↔ Dieta): o `AppShell` usa um `TabView` com a barra do sistema escondida, e a troca do `TabView` é instantânea e não aceita animação. Só o chip da pílula desliza.
- **Sub-página do cabeçalho** (Visão geral ↔ Atividades; Visão geral ↔ Rotinas ↔ Histórico; Visão geral ↔ Histórico): o `AreaHeader` troca `page` e o `AreaScreen` troca a view no lugar (o próprio comentário diz "Switching is instant"). O sublinhado mostarda pula.
- **Atalho do Hoje** (tocar numa célula leva pra página da área): `tabBar.open(page)` + troca de aba, os dois secos.

Objetivo: transições suaves, discretas e consistentes, sem perder nada do comportamento atual (pilha de navegação viva por aba, posição de rolagem, recarga ao entrar na aba, pop-to-root/scroll-to-top da pílula).

## 2. Decisões (da entrevista)

| Tema | Decisão |
|---|---|
| Escopo | Abas pela pílula, sub-páginas do cabeçalho e atalhos do Hoje. Pushes do `NavigationStack` ficam com o deslize do sistema (fora do escopo) |
| Estilo da troca de aba | **Fade + leve subida**: o corpo da aba nova entra com opacidade e sobe 8pt; sem deslocamento lateral, sem direção |
| Cabeçalho na troca de aba | "Moldura fixa": avatar parado, título e sub-abas fazem crossfade no lugar, só o corpo sobe |
| Sub-páginas | **Mais leve que a aba**: só crossfade curto (~180ms), sem subida. O sublinhado mostarda **desliza** até a nova sub-aba (mesma curva do chip da pílula) e a cor do texto troca com fade |
| Hoje → área | Igual à troca de aba. A sub-página já aparece certa: nenhuma segunda animação (nem do sublinhado) depois |
| Repetição | Toda troca anima, inclusive voltar pra uma aba já visitada (a rolagem continua onde estava, só entra com fade + subida) |
| Duração | Rápida: corpo 220ms ease-out; a aba antiga some ao fim (ver §4.2) |
| Reduzir movimento | Vira só fade (sem subida, sem sublinhado deslizando: o sublinhado faz fade), ~150ms |
| Gesto | Só toque. Nada de swipe horizontal (conflitaria com carrosséis, gráficos com scrub e o voltar por borda) |
| Extras | Nenhum: sem fade de chegada de dado da rede, sem vibração nas sub-páginas |
| Arquitetura | `TabView` sai; entra um **ZStack próprio com abas vivas** (montam na 1ª visita e ficam) |
| Rolagem das sub-páginas | Continua recriando a cada troca (voltar pra Visão geral começa do topo, como hoje) |
| Recarga ao entrar na aba | **Preservada**: voltar pra uma aba recarrega como hoje; o polling da primeira importação da Strava só roda com a aba ativa |
| Validação | Uso normal no iPhone + gravação de tela; tempos centralizados em tokens no Kit pra ajustar números |

## 3. Comportamento esperado

### 3.1 Troca de aba (pílula)

1. Toque num ícone da pílula (aba diferente da atual). O chip desliza como hoje (`.snappy(0.32)`, vibração `.selection`).
2. A aba nova é posta **por cima** da antiga e faz fade-in de 0 → 1 em 220ms ease-out. A antiga **fica opaca embaixo** durante esse tempo e só é escondida quando a nova termina.
   - Por que assim, e não "a antiga some em 120ms enquanto a nova aparece": com as duas cruzando opacidade, o avatar (idêntico nas duas abas) e o fundo `pageBg` piscariam a ~50% no meio. Com a nova por cima da antiga opaca, pixels iguais ficam firmes (avatar, fundo, hairline) e só o que difere (título, sub-abas, corpo) cruza — que é exatamente a "moldura fixa" decidida.
3. Junto, **só o corpo** da aba nova (o `content(page)` do `AreaScreen`, abaixo do `AreaHeader`) começa 8pt abaixo e sobe até 0 nos mesmos 220ms ease-out. O cabeçalho da aba nova não se desloca.
4. Toque rápido em sequência: o último toque vence. A aba "antiga" da nova transição é a que estiver por cima naquele momento (mesmo que no meio do fade); qualquer aba que não seja nem a nova nem essa é escondida na hora. A conclusão de uma transição velha nunca esconde a aba que acabou de virar ativa (token de geração).
5. Tocar na aba já selecionada continua sendo `TabReselect` (pop-to-root ou scroll-to-top) — sem transição de página.

### 3.2 Troca de sub-página (cabeçalho)

1. Toque numa sub-aba diferente: o sublinhado desliza até ela (`matchedGeometryEffect`, `.snappy(0.32)`), o texto ativo/inativo troca de cor com fade.
2. O corpo faz crossfade de 180ms: a sub-página antiga e a nova ficam sobrepostas (ZStack, não empilhadas no `VStack`, senão o layout pula) e cruzam opacidade. Sem subida.
3. A sub-página nova é recriada (estado e rolagem do zero, como hoje).

### 3.3 Hoje → área

1. `TabBarState.open(page)` + `selectedTab` como hoje. A troca de sub-página que isso provoca na aba destino é aplicada **sem animação** (transação com `disablesAnimations`), e a troca de aba roda a §3.1.
2. Vale tanto pra aba destino já montada (o `onChange` de `pageRequests` dispara antes da transição) quanto pra aba montada pela própria requisição (`initial: true`).

### 3.4 Reduzir movimento

- Aba: fade-in da nova por cima em 150ms, sem subida.
- Sub-página: crossfade de 150ms; o sublinhado faz fade no lugar em vez de deslizar.
- Mesma regra da entrada e da pílula (`accessibilityReduceMotion`).

### 3.5 O que não muda

- Cada aba mantém sua pilha (`NavigationStack`/`NavigationPath`) e a rolagem ao sair e voltar.
- `@SceneStorage("selectedTab")`, a regra de aba de área desligada caindo em `tabs[0]` e o `ValidationLaunch.tab`.
- `tabBar.expand()` na troca de aba e no primeiro plano.
- Pushes, sheets, `fullScreenCover` do treino, menu da conta (exceto o fechamento na troca, §4.3).

## 4. Implementação

### 4.1 Tokens e regra no Kit (`SoTreinaKit`, com teste)

Tudo que não desenha tela vai pro Kit. Novo `PageTransition.swift`:

- Tokens: `tabFadeIn = 0.22`, `tabRise = 8` (pt), `subpageCrossfade = 0.18`, `reducedFade = 0.15`, curva do sublinhado = a do chip (0.32).
- Regra pura: dado `(de, para, reduceMotion)` em termos de aba/sub-página → qual transição (`.tab(rise:duration:)`, `.subpage(duration:)`, `.none` quando é a mesma). Hoje → área resolve como `.tab` com a sub-página aplicada sem animação.
- Regra da fila de transições de aba (§3.1 item 4): estado `(ativa, porBaixo, geração)` → após um novo toque, quais abas ficam visíveis e qual geração a conclusão precisa bater pra esconder a de baixo. Testável sem SwiftUI.

Testes em `Tests/SoTreinaKitTests/PageTransitionTests.swift`: mesma aba = nenhuma; reduce motion = sem subida e 150ms; toques rápidos A→B→C escondem A na hora e só escondem B na conclusão da geração de C; conclusão de geração velha não esconde nada.

### 4.2 `AppShell`: ZStack no lugar do `TabView`

- `ForEach(tabs)` dentro de um `ZStack`, cada aba montada **na primeira vez que fica ativa** (conjunto `mountedTabs`, como o `TabView` fazia) e mantida viva depois.
- Por aba: `opacity` (1 se ativa ou "por baixo", 0 se não), `zIndex` (a ativa no topo, a de baixo logo abaixo), `.allowsHitTesting(ativa)`, `.accessibilityHidden(!ativa)`.
- A troca: ao mudar `selection`, a nova recebe opacidade 0 → 1 com `withAnimation(.easeOut(duration:), completionCriteria: .logicallyComplete) { … } completion: { … }` (iOS 17+, o alvo é 18). A conclusão esconde a de baixo se a geração bater (§4.1).
- Injeta no environment de cada aba `\.tabActivation`: um valor `(isActive: Bool, generation: Int)` que muda a cada ativação dela. É o sinal que substitui o `onAppear`/`onDisappear` que o `TabView` disparava.
- VoiceOver: na ativação, `AccessibilityNotification.ScreenChanged` com o título da aba, já que o foco não se move sozinho entre camadas.
- O `.toolbar(.hidden, for: .tabBar)` em volta de cada `NavigationStack` (`AreaScreen`) deixa de ser necessário (não há mais `TabView`); remover, e conferir que os pushes continuam sem barra do sistema. O comentário do `AppShell` sobre "o `TabView` é mantido pelo que guarda" muda.

### 4.3 `AreaScreen`

- **Subida do corpo**: `content(page)` ganha `.offset(y:)` lido da ativação: ao virar ativa, coloca 8pt sem animação e anima pra 0 em 220ms ease-out (zero com reduzir movimento). O `AreaHeader` não recebe offset.
- **Sub-página**: o corpo vira `ZStack { content(page).id(page).transition(.opacity) }` com a troca de `page` feita em `withAnimation(.easeInOut(duration: 0.18))` (no `AreaHeader`). O `pageRequests` aplica `page` em transação sem animação (§3.3).
- **Menu da conta**: hoje fecha no `onDisappear` (troca de aba ou push). Na troca de aba isso não dispara mais → fechar também quando `tabActivation.isActive` virar `false`. O fechamento por push continua no `onDisappear`.
- **`atRoot` da pílula** (`setAtRoot` no `onAppear`/`onDisappear` da raiz): continua correto, porque o push/pop dentro do `NavigationStack` ainda dispara esses eventos e o valor de uma aba inativa não é lido (`TabReselect` só olha a selecionada). Conferir no aparelho; não mudar se funcionar.

### 4.4 `AreaHeader`

- Sublinhado único com `matchedGeometryEffect(id: "underline", in:)` desenhado só na sub-aba ativa (hoje cada botão desenha o seu, transparente nos inativos), `.snappy(0.32)`; com reduzir movimento, fade no lugar.
- Cor do texto anima junto (`.animation(_, value: selection)`).
- Atualizar o doc comment ("Switching is instant").

### 4.5 Recarga ao entrar na aba (preservar)

Com o `TabView`, toda `.task` da raiz de uma aba rodava de novo ao voltar pra ela. No ZStack a view não "desaparece", então:

- Modificador novo (no `FloatingTabBar.swift`, junto dos outros da pílula, ou num `TabActivation.swift` em `App/`): `.taskOnTabActivation { await … }` = `.task(id: tabActivation.generation) { guard tabActivation.isActive else { return }; … }`.
- Trocar o `.task` de carga das telas hospedadas em aba por ele. Auditoria (grep de 2026-10-26): `RunOverviewView`, `RunActivitiesView`, `DietOverviewView`, `DietHistoryView`, `GymOverviewView` (`history.load()`), `GymHistoryView`, `TodayView` (`load()`), e as telas empilhadas dentro das abas que recarregam ao reaparecer (`RunActivityDetailView`, `WorkoutHistoryDetailView`, `RoutineDetailView`, `RoutineExerciseDetailView`, `SavedMealsListView`) — para estas, confirmar uma a uma se a recarga ao voltar pra aba importa; o padrão é preservar.
- **Polling da primeira importação** (`RunStravaViews.swift`, `.task(id: store.firstSync == .notStarted)`): a chave passa a incluir `isActive`, e o polling só roda com a aba ativa (era o "só com a tela visível").
- O fetch roda em paralelo com a animação e atualiza no lugar; não mostrar spinner por cima de dado já carregado (as stores já guardam o último estado — conferir que nenhuma zera ao recarregar).
- `.floatingTabBarScroll()` zera `scrolling` no `onDisappear`: passar a zerar também na desativação da aba (senão a pílula pode ficar encolhida ao trocar de aba no meio de uma rolagem por inércia).

### 4.6 Validação de lançamento

Sem destino novo. O `ValidationLaunch.tab` continua abrindo a aba sem transição (primeira montagem não anima: a aba inicial já nasce ativa e opaca, sem subida).

## 5. Riscos e cuidados

- **Views ocultas com opacidade 0 continuam vivas**: animações contínuas ou timers numa aba escondida seguem rodando (ex.: gráficos que animam na chegada). Se algo pesar, pausar pela `tabActivation`. Medir memória no aparelho com as 4 abas visitadas (o `TabView` já mantinha as 4 vivas, então não deve mudar muito).
- **`hidesFloatingTabBar`** é um contador global por `onAppear`/`onDisappear`. Hoje nenhuma tela que esconde a pílula permite trocar de aba (a pílula some), então não muda; anotar no código.
- **`fullScreenCover` e sheets** ficam no `AppShell`/nas telas como hoje; o ZStack não deve ser o dono de nenhum `.sheet` que dependa de a aba estar visível.
- **Teclado**: a pílula tem `.ignoresSafeArea(.keyboard)`; o ZStack não pode empurrar abas inativas com o teclado de uma ativa (todas compartilham o mesmo container — conferir a Dieta com a busca aberta antes de trocar).
- **Pull-to-refresh e `scrollPosition`** por aba seguem nas telas; nada no ZStack mexe nisso.

## 6. Critérios de aceite (no iPhone, gravação de tela)

1. Corrida → Treino: título/sub-abas cruzam no lugar, avatar não pisca, corpo sobe 8pt em ~220ms, sem flash do fundo.
2. Treino ▸ Visão geral → Rotinas: sublinhado desliza, corpo cruza em ~180ms sem pular de altura.
3. Hoje → célula do Treino: uma transição só; a sub-página certa já aparece; o sublinhado não anima depois.
4. Toques rápidos Hoje → Corrida → Dieta: termina na Dieta, sem aba presa visível nem toque caindo numa aba escondida.
5. Voltar pra Corrida depois de rolar e abrir uma atividade: mesma pilha e rolagem, e a lista recarrega (log `GET /activities… -> 200` no `ios/scripts/logs.sh`).
6. Primeira importação da Strava: polling para ao sair da Corrida e volta ao entrar.
7. Menu da conta aberto + toque na pílula: o menu fecha.
8. Retocar a aba ativa: pop-to-root / scroll-to-top como antes.
9. Reduzir movimento ligado: só fades, nenhum deslocamento, sublinhado não desliza.
10. VoiceOver: ao trocar de aba, o foco anuncia a nova aba; nenhum elemento de aba oculta é alcançável.
11. `cd ios/SoTreinaKit && swift test` verde com os testes novos do `PageTransition`.

## 7. Fatias

1. **Kit**: `PageTransition` (tokens + regras + testes).
2. **Shell**: ZStack + `tabActivation` + `.taskOnTabActivation` + auditoria de `.task` + menu/scroll na desativação (§4.2, §4.3 menu, §4.5). Sem animação ainda: validar no aparelho que nada regrediu (critérios 5–8, 10).
3. **Movimento**: fade + subida da aba, crossfade da sub-página, sublinhado, Hoje → área sem segunda animação, reduzir movimento (critérios 1–4, 9).
4. **Docs**: `docs/claude/ios.md` (pílula/`AreaScreen`/Hoje: troca animada, `TabView` removido, regra "tela de aba carrega com `.taskOnTabActivation`, não `.task`") e, se aparecer algo surpreendente no SwiftUI/xtool, `docs/claude/learnings.md`.

## 8. Fora do escopo

- Swipe entre abas ou sub-páginas.
- Fade de chegada do dado da rede (spinner → conteúdo).
- Vibração na troca de sub-página.
- Preservar a rolagem das sub-páginas.
- Zoom/matched geometry da célula do Hoje pra página.
- Mudanças nos pushes do `NavigationStack`.
