# Kit: WeekPlan e as regras do Plano da semana

Type: task
Status: resolved
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

## Answer

Built on 2026-10-25 in `main`, not committed. `swift test` passes **403 tests** (64 new in `WeekPlanTests.swift`). Nothing visual was added.

All of it lives in `SoTreinaKit/Sources/SoTreinaKit/WeekPlan.swift`.

**API models**
- `PlanEntryState`, `PlanSource` (`.pattern`/`.adjustment`), `PlanEntry` (`isMoveHalf`), `PlanDay` (`entry(_:)`), `PatternSlot`, `WeekPattern` (`isActive`).
- The requests `PatternWriteRequest`, `DayChangeRequest([Area: Change?])` and `PlanMoveRequest` always send `templateId`, as `null` when there is none. In `DayChangeRequest`, `nil` sends `null`, which means undo.
- `POST /plan/moves` answers 201.
- Decoding is tested against the three real fixtures.

**`PlanDate`**: arithmetic on `"YYYY-MM-DD"` strings over a UTC calendar, so DST never shifts a day. It covers `add`, the ISO `weekday`, `monday`, the Mon–Sun `week(of:)`, and `window(today:)`.

**`PlanStatus`**
- `state(_:on:done:today:)` returns `.done`/`.pending`/`.missed`/`.upcoming`/`.skipped`/`.extra`/`.free`.
  - The Dieta is always planned.
  - **With no active plan, or no day loaded, every area counts as planned**, which is the old Hoje. That lets the Mon–Sun strip work the same way without a plan.
- `week(now:calendar:areas:planDays:activities:workouts:dietPoints:kcalGoal:)` builds 7 `Column`s.
  - Each column has `states` in `Area.allCases` order, filtered by the enabled areas.
  - `segments` leaves out Folga and Dia livre, and `isRest` is true when no segment is left.
  - `active` says whether the plan existed that day.
- `progress(_:week:)` returns `Progress(planned, doneOnPlanned, extra)`.
  - Days before the plan started don't count as planned.
  - What was done on those days counts as Extra.
- `nextPlannedDay(_:after:areas:)` feeds "Dia livre · próximo: …". It only looks at RUN/GYM.
- `nextGym(_:templates:today:doneToday:)` implements §6.4.
  - It returns `nil` without an active plan today, so the caller keeps `RoutineFormat.nextRoutine`.
  - Otherwise it returns `NextGym(template, date)`: today's planned routine first, then the next planned day's.
  - A day with no routine, or with a deleted one, falls back to the rotation. With nothing planned ahead, the date is `nil`.
- `canMove` and `moveTargets` give the reasons a target is refused: `.sameDay`, `.noPlan`, `.alreadyPlanned`, `.partOfMove`.
  - A Folga of the same area is a valid target, the same rule as the server.
  - When a day is both planned and half of a move, the app reports `.alreadyPlanned`, which reads better to the user. The server checks move halves first, but it refuses both cases anyway.

**`PatternDraft`**
- Keeps the slots of **every** area, so a Corrida hidden because its area is turned off survives the save.
- Turning a Treino off forgets its routine, and `setTemplate` only works on a Treino that is on.
- Provides `isDirty`, `gymDays`, `isEmpty`, `isEmpty(among:)` and `request` (sorted by weekday, then area).

**`RoutineAbbreviation.make(_:)`**: word initials, ignoring connectives ("Peito e Tríceps" → "PT"), otherwise the first letter. When names collide, it uses the first letter plus the first letter that sets each apart: "Peito" → "Pi", "Pernas" → "Pr". This settles part of the map's fog about collisions; whether it reads well on the dot is left for real use.

**Not done here**: the logic for which actions the day sheet offers (Pular, Adicionar, Folga o dia todo). It belongs in the [Folha do dia: Ajustes no app](06-folha-do-dia.md) and should go into the Kit there.

**App build**: no app code uses the Kit yet, so I didn't run the xtool build. The new names don't clash with any type in the app (checked with grep).
