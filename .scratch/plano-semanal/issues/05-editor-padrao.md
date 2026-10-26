# Editor do Padrão no app

Type: task
Status: resolved
Blocked by: 04

## Question

Construir a §6.6 da spec: `WeekPlanEditorView`.
- Grade Área × dia, só das Áreas ligadas, com toque pra ligar/desligar e vibração.
- Toque longo numa bolinha de Treino abre a lista de Rotinas + "Qualquer rotina". A abreviação aparece na bolinha.
- Legenda e dica fixa abaixo da grade. VoiceOver com toggle + ação "Escolher rotina".
- Salvar numa chamada só (`PUT /plan/pattern`), confirmação ao voltar com alteração pendente e o aviso de grade vazia.
- `.hidesFloatingTabBar()`.

Entradas: o botão da faixa, o convite do Hoje (troca o placeholder do [Hoje com o Plano da semana no app](04-hoje-com-plano.md)) e a linha **Perfil › Metas › "Plano da semana"**. Com plano ativo, o stepper de Treinos do Perfil vira "definido pelo plano". O seletor "Esta semana / Próxima" do editor só aparece depois da [Folha do dia: Ajustes no app](06-folha-do-dia.md). Até lá, deixar o lugar reservado.

Destino de validação `weekPlanEditor`. Termina com o usuário montando o próprio Padrão no iPhone (contra a API local ou de produção) e conferindo o Hoje mudar, a meta de Treinos na web acompanhar e a grade vazia desligar o plano.

Inherited from the [Hoje com o Plano da semana no app](04-hoje-com-plano.md): with the real plan saved, also check the **Treino tab**. That means "Próximo treino" with "Qua · " when the planned day isn't today, and the "Próxima" badge on `RoutinesView` following the plan.

## Progress (2026-10-25, `main`, not committed)

- **Kit**:
  - `ProfileRules.weeklyGoalAreas(_:planned:)`: with an active plan, the Treino goal leaves the steppers.
  - `ValidationLaunch.Destination.weekPlanEditor`.
  - 409 tests.
- **App**:
  - `PlanStore.loadPattern()` (`GET /plan`, cache) / `savePattern(_:)` (`PUT /plan/pattern`, then reloads the window).
  - `Features/Today/WeekPlanEditorView.swift`:
    - A `Grid` of enabled areas × Mon–Sun, 30 pt dots (34 pt overflowed a 393 pt screen).
    - Tap toggles, with `.sensoryFeedback(.selection)`.
    - **Long press on a Treino** turns it on if it's off, then opens the `RoutinePicker` sheet ("Qualquer rotina" + the routines). The dot shows the `RoutineAbbreviation`.
    - Below the grid: a legend "Seg · Peito …", a fixed hint, "N treinos por semana", and the note "Mudanças valem a partir de hoje…".
    - Fixed bottom "Salvar plano" button: one PUT, then reloads the `ProfileStore`, since the server rewrote the Meta.
    - An empty grid with an active plan asks to confirm "Desligar plano". Back with changes → "Cancelar" + "Descartar alterações?".
    - VoiceOver: label "Treino, Segunda", value "ligado, Peito", activation toggles, action "Escolher rotina".
    - `.hidesFloatingTabBar()`.
    - The "Esta semana / Próxima" switch is only a comment holding its place (it comes with the folha do dia).
  - Entry points:
    - Hoje: the invite and the calendar button (the placeholder is gone).
    - **Perfil › Metas**: new "Plano da semana" row ("dias de corrida e de treino" / "ainda não montado"). With a plan, the Treino row reads "definido pelo plano da semana" and opens the editor.
    - The Hoje pencil and Perfil's weekly goals no longer show the Treino stepper with a plan (`weeklyGoalAreas`).
  - `AppShell` injects `PlanStore` and `WorkoutStore` into the environment (Perfil reads them).
  - PT/EN strings.
- **Build and install**: clean. Screenshot of the empty editor (the user's real account), light PT. The plan **was not saved by the agent**: saving writes to the user's production account.
- **Pending: the user** builds the real plan on the iPhone and checks:
  - the Hoje changes;
  - the Treino Meta on the web follows the gym days;
  - an empty grid turns the plan off;
  - the Treino tab ("Próximo treino" with "Qua · ", "Próxima" badge), inherited from the Hoje ticket.

## Answer

Done on 2026-10-25 in `main`, not committed. The details are in the Progress section above.

The user built the real plan on the iPhone and confirmed "tudo certo". That covers:
- the Hoje following the plan;
- long press picking the routine;
- the Treino tab ("Próximo treino" with the day, the "Próxima" badge);
- the Treino Meta following the gym days.

The plan now lives in the user's production account.
