# Backend do Plano da semana

Type: task
Status: resolved
Blocked by:

## Question

Construir as §4 e §5 de `.plans/plano-semanal-spec.md`:

- schema + migration `add_week_plan` (DDL puro);
- `server/src/plans/` com `plan-resolver.ts` puro, as rotas `GET /plan`, `PUT /plan/pattern`, `GET /plan/days`, `PUT /plan/days/:date` e `POST /plan/moves`, e as validações de §5.3 no fuso do `X-Time-Zone`;
- a gravação de `weeklyWorkoutsGoal` no save do Padrão;
- a posse da Rotina via `WorkoutTemplatesService`.

Testes (TDD):
- o resolver puro: fronteira de versão no meio da semana, Ajuste vencendo o Padrão novo, move entre semanas, domingo → segunda, DST;
- as validações (passado só aceita Folga, metades de move imutáveis no passado, colisão);
- um pino no `migration.sql` (`SET NULL` na Rotina, cascade no usuário);
- as tabelas novas na integração de exclusão de conta.

Termina com:
- `npx tsc --noEmit` e os testes do servidor passando;
- a API local respondendo via `curl`;
- **fixtures reais** gravadas (`GET /plan`, `GET /plan/days` cobrindo Padrão, Folga, move e Extra-candidato) para o Kit usar.

Migration aplicada só localmente; a produção é o [Produção: migration no Neon e backend no Render](02-producao-backend.md).

## Answer

Built and tested in `main`, without a commit (2026-10-25).

- **Names follow the glossary**: model `PlanAdjustment` (table `plan_adjustments`), not `PlanOverride`, and `source: 'PATTERN' | 'ADJUSTMENT'` in the API (the spec said `OVERRIDE`). The rest matches spec §4/§5: `WeekPlanVersion`, `WeekPlanSlot`, enum `PlanEntryState` (`PLANNED`/`SKIPPED`).
- **`server/src/plans/`**:
  - `plan-dates.ts`: ISO weekday, window, days as `YYYY-MM-DD` strings.
  - `plan-resolver.ts`: pure; the version in force + Ajuste per area.
  - `plan-rules.ts`: pure; decides what each request becomes or throws a 400.
  - `dto.ts`, `plans.service.ts`, `plans.controller.ts`, `plans.module.ts`.
  - `WorkoutTemplatesService.assertOwnedTemplate` became public, so the ownership check isn't duplicated.
- **Decided in the implementation**, beyond the spec:
  - A Folga that the current Padrão no longer plans drops out of the response, since nothing is left to skip (unless it's the emptied half of a move).
  - A Folga on an area that only an Ajuste added deletes the Ajuste (the day goes back to Dia livre).
  - `PLANNED` with exactly what the Padrão says deletes the Ajuste instead of storing a redundant one.
  - Any change to a half of a move other than undoing it → 400. So does moving from or to a day that is already half of a move. There are no chained moves.
  - Undoing a move goes back to the Padrão: a routine change that the move overwrote on the source day doesn't come back.
  - Saving an empty Padrão when there was never a plan is a no-op; it doesn't create an empty version.
  - `PUT /plan/days/:date` decides every area before writing any, so "Folga o dia todo" with one area refused writes nothing.
- **Tests**: 726 server tests passing, plus 2 opt-in integration tests.
  - `test/plans/plan-resolver.test.ts` and `plan-rules.test.ts` (41 cases): version boundary mid-week, Ajuste beating a newer Padrão, move across the Sunday, DST, past days, collision.
  - `plans.dto.test.ts`.
  - `week-plan-migration.test.ts`: DDL only, `SET NULL` on the Rotina, cascade on the user.
  - `plans.integration.test.ts`: opt-in, the whole story against Postgres.
  - `account-deletion.integration.test.ts` now creates plan rows.
  - The two opt-in integration tests **can't run together**: both count rows across the whole database.
  - `npx tsc --noEmit` clean, prettier/eslint clean in `plans/`.
- **Local API checked with `curl`** (a throwaway account, already deleted). 200s on every route. Expected errors: 400 for past `PLANNED`, collision, out of window; 404 for someone else's routine; 401 without a session.
- **Kit fixtures** (real, America/Sao_Paulo, week of 2026-10-19 → 2026-11-01) in `ios/SoTreinaKit/Tests/SoTreinaKitTests/Fixtures/`:
  - `plan-pattern.json`: Padrão with gym Mon/Wed/Fri (Peito, Costas, any routine) and runs Tue/Thu/Sat.
  - `plan-days.json`: Padrão, Folga on a past day, Treino added today, move Mon→Tue, routine swap, Folga on a run, Sunday as a Dia livre.
  - `plan-days-inactive.json`: days before any version.
- **Migration** `20261025155624_add_week_plan` applied **only locally**. Neon is the [Production: migration on Neon and backend on Render](02-producao-backend.md) ticket.
- CLAUDE.md updated (Backend, folder tree). It also fixes the old claim that the iOS app doesn't send `X-Time-Zone`.
