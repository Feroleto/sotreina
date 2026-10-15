# Spec — Animações pra dar vida ao SoTreina

Data: 2026-10-15 · Status: **Fase 1 commitada** (`92b19c7`) · **Fase 2 implementada** (aguardando validação e commit) · Fase 3 pendente
Precedente: animação do hero do login (`features/auth/HeroTrace.tsx`, bloco `.hero-*` em `index.css`)

## 1. Objetivo

Hoje o app quase não tem movimento. Só o drawer mobile, o colapso da sidebar e algumas barras de progresso se mexem. A troca de página é um corte seco, gráficos e anéis aparecem prontos, e os momentos de conquista passam em branco. O objetivo é dar vida em três frentes, apontadas pelo usuário:

1. **Troca de página e de tela** (navegação e drill-down)
2. **Chegada do dado** (gráficos, anel, listas, loading)
3. **Momentos de conquista** (treino finalizado, novo PR, primeiro sync)

Microinterações de uso diário **não** são foco. Ficam só no feedback de toque do treino ao vivo, ver §6.4.

## 2. Princípios (decididos na entrevista)

| Decisão | Escolha |
| --- | --- |
| Personalidade | **Mista por contexto**: discreta no uso diário (ease-out forte, 150–250ms, sem bounce) e energética **só** em momentos raros (springs com bounce 0.1–0.3, count-up) |
| Biblioteca | **Adotar Motion (`motion` / `motion/react`) já**. CSS continua valendo onde basta (hover, press, transições de classe) |
| Teto de celebração | **Contido**: números contando, pop com spring leve, glow/anel em `--acc`. **Sem confete nem partículas** |
| Repetição de celebração | **Uma vez por evento**, lembrada em `localStorage` (recarregar não repete) |
| Repetição de entrada (gráfico/lista) | **Uma vez por sessão por página**, registrada em memória (módulo JS, não `localStorage`). Revisitas mostram o conteúdo pronto. Recarregar a aba anima de novo |
| Boot otimizado (dado já pronto no 1º paint) | A entrada **roda igual**: a animação de entrada independe de ter havido skeleton |
| Reduced motion | Obrigatório em todo item, entregue junto. Movimento vira fade de opacidade ou nada, segundo a regra já registrada no CLAUDE.md: `duration-*` também atrás de `motion-safe:`. No Motion, usar `useReducedMotion()` / `MotionConfig reducedMotion="user"` |

### Tokens de movimento (fundação)

Criar uma vez e reaproveitar. Nada de curvas avulsas por componente.

- CSS, em `index.css` → `:root`, com nomes que **não colidam** com o tema do Tailwind v4 (`--ease-out` já é variável de tema dele):
  - `--motion-ease-out: cubic-bezier(0.23, 1, 0.32, 1)`: entradas e saídas
  - `--motion-ease-in-out: cubic-bezier(0.77, 0, 0.175, 1)`: movimento na tela
  - `--motion-ease-drawer: cubic-bezier(0.32, 0.72, 0, 1)`: push lateral e sheets
- JS: `client/src/lib/motion.ts` espelha os mesmos valores (`EASE_OUT`, `EASE_IN_OUT`, `EASE_DRAWER`, `SPRING_CELEBRATE = { type: 'spring', duration: 0.5, bounce: 0.2 }`), mais as durações nomeadas (`DUR.fast = 0.15`, `DUR.base = 0.2`, `DUR.page = 0.25`).
- Migrar `--hero-ease` do login pra `--motion-ease-out` (mesmo valor).

### Regras técnicas fixas

- Só `transform`/`opacity`. Exceção: `stroke-dashoffset` em gráfico de linha (já usado no hero), e `clip-path` se necessário.
- No Motion, usar **string de `transform` completa** em vez dos atalhos `x`/`y`/`scale` em telas pesadas (Analysis, sessão de treino).
- Nunca `transition: all`, nunca `scale(0)` (mínimo 0.9–0.97 + opacity 0), nunca `ease-in` em UI.
- Hover com movimento sempre atrás de `@media (hover: hover) and (pointer: fine)`.
- Nada anima em ação de teclado nem em ação de 100+ vezes por dia.

## 3. Fase 1 — Fundação + navegação + loading

