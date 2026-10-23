# Histórico do Treino

Type: task
Status: resolved
Blocked by: 22

## Question

Portar `GymHistoryPage`/`WorkoutDetailPage`/`ExerciseSessionDetailPage`: KPIs, barras de volume semanal (Swift Charts), "Recentes" agrupados por semana, detalhe do Treino (peso/reps médios reais) e detalhe do exercício na Sessão, série a série, com 1RM estimado (Epley). `historyBins` (`groupWorkoutsByWeek` e cia.) e o Epley vão pro Kit com os testes da web traduzidos. Dados via `GET /workouts/history-stats` e `GET /workouts/:id`, com o cache de leitura. Termina com o checklist da Fase T no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase T (Treino completo)](18-fatiamento-fase-t.md).

## Answer

**Feito e validado no iPhone (2026-10-23).** O usuário aprovou a galeria da Fase T, linhas 27–34. Os desvios foram aceitos **"por enquanto"** (ver abaixo).

- **Kit** (`WorkoutHistory.swift`, 160 testes passando):
  - `WorkoutHistoryItem`, com fixture real em `Fixtures/workouts-history-stats.json`.
  - `HistoryBins`: `weekStart` (segunda-feira no fuso local), `weeklyVolume` (12 semanas zeradas, a semana corrente inclusa), `groupByWeek`, `summary` (os KPIs) e `routineDots` (cor por rotina na ordem em que aparece, ciclo de 4).
  - `SetStats`: médias (peso com uma casa, reps inteiras), volume, melhor série (maior volume, a primeira no empate) e Epley com uma casa.
  - `WorkoutFormat.totalDuration`/`dayMonth`/`longDate`.
  - Os testes do `historyBins.test.ts` da web foram traduzidos, com relógio e fuso fixos.
- **Paleta**: tokens `dotEasy` (conferido contra o `index.css`) e `chart1/2/4`. Os três últimos vêm do oklch da web convertido pra sRGB e ficam fixados por teste (o teste do CSS só lê hex). `Color.routineDots` = mostarda, `--chart-2`, `--chart-4`, `--chart-1`, como `ROUTINE_DOT_COLORS`.
- **App**:
  - `GymHistoryStore`: `history-stats` e `GET /workouts/:id` pelo cache de leitura; o detalhe desenha o cache antes da busca, porque um treino finalizado não muda.
  - `GymHistoryView`:
    - KPIs em carrossel (cartões de 150 pt) e as barras semanais (tocar lê a semana, tocar de novo volta ao total).
    - "Semana de dd/MM" com os treinos e "+ N semanas anteriores".
    - Recarrega a cada vez que a página aparece.
  - `WorkoutHistoryDetailView`: data por extenso, 4 stats e as médias por exercício.
  - `ExerciseSessionDetailView`: séries, volume, 1RM est., a tabela série a série, a melhor série e a faixa planejada.
  - `gymHistory` entrou em `AreaScreen.portedPages`, e o store mora no `AppShell`.
- **Validação** (linhas 27–34 da Fase T no `ios/README.md`):
  - A lista tem destino próprio no modo de validação; os detalhes são por toque.
  - Corrigido durante a validação: largura dos cartões de KPI e a tabela de séries, que estava espremida.
  - **Desvios aceitos por enquanto**: sem a animação de entrada das barras e das semanas (a web anima uma vez por sessão), e barras desenhadas à mão em vez de Swift Charts, como os blocos da web.
- **Bug dos dois lados, mantido por paridade**: "1 séries" na linha do exercício (`history.detail.exerciseSummary` não tem plural na web, e o app copiou a frase).
