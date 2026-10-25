# Kit: WeekPlan e as regras do Plano da semana

Type: task
Status: open
Blocked by: 01

## Question

Construir a §6.1 da spec em `SoTreinaKit/WeekPlan.swift`, por TDD:

- modelos `Codable` decodificando as fixtures reais do [Backend do Plano da semana](01-backend.md);
- `PlanStatus.state` com os estados do glossário (feito, pendente, Perdido, planejado futuro, Folga, Extra, Dia livre), a Dieta como planejada todo dia;
- `PlanStatus.week` (as sete colunas da faixa), `gymProgress` ("X de Y" + extras) e o equivalente da Corrida;
- `PlanStatus.nextGym` (spec §6.4) em volta do `RoutineFormat.nextRoutine`;
- `PatternDraft` (estado do editor, `isDirty`, corpo do `PUT`, abreviação da Rotina);
- `MoveTargets` (destinos válidos e o motivo dos inválidos).

Casos de borda espelhando os do servidor. Termina com `swift test` passando. Não tem tela.

Note (from the backend ticket): the API says `source: "ADJUSTMENT"`, not `OVERRIDE` as in the spec. The behaviors decided in the implementation (Folga dropping out, undoing a move going back to the Padrão, no chained moves) are in the [Backend do Plano da semana](01-backend.md) answer, and `MoveTargets` should follow them.
