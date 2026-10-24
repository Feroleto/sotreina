# Conexão Strava: backend

Type: task
Status: open
Blocked by: 06

## Question

Spec §5.2, só backend:

- `POST /strava/connect/start` (Bearer, `AuthGuard` e `AccountThrottlerGuard`) devolve `{ url }`. O `state` é um JWT de 10 min com `{ sub, tv, purpose: 'strava-connect', client: 'ios', nonce }`.
- No `GET /strava/auth/callback`, um `state` desse tipo segue um ramo próprio: confere o `tv` no banco, chama `handleCallback(code, sub)`, dispara o sync da conta (fire-and-forget, respeitando o `isSyncing`) e redireciona para `sotreina://strava/connected?status=ok|conflict|error`.
- Sem JWT, o caminho de cookie da web fica **intacto**.

Testes:

- JWT com assinatura inválida, expirado, com `tv` obsoleto ou com outro `purpose` cai em `error` sem linkar.
- Conflito de conta já ligada.
- O caminho da web continua igual.

`STRAVA_REDIRECT_URI` não muda.
