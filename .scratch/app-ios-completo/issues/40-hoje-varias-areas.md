# Hoje: várias áreas

Type: task
Status: resolved
Blocked by: 39

## Question

Portar o Hoje de 2–3 áreas (`client/src/features/today/TodayPage.tsx`, Redesign 18a/21): data no cabeçalho, status do dia por área (Corrida = correu hoje; Treino = treino finalizado hoje, senão "<próxima rotina> pendente" via `RoutineFormat.nextRoutine`, ou o treino aberto; Dieta = ≥ 90% da meta de kcal), barras dos últimos 7 dias (áreas concluídas por dia, `countDone`), "Por área" contra as metas semanais (Corrida/Treino) e a meta diária de kcal, com o lápis empilhando as metas semanais do Perfil, e o feed misto (5 itens). Só as áreas ligadas entram (`enabledAreas`). `todayStatus.ts` vai pro Kit (`TodayStatus`) com os testes de `todayStatus.test.ts` traduzidos, inclusive `buildDailyValues`, que a [Hoje: uma área só](41-hoje-uma-area.md) usa. Dias em fuso local, semana começando na segunda, distância na unidade do usuário. Os dados vêm das stores do shell, sem fetch próprio. Os toques trocam pra aba da área. O padrão do `selectedTab` vira Hoje, e "Hoje" entra no `AreaScreen.portedPages`. Com uma área só ligada, até a próxima tarefa, o Hoje mostra a mesma tela filtrada. "Powered by Strava" no rodapé quando a Corrida está ligada e há Strava conectada, como na web. Termina com o checklist da Fase H no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Sem mudança no backend. Regras da fase em [Fatiamento da Fase H (Hoje)](39-fatiamento-fase-h.md).

## Answer

**Feito e validado (2026-10-24).** Galeria e linhas 01–07 da Fase H aprovadas pelo usuário no iPhone.

- **Kit**: `TodayStatus` (`SoTreinaKit/Sources/SoTreinaKit/TodayStatus.swift`), port de `todayStatus.ts`: `isDietDone`, `percent`, `lastNDays`, `buildDays`, `countDone`, `buildDailyValues` (pronto pra [Hoje: uma área só](41-hoje-uma-area.md)), `buildTotals`, `buildFeed` (filtra por área, ordenação estável) e `calendarDaysAgo`. Testes de `todayStatus.test.ts` traduzidos em `TodayStatusTests.swift` (15 novos, 354 no total).
- **Tela**: `ios/Sources/SoTreina/Features/Today/TodayView.swift`. Lê as stores do shell (`RunStore`, `GymHistoryStore`, `WorkoutStore`, `DietStore`, `DietHistoryStore`, `ProfileStore`) e chama o `load` só das áreas ligadas, ao aparecer, ao puxar e ao voltar pro primeiro plano. O "agora" é renovado a cada carga, então uma aba deixada aberta na virada do dia muda pro dia novo. Corrida só entra com Strava conectada, e aí aparece o "Powered by Strava".
- **Navegação**: `TabBarState.open(page)` faz o pop até a raiz da aba (`popTokens`) e deixa um pedido de página (`pageRequests`), que o `AreaScreen` aplica, inclusive na primeira montagem da aba. O `AppShell` troca a aba. Com uma área só não há aba pra onde ir, então o toque não faz nada (fica pra próxima tarefa). O `selectedTab` padrão virou `today`. O `AreaScreen.portedPages` não mudou: o Hoje não é um `AppPage` e não tem sub-páginas.
- **Lápis**: empilha o `WeeklyGoalsView` do Perfil com `.hidesFloatingTabBar()`, desabilitado até o `/users/me` carregar.
- **Strings**: `today.status/days/areas/feed.*` em PT/EN, com plurais no `.stringsdict` (com `zero`, como os outros). `today.areas.runGoal` recebe a meta já na unidade de exibição (`%lld`).
- **Desvio aceito**: lápis em SF Symbol, onde a web usa o lucide.
- Sem mudança no backend.