### 3.1 Infra
- `npm i motion` em `client/`. Medir o bundle antes e depois e registrar o delta no CLAUDE.md (o usuário não pediu como critério, mas é barato).
- Tokens de §2 e `lib/motion.ts`.
- `lib/useFirstVisit.ts`: `useFirstVisit(key: string): boolean` lê/escreve um `Set` em escopo de módulo. Devolve `true` só na primeira montagem daquela chave na sessão. Base pra §4 e §3.4.
- `<MotionConfig reducedMotion="user">` no topo do `App.tsx`.

### 3.2 Troca de seção (menu) — View Transitions API
- Envolver a troca de `PageId` no `App.tsx` em `document.startViewTransition(() => flushSync(() => setPage(next)))`.
- Animação: crossfade + leve subida (6–8px) do conteúdo novo, **~200–250ms**, `--motion-ease-out`. A saída é só fade, mais curta (~120ms). Usar `view-transition-name` **só no painel de conteúdo**: sidebar, app bar e drawer ficam fora (`view-transition-name: none` neles) pra não "piscar" o chrome.
- **Fallback sem suporte** (Safari < 18, Firefox antigo): detectar `'startViewTransition' in document`. Sem ele, o container da página entra com o mesmo fade+subida via Motion (`initial`/`animate`, keyed pelo `PageId`). A experiência fica equivalente em todo lugar.
- Reduced motion: no CSS da VT, `@media (prefers-reduced-motion: reduce)` reduz pra crossfade de opacidade puro. O fallback Motion respeita o `MotionConfig`.
- **Riscos a validar**:
  1. Páginas são `React.lazy`. Se o chunk ainda não baixou, o snapshot "novo" da VT captura o `Suspense` fallback. Mitigação: o `PAGE_IMPORTERS` de `lib/boot.ts` já permite fazer `await` do import **antes** de chamar `startViewTransition`.
  2. A VT congela a interação durante a transição, então a duração tem que ficar curta.
  3. O `<style>` temporário de troca de tema (`transition:none!important`) não pode coincidir com uma VT.
  4. Back do navegador (drawer/detalhe empurram histórico) não deve disparar VT de seção.

### 3.3 Drill-down (lista → detalhe)
Destinos cobertos: atividade (`ActivityDetailView`), treino do histórico (`WorkoutDetailPage` → `ExerciseSessionDetailPage`), rotina (`RoutineDetailPage` → `RoutineExerciseDetailPage`), Dieta (`AddMealPage`/`GoalPage` no push-stack do `DietOverviewPage`).

- **Mobile (< md): push lateral estilo iOS.** O detalhe entra de `translateX(100%)` → 0, e voltar sai pela direita (simétrico). A tela de baixo recua levemente (`translateX(-20%)` + escurece um pouco). Usar `--motion-ease-drawer`, ~300ms na entrada e ~250ms na saída, via `AnimatePresence` do Motion (exige saída, por isso Motion). Precisa funcionar com o botão voltar do navegador, que hoje já fecha o overlay via histórico.
- **Desktop: fade + subida curta** (~200ms), igual à navegação.
- **Fora de escopo**: shared element (card que "cresce" até virar detalhe).
- Reduced motion: só fade de opacidade nos dois tamanhos.

### 3.4 Skeletons + crossfade
- Componente `Skeleton` genérico (já existe `ui/` do shadcn; conferir se tem `skeleton` e estender em vez de criar outro) com shimmer sutil. O shimmer é animação constante, então `linear`. Sob reduced motion, o shimmer vira bloco estático.
- **Atraso de ~150ms antes de mostrar o skeleton**: se o fetch voltar antes, o skeleton nunca aparece (evita flash). Implementar como hook (`useDelayedFlag(loading, 150)`).
- O conteúdo real substitui o skeleton com crossfade (~200ms).
- Telas-alvo (em ordem de impacto): Overview de Corrida, Activities/Dashboard, Analysis, Overview e Histórico de Academia, Overview e Histórico de Dieta, detalhe de atividade.
- `FirstSyncPage` já tem skeleton do shell e não muda nesta fase.

