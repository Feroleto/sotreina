# Produção: migration no Neon e backend no Render

Type: task
Status: resolved
Blocked by: 01

## Question

Levar o [Backend do Plano da semana](01-backend.md) pra produção, na ordem:

1. `prisma migrate deploy` contra o Neon. É DDL puro e o código antigo não lê as tabelas novas.
2. O usuário commita e faz o push, e o Render faz o deploy.
3. Conferir com `curl` autenticado em `https://www.sotreina.com/api/plan` e em `/plan/days`, numa conta de teste.

É HITL: o push e as credenciais do Neon são do usuário. O agente entrega a checklist e confere as respostas. Termina com as rotas respondendo em produção e o CLAUDE.md marcando a migration como aplicada.

## Progress

- 2026-10-25: the user ran `prisma migrate deploy` on Neon. **Only `add_week_plan` was pending** (28 migrations in the repo). So `add_food_log_client_id`, `add_weekly_goals` and `add_enabled_areas`, which CLAUDE.md still listed as pending, were already applied, and CLAUDE.md is fixed. Before the deploy, `GET /api/plan` in production → 404.
- Remaining: commit + push, then the check (401 without a session, and optionally a test account).

## Answer

Done on 2026-10-25, live in production.

- **Neon**: `add_week_plan` applied by the user. It was the only one pending (see Progress).
- **Code**: the user's commit `9e0062e` on `main` (30 files: backend, migration, tests, Kit fixtures, glossary, spec, map), pushed. Render switched to serving the routes about 1 min after the push.
- **Check in `https://www.sotreina.com/api`**:
  - Without a session: `GET /plan`, `GET /plan/days`, `PUT /plan/pattern` and `POST /plan/moves` → 401 (they were 404 before the deploy).
  - With a disposable account (`claude-test-plan-prod-…@example.invalid`, created by `register-token` and deleted by `DELETE /users/me` → 204):
    - `GET /plan` empty → `PUT /plan/pattern` Mon/Wed gym + Tue run (`effectiveFrom` = today, `weeklyWorkoutsGoal` = 2);
    - move Mon→Thu (the two halves pointing at each other in `GET /plan/days`);
    - empty grid;
    - the token returns 401 after the deletion.
- **For the app**: `POST /plan/moves` responds **201** (the Nest default for POST, like `/strava/connect/start`), and the `PUT`s respond 200. The client has to accept any 2xx.
- **Security**: the Neon connection string (with the password) leaked into the conversation's plain text. I suggested resetting the `neondb_owner` password; it's up to the user.
