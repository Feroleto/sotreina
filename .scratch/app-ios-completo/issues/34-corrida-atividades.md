# Corrida: Atividades

Type: task
Status: claimed
Blocked by: 33

## Question

Roda no worktree `../strava_dashboard-corrida` (branch `fase-c`), ver as Notes do mapa.


Portar a vista mobile de Atividades (`Dashboard.tsx`, `MobileWeeklySummary.tsx`, `ActivityList.tsx`): resumo da semana (semana atual em Geist Mono contra a passada, faixa de 3 KPIs, barras de 12 semanas com a atual em `--acc`), lista agrupada por semana e filtro de período (presets + calendário em sheet nativo, semana começando na segunda), a partir de `GET /activities?limit=1000` com o Cache JSON. Distância e pace na unidade do usuário (`UnitConversion`). "Powered by Strava" no rodapé, preto no claro e branco no escuro: os assets de `client/src/assets/strava/` são SVG, então converter pra PDF/PNG @3x sem alterar o desenho (as guidelines proíbem modificar), em `ios/Resources/`. `bins.ts` e `activityFormat.ts` vão pro Kit com os testes da web traduzidos. "Corrida" entra em `AreaScreen.portedPages` (abre em Atividades até a [Corrida: Visão geral](37-corrida-visao-geral.md) entrar). Tocar numa atividade abre o detalhe da [Corrida: detalhe da atividade](35-corrida-detalhe.md), então até lá a linha não navega. Sem mudança no backend. Termina com o checklist da Fase C no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase C (Corrida)](33-fatiamento-fase-c.md).

## Progresso (2026-10-23, no worktree `../strava_dashboard-corrida`, branch `fase-c`, sem commit)

- **Kit** (136 testes, 13 novos em `RunActivitiesTests`):
  - `Activities.swift`: `ActivityListItem`, `ActivitiesPage`, `DateRange`, `WeekBin` e `RunBins`, o port de `bins.ts` mais as partes mobile do `Dashboard`/`DateRangePicker`. Semana começando na segunda, últimas N semanas zero-preenchidas, semanas de um período, lista com 4 semanas por "carregar mais", % contra a semana passada, atalhos de período até 3 meses e teto de 3 meses no fim.
  - `RunFormat.swift`: distância com 1 casa na unidade e no idioma ("12,4" em PT; a web escreve "12.4" por causa do `toFixed`), pace com virada de minuto, DD/MM, meses curtos e longos, rótulo do período.
  - Fixture `activities.json` tirada da API local.
- **App**:
  - `Features/Run/RunStore.swift`: `GET /activities?limit=1000` pelo Cache JSON, recarregado ao voltar pro primeiro plano.
  - `Features/Run/RunActivitiesView.swift`: semana atual, barras tocáveis com a leitura, lista por semana, chip do período, "Powered by Strava".
  - Sheet de período nativo: os atalhos da web que cabem em 3 meses, mais início e fim com teto de 3 meses. A web usa um calendário de dois toques, que não tem equivalente nativo.
  - `SessionStore.distanceUnit`, a aba Corrida no `AppShell` e `.runActivities` em `portedPages`.
- **Selo Strava**: os SVGs oficiais renderizados @3x no Chromium, sem alteração, em `SoTreinaDesign/Resources/Strava/` (`.copy` no `Package.swift`), com o componente `PoweredByStrava`.
- **Strings**: as chaves `dashboard.*` da web, com plurais no `.stringsdict`. Só do app: `dateRange.start/end/apply`.
- `xtool dev build` passa no worktree. As linhas 01–07 da Fase C estão no `ios/README.md` do worktree. Os pares web 01 e 02 foram capturados em `ios/validation/C/` do worktree.
- **Parado por decisão do usuário**: a instalação no iPhone espera as [Rotinas: detalhe da rotina e detalhe do exercício](21-rotinas-leitura.md) fecharem e serem commitadas em `main`. Depois: commit do `fase-c`, merge de `main` em `fase-c`, `deploy.sh` do worktree e captura das linhas.

### Retomada (2026-10-23)

- As Rotinas fecharam (`da196a2` em `main`). Fiz o merge de `main` em `fase-c` e resolvi o conflito nos `.strings` mantendo os dois blocos, sem chave duplicada. O commit do merge fica com o usuário. 142 testes do Kit e o build passam.
- Instalei e capturei as linhas 01 e 02 (conta em mi): a estrutura bate com a web. O botão "Personalizado" virou o contorno da web (`RangeTrigger`: 36 pt, cantos 8, `--grid-ax`, 11,5 muted, com fundo de acento quando há período). Esse ajuste **ainda não foi instalado**.
- **Parado de novo**: a sessão do [Editor de rotina: criar e editar](22-editor-rotina.md) instalou pelo `main` ao mesmo tempo e cancelou a minha instalação. O usuário decidiu que o Editor usa o iPhone primeiro. Quando ele fechar e for commitado, faço o merge de `main` em `fase-c` de novo, instalo e sigo da linha 03. A regra entrou nas Notes do mapa.
