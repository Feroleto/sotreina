# Histórico do Treino

Type: task
Status: open
Blocked by: 22

## Question

Portar `GymHistoryPage`/`WorkoutDetailPage`/`ExerciseSessionDetailPage`: KPIs, barras de volume semanal (Swift Charts), "Recentes" agrupados por semana, detalhe do Treino (peso/reps médios reais) e detalhe do exercício na Sessão, série a série, com 1RM estimado (Epley). `historyBins` (`groupWorkoutsByWeek` e cia.) e o Epley vão pro Kit com os testes da web traduzidos. Dados via `GET /workouts/history-stats` e `GET /workouts/:id`, com o cache de leitura. Termina com o checklist da Fase T no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase T (Treino completo)](18-fatiamento-fase-t.md).