### 3.5 Como a Fase 1 ficou (desvios da spec, todos deliberados)
- **Provider do Motion não fica no `App.tsx`/`main.tsx`**: `LazyMotion` (features async via `lib/motionFeatures.ts`) + `MotionConfig reducedMotion="user"` vivem dentro do `DrillStack`. No `main.tsx` puxavam o núcleo do Motion pro entry chunk (+29,5 kB gz pra quem só abre o login). Medido: entry 78,5 → 78,8 kB gz; Motion chega só com as páginas (16,7 kB gz núcleo + 17,8 kB gz features). **Fases 2/3 devem reaproveitar o mesmo padrão** (provider local, ou extrair um `MotionProvider` compartilhado), nunca subir pro entry.
- **Fallback sem View Transitions é CSS (`.page-enter`), não Motion**: mais barato, e `animation-fill-mode: backwards` não deixa `transform` residual.
- **`view-transition-name` só existe durante a transição** (`.vt-page` no `<html>`, adicionada/removida em `navigate()`): permanente, ele transforma o painel num stacking context e prende os overlays `fixed` da página (sheets, editor de laps, scanner) **abaixo da app bar z-40** no mobile. Pego na verificação, não na leitura.
- **`DrillStack` limpa `transform`/`z-index` no `transitionEnd`**: o Motion grava o alvo `'none'` como `matrix(1,0,0,1,0,0)`, que ainda cria containing block pros `fixed` internos. Verificado via `getComputedStyle` após push/pop.
- Drill-downs cobertos: atividade (Dashboard, com bleed `-mx-5` no mobile), Histórico → treino → exercício, Rotinas → rotina → exercício, Dieta → AddMeal/Meta. Skeletons: totais da Corrida e da Academia, Activities, Analysis, Histórico da Academia, Overview e Histórico da Dieta, detalhe de atividade (agora com o botão Voltar funcional durante o loading), listas de exercícios do treino/rotina, cards de rotina.
- `useFirstVisit` já existe (com teste), mas só é consumido a partir da Fase 2.

## 4. Fase 2 — Chegada do dado

Todas as entradas desta fase são **uma vez por sessão por página** (`useFirstVisit`) e rodam também quando o dado veio pronto do boot.

### 4.1 Gráficos (só na primeira carga)
- **Linha/área** (`WeeklyChart`, gráficos de linha da Analysis): a linha desenha via `pathLength=1` + `stroke-dashoffset` (mesma técnica do hero), ~700ms `--motion-ease-out`, e a área faz fade logo depois.
- **Barras** (histórico da Dieta, barras semanais de volume da Academia, `MobileWeeklySummary`, histograma da Analysis): `scaleY` a partir da base (`transform-origin: bottom`, `transform-box: fill-box` em SVG), com stagger de 25–35ms limitado a ~400ms no total.
- **Trocar período, passar o mouse, tocar numa barra: instantâneo.** Nenhum morph entre datasets (decisão: "só na primeira carga").
- **Analysis (9 gráficos)**: cada `AnalysisCard` dispara a entrada **ao entrar na viewport** (IntersectionObserver / `whileInView` com `once: true`), não no mount. A regra vale pra qualquer card abaixo da dobra em outras páginas.

### 4.2 Anel de calorias e barras de macro (Dieta)
- `NutritionRing`: o preenchimento anima do valor anterior pro novo (`stroke-dashoffset`), ~500ms. No mount, de 0 até o valor (respeitando `useFirstVisit`). Ao adicionar ou remover alimento, transição do valor antigo pro novo, sempre (é feedback de uma ação rara, não entrada).
- **Faixa da meta**: perto da meta (±3–5%, usar o mesmo critério de cor que o `DietHistoryPage` já aplica) o tom é `--acc`. Acima da faixa, o anel transiciona a cor pra `--neg`. **Sem celebração** (decisão explícita: a meta de kcal não é conquista).
- `MacroBar`: hoje anima `width` (`transition-[width] duration-300`, sem gate de reduced motion). Migrar pra `transform: scaleX` com `transform-origin: left` e colocar atrás de `motion-safe:`. Mesmo tratamento pras barras de progresso do `SyncPanel` e do `LapEditorPanel`, que também animam `width`.

### 4.3 Listas (stagger só na primeira carga)
- Atividades por semana (`ActivityList`), treinos recentes (`GymHistoryPage`), lista de refeições (`DietOverviewPage`), cards de rotina (`RoutinesListPage`), recordes (`PersonalRecordsCard`), tênis (`ShoesSection`).
- Fade + subida de 6px, stagger de 30–40ms, **no máximo os ~8 primeiros itens** (o resto entra junto com o 8º).
- **Sem animação**: resultados de busca (alimento, exercício), paginação e itens adicionados ou removidos. Decisão: só primeira carga. Layout animation de add/remove fica fora.

