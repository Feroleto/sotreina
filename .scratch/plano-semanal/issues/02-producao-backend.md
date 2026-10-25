# Produção: migration no Neon e backend no Render

Type: task
Status: claimed
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
