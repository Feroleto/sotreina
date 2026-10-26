# Hoje com o Plano da semana no app

Type: task
Status: resolved
Blocked by: 03

## Question

Construir as §6.2–§6.4 da spec:

- `PlanStore` no shell (janela atual + próxima, fila de mutações, recarga no primeiro plano e na virada do dia, `ResponseCache`);
- `TodayView` com plano ativo: status só do planejado + Dieta + Extra, linha de Dia livre, faixa seg–dom no lugar do `LastDays`, "Por área" com "X de Y" no Treino e o subtítulo da Corrida;
- `TodaySingleArea`/tela filtrada respeitando o plano;
- convite "Planeje sua semana" sem plano. Ele empilha um placeholder até o [Editor do Padrão no app](05-editor-padrao.md) existir;
- próximo Treino seguindo o plano no Hoje, no `GymOverviewView` e no selo "Próxima" do `RoutinesView`.

Destinos de validação `todayPlanned` e `todayRestDay` (dado fixo). O plano para testar é criado via `curl` na API local (o iPhone a alcança pela LAN, ver `ios/README.md`). A faixa ainda não abre a folha, isso fica pra [Folha do dia: Ajustes no app](06-folha-do-dia.md).

Termina com o app no iPhone e o usuário conferindo:
- claro, escuro, EN e VoiceOver na faixa;
- uma semana com feito, Perdido, planejado futuro, Folga e Extra;
- uma só Área ligada;
- sem plano.

## Progress (2026-10-25, `main`, not committed)

- **Kit**:
  - `PlanDate.weekdayShort`/`weekdayLong`/`localMidnight`.
  - `PlanPreview.days(today:restDay:)`: the fixed plan for the validation launches. Gym Mon/Wed/Fri, run Tue/Thu/Sat, a Folga on this Friday, and this Tuesday's run moved to Sunday.
  - `ValidationLaunch.Destination.todayPlan(restDay:)` (`todayPlanned`/`todayRestDay`).
  - 408 tests.
- **App**:
  - `Features/Today/PlanStore.swift`: lives in the shell and loads on launch and on each return to the foreground (also in `TodayView.load`).
    - The window is recomputed from today on every load, which covers the day turning over.
    - Uses the `ResponseCache`, plus a fixed plan in a validation launch.
    - `nextGym(templates:)`.
    - **Mutations stay for the tickets that use them** (folha/editor). Writing the queue without a caller would be dead code.
  - `WorkoutStore.plan` + `plannedNext`; `nextRoutineId` follows the plan. "Today's Treino done" = some routine with `lastPerformedAt` today (a free workout doesn't count).
  - `GymOverviewView`: the meta of "Próximo treino" gets "Qua · " when the planned day isn't today. The "Próxima" badge on `RoutinesView` already reads `nextRoutineId`.
  - `TodayView`:
    - The status only shows what's planned today + Dieta + Extra ("extra · …" in the subtitle). Empty → `RestDay` ("Dia livre · próximo: Qua · Treino · Peito").
    - `PlanInvite` without a plan.
    - `WeekStrip` (Mon–Sun) replaces `LastDays`, with a calendar button in the header. The invite and the button push a `ComingSoonView` until the [Editor do Padrão no app](05-editor-padrao.md).
    - "Por área": Treino "X de Y" + "planejados esta semana · +N extra" ("sem treinos planejados" with 0 → "—"); Corrida keeps km and gets "X de Y corridas planejadas" in the detail.
    - Per-column VoiceOver: "Quarta: Treino feito, Corrida planejada, …".
  - Strings: PT/EN added, `today.days.*` removed.
- **Build and install**: `xtool dev build` clean, `deploy.sh` installed. Screenshots from the agent:
  - `todayPlanned`, light PT: status with 3 planned areas; strip with Extra on Thu/Fri; "0 de 3 · +2 extra".
  - `todayRestDay`, dark EN.
  - Real account without a plan: invite, Mon–Sun strip, "5 / 3".
- **Visible decisions**:
  - In the strip, each area keeps a fixed position (Corrida at the bottom, Dieta on top). The old one stacked what was done from the bottom up.
  - With the Dieta on, a Dia livre still shows the Dieta cell. So the "Dia livre · próximo" line only appears when the Dieta is off, as the spec says.
- **Pending: the user's check** on the iPhone: VoiceOver on the strip, a single area, the Treino tab with the plan (the `todayPlanned` destination only covers the Hoje), plus a confirmation of the two decisions above.

## Answer

Done on 2026-10-25 in `main`, not committed. Installed on the iPhone. The details are in the Progress section above.

The user decided:
1. **Strip with a fixed position per area** (Corrida at the bottom, Dieta on top), as built.
2. **"Dia livre · próximo: …" also under the grid** when Corrida/Treino have nothing planned today, with the Dieta cell still showing. This goes beyond the spec, which only put the line in place of the empty grid. `RestDay(standalone:)`; `PlanAreaState.isPlanned` became public.
3. **Checking the Treino tab with the plan** ("Qua · " in the "Próximo treino", the "Próxima" badge) **was moved to the [Editor do Padrão no app](05-editor-padrao.md)**, with a real plan made in the editor. No plan was written to the user's account.
4. The user checked on the iPhone **VoiceOver on the strip and the Hoje with one area: OK**.

Screenshots from the agent: `todayPlanned` (light PT), `todayRestDay` (dark EN, then light PT with the line under the Dieta), and the real account without a plan.
