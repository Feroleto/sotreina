# Folha do dia: Ajustes no app

Type: task
Status: resolved
Blocked by: 04

## Question

Construir a §6.5 da spec. Tocar numa coluna da faixa (com plano ativo) abre um `.sheet` com uma linha por Área ligada:
- **trocar Rotina**, **Mover pra…** (chips de hoje até o domingo da próxima, inválidos desabilitados com o motivo) e **Folga** (o botão diz "Pular");
- **Desfazer** em Folga e em metade de move (desfaz as duas);
- **Adicionar** numa Área não planejada;
- **Folga o dia todo** quando há duas Áreas planejadas.

Dia passado: só Folga e desfazer Folga, com a nota. Mutações otimistas pela fila do `PlanStore`, e a janela do servidor substitui o estado. Rodapé "Editar padrão semanal ›".

Quando o [Editor do Padrão no app](05-editor-padrao.md) já existir, ligar o seletor "Esta semana / Próxima" dele a esta folha, pra alcançar os dias da próxima semana.

Destinos de validação `planDaySheet` e `planDaySheetPast`. Termina com o usuário fazendo no iPhone cada Ajuste (inclusive um move que cruza o domingo e uma Folga retroativa) e vendo o Hoje e o "X de Y" responderem.

## Progress (2026-10-25, `main`, not committed)

- **Kit** (425 tests):
  - `PlanDaySheet.make(date:window:areas:today:)`: one row per enabled area (Corrida, Treino) with its kind (planned / Folga / move half / free) and only the actions the server accepts (`plan-rules.ts`). Past days: "Pular" only on what the Padrão planned, "Desfazer" only on a Folga that isn't a move half. A move with a day already past offers nothing. `canSkipAll` with two areas that can take a Folga. nil without an active plan or outside the window.
  - `PlanChange` (`skip`/`skipAll`/`undo`/`add`/`routine`/`move`): its `route` (`PUT /plan/days/:date` or `POST /plan/moves`) and `applied(to:templateNames:)`, the optimistic guess. Undoing a move half undoes both. Undoing a Folga can't know the Padrão's routine, so it shows none until the server answers.
  - `ValidationLaunch.Destination.planDaySheet(past:)` (`planDaySheet`, `planDaySheetPast`) + `PlanPreview.sheetDate`.
- **App**:
  - `PlanStore.apply(_:templateNames:)`: optimistic, queued (a late answer can't undo a newer tap). The server's window is merged in. On failure: rollback, `actionError` shown in the sheet, then a reload.
  - `Features/Today/PlanDaySheetView.swift`: medium/large detents. Title "Domingo, 25 de outubro". Per area: heading "Treino · Peito", detail ("ajuste desta semana", "folga", "foi pra Dom 1", "veio de Ter 27", "não planejado"), action chips. "Mover pra…" opens a row of day chips through the Sunday after next; refused ones are disabled and show why. "Trocar rotina" reuses the editor's `RoutinePicker` (now internal, with a title). "Folga o dia todo", the past-day note, and the footer "Editar padrão semanal ›" (it pushes the editor after the sheet closes).
  - Hoje: a week-strip column with an active plan is tappable (VoiceOver: button + hint).
  - Editor: "Esta semana / Próxima" + that week's 7 days, only with a saved active plan. A tap opens the sheet (no editor footer there). Days without a plan are disabled.
  - PT/EN strings.
- **Build and install**: clean. Screenshots of `planDaySheet` (today, two areas, "Folga o dia todo") and `planDaySheetPast` (Monday: note + "Pular" only), dark PT.
- **Pending: the user** on the iPhone, with the real plan:
  - each Ajuste: Pular, Desfazer, Adicionar, Trocar rotina, Folga o dia todo;
  - a move that crosses Sunday into next week, then undoing it from either half;
  - a retroactive Folga on a past day;
  - a day of next week through the editor's "Próxima";
  - Hoje and the "X de Y" following each change.

## Answer

Done on 2026-10-25 in `main`, not committed. The details are in the Progress section above.

The user ran the Ajustes on the iPhone with the real plan and confirmed that everything works. That covers:
- each action;
- a move across Sunday;
- a retroactive Folga;
- a day of next week through the editor;
- Hoje and the "X de Y" responding.