### 4.4 KPIs e calendários
- KPIs do dia a dia (totais da Overview, carrossel do Histórico): **fade simples, sem count-up**. O count-up é exclusivo de telas de resumo/celebração.
- `RunCalendar`/`GymCalendar`: os pontos de dias com treino entram em fade com stagger por semana (curto). Navegar entre meses é instantâneo.

### 4.5 Como a Fase 2 ficou
- **Ferramenta: só CSS animation, zero Motion.** Toda entrada é predeterminada, e CSS roda fora da main thread enquanto a página ainda está carregando. Entry chunk inalterado.
- **`lib/useEntrance.ts`**: `useEntrance(key, { ready, inView })` devolve `{ attach, state }`. O `state` vai em `data-enter` do container, e as classes de `index.css` (`chart-line`, `chart-fade`, `chart-bar`, `enter-rise`, `enter-fade`, `ring-fill`, `macro-fill`) só animam sob `[data-enter='run']`. Ciclo: `pending` (esperando dado ou viewport, com os alvos em opacity 0) → `run` (janela de 1,4s) → `idle`. Depois da janela, trocar período ou mês renderiza instantâneo, porque nada fica preso a "entrada". Com movimento reduzido nunca arma.
  - `attach` é um callback ref guardado em estado, e não `useRef`: o container costuma montar só depois do loading (ex.: `ShoesSection`), e o IntersectionObserver precisa ligar quando ele aparece.
  - Os call sites **desestruturam** (`const { attach: enterRef, state: enterState } = useEntrance(...)`). Com `entrance.attach`/`entrance.state`, o lint `react-hooks/refs` trata o objeto inteiro como ref e acusa a leitura de `state` no render.
- **Barras de progresso (`MacroBar`, `SyncPanel`, `LapEditorPanel`, `FirstSyncPage`)**: `width` virou `clip-path: inset(0 X% 0 0 round …)`, e não `scaleX`. O `scaleX` achataria a ponta arredondada, e o `inset … round` mantém o raio em qualquer largura. As transições ficaram atrás de `motion-safe:`.
- **`NutritionRing`**: fica `--neg` quando `value > max`, mesma regra estrita do `DietHistoryPage` (sem faixa de ±3–5%; questão aberta da §8 resolvida assim). A troca de cor transiciona mesmo com movimento reduzido (é cor, não movimento); o preenchimento só transiciona sob `no-preference`.
- **Calendários**: o "ponto" é o próprio círculo preenchido com o número do dia, então o círculo inteiro faz fade, com stagger por semana.
- **Analysis**: a `AnalysisCard` dispara por viewport. **Não verificado visualmente**, porque `run/analysis` está desabilitada no menu (`disabled: true`) e o app cai pra Activities. Typecheck e lint ok, e as classes seguem o mesmo padrão verificado no `WeeklyChart`.
- Verificado no navegador, com `page.route` simulando dados (só GET, nada gravado): anel, macros e caso acima da meta (Dieta Overview), barras do histórico da Dieta, linha+área do `WeeklyChart`, grupos de semana, recordes, tênis (`pending` até rolar), calendário. Sob `--reduced-motion`, o estado fica `idle` desde o início.

## 5. Fase 3 — Conquistas

Teto contido: count-up, pop com `SPRING_CELEBRATE` e glow em `--acc`. Cada celebração ocorre uma vez por evento, com chave em `localStorage` (try/catch, mesmo idioma do resto do app).

### 5.1 Resumo de fim de treino (feature nova, fatia vertical)
Hoje `finish()` em `useActiveWorkout.ts` faz `setWorkout(null)` e o app volta pra lista de rotinas, sem tela de resumo.

