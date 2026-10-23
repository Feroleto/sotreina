# Visão geral do Treino

Type: task
Status: resolved
Blocked by: 23

## Question

Portar `GymOverviewPage`/`GymCalendar`/`GymPersonalRecordCard`: Treinos da semana contra a semana passada (Geist Mono grande), faixa Volume/Exercícios/Tempo, "Próximo treino" com Iniciar/Continuar (`RoutineFormat.nextRoutine`), calendário mensal navegável, Recorde pessoal por exercício com busca (reaproveitando o seletor de exercício) e lista de rotinas. Ao entrar em `AreaScreen.portedPages`, a aba Treino passa a abrir nela, como na web. Se estourar a sessão, dividir em "calendário + recorde" e registrar. Termina com o checklist da Fase T no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase T (Treino completo)](18-fatiamento-fase-t.md).

## Answer

**Feito e validado no iPhone (2026-10-23).** O usuário aprovou a galeria da Fase T, linhas 35–41.

- **Kit** (`GymOverview.swift`, 217 testes passando):
  - `GymWeek`: a semana corrente (segunda a domingo, fuso local, `HistoryBins.weekStart`) contra a passada, com volume, exercícios, tempo e a porcentagem.
  - `GymCalendarMonth`: células começando na segunda, treinos por dia, totais do mês e o rodapé (`Footer`: dia com um treino, dia com vários, mês). Os limites de navegação reaproveitam `RunCalendar`.
  - `ExercisePersonalRecord` (`GET /exercises/:id/personal-record`, corpo vazio = sem recorde).
- **App**:
  - `GymOverviewView`: semana em Geist Mono 64, "semana passada" com a linha de progresso, faixa Volume/Exercícios/Tempo, "Próximo treino" com Iniciar (`RoutineFormat.nextRoutine`), ou "Treino em andamento" com Continuar (desminimiza a sessão), Rotinas com "+ Nova" (editor em tela cheia), calendário (células de 34 pt, círculo de 28 pt) e Recordes pessoais com busca.
  - `ExercisePickerView` agora recebe `onPick` e título; a sessão e o recorde usam o mesmo seletor.
  - `GymHistoryStore.personalRecord`; o histórico recarrega a cada vez que a página aparece.
  - `gymOverview` entrou em `AreaScreen.portedPages`: a aba Treino abre nela, como na web.
- **Desvios aceitos**: linha de rotina empilha o detalhe na própria Visão geral (a web pula pra Rotinas); "0 treinos" no plural (a web escreve "0 treino" no rodapé do calendário, porque o plural do PT trata 0 como 1); volume com vírgula em PT (a web escreve "0.1 t").
- Corrigido na validação: as linhas de rotina diziam "hoje" em vez de "última vez hoje".
- Nenhuma mudança de backend.