- **Backend**: `PATCH /workouts/:id/finish` passa a devolver um resumo: `{ durationSec, volumeKg, setCount, exerciseCount, personalRecords: { exerciseId, exerciseName, weightKg, reps, previousBestKg | null }[] }`. O PR de academia é a série de maior peso daquele exercício superando o melhor **anterior** a este treino, pela mesma ordenação do `GET /exercises/:id/personal-record` (`weightKg desc, reps desc`), escopado por `userId`. Calcular dentro do finish, antes de marcar concluído ou excluindo o próprio treino da comparação. Ainda falta decidir se a primeira vez que se faz um exercício conta como PR (sugestão: **não**, `previousBestKg` nulo não celebra). Testes no padrão de `server/test/`.
- **Frontend**: nova `WorkoutSummaryPage` (em `features/gym/`), exibida depois do finish no lugar da volta direta. Sequência:
  1. Título "Treino concluído" com fade+subida.
  2. Os KPIs (duração, volume, séries) contam até o valor em ~600–800ms, em stagger.
  3. Cada PR entra como card com selo "PR" em pop (`SPRING_CELEBRATE`) e glow `--acc` curto, mostrando o anterior → o novo.
  4. Botão "Concluir" volta pras rotinas.
- Celebração única: chave `celebrated:workout:<id>`. Se a tela for reaberta, mostra pronta.
- Reduced motion: sem count-up (valor final direto), sem pop. Fica só fade.
- i18n pt/en, seguindo a convenção do projeto.

### 5.2 Novo PR de corrida
- O `PersonalRecordsCard` compara `GET /personal-bests` com o snapshot visto por último (`localStorage`, por distância: id do best effort top 1).
- Distância com top 1 novo: o selo "PR" daquela linha faz pop + glow **uma vez**, e o snapshot é atualizado em seguida.
- Na primeira visita (sem snapshot), grava o snapshot e **não** celebra. Senão, todo usuário novo veria 12 celebrações.
- Os PRs de academia fora do resumo de treino (ex.: `GymPersonalRecordCard`) **não** celebram. A celebração de academia acontece no resumo, §5.1.

### 5.3 Primeiro sync (onboarding)
- `FirstSyncPage`, estado `done`: o contador de atividades importadas conta até o total, com count-up + pop do número final. Depois, transição pro dashboard: o card sai e o shell real entra no lugar do skeleton com crossfade, aproveitando a VT se houver suporte.
- O sync manual do rail (`SyncPanel`) **não** celebra. Mantém o feedback atual, só com a barra migrada pra `scaleX` (§4.2).

## 6. Escopo por exclusão (decidido)

1. Meta de kcal batida não é celebrada (§4.2).
2. Sem confete nem partículas.
3. Sem count-up em KPIs do dia a dia.
4. **Treino ao vivo (`WorkoutSession`/`WorkoutExerciseCard`)** recebe só feedback de toque rápido: o check de série confirma em ~150ms (preenchimento do check + pop sutil de scale 0.96→1, sem bounce), sem nada que atrase registrar a próxima série. O anel do timer de descanso (`RestTimerControl`) pode ganhar progresso circular animado (linear, contínuo). Nenhuma celebração por série.
5. Sem morph de gráfico ao trocar período.
6. Sem animação de add/remove em listas nem em resultados de busca.
7. Sem shared element transitions.
8. Ações de teclado e itens de uso contínuo (toggle de tema, segmented controls, steppers) continuam como estão. O `press` já cobre os botões primários.

## 7. Validação (por fase, antes de commitar)

1. **`/run-sotreina`**: screenshots desktop, mobile, dark e `--reduced-motion` em pontos da animação (mesmo roteiro do hero do login). Steps só leitura: nada de finalizar treino ou salvar no banco do usuário sem pedir. Pra §5.1, combinar antes um treino de teste.
2. **Estilos computados**: step que percorre os elementos animados e lê `getComputedStyle(el).transitionProperty/transitionDuration/animationName`. Falha se aparecer `all`, ou se houver duração > 0 em propriedade de movimento sob reduced motion.
3. **Celular real** (usuário): push lateral com o botão voltar, sensação do check de série e do timer, View Transition no Safari 18+ e o fallback em navegador sem suporte.
4. `npx tsc --noEmit` e `npm test` no client. Testes puros pra `useFirstVisit`, a lógica de snapshot de PR e o cálculo de PR do backend.
5. Atualizar o CLAUDE.md ("Estado atual → Frontend", "Polimento de UI / movimento") ao fim de cada fase.

## 8. Questões em aberto

- Primeiro registro de um exercício conta como PR? (sugestão: não)
- Faixa exata da meta de kcal: ±3% ou ±5%? Alinhar com o critério que o `DietHistoryPage` já usa.
- Se a View Transition + `React.lazy` se mostrar frágil na prática (snapshot com fallback), aceitar trocar pela entrada via Motion em todos os navegadores?
