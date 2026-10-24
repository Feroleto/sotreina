# Conexão Strava: backend

Type: task
Status: resolved
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

## Answer

Resolvido em 2026-10-24, no branch `login` (worktree `../strava_dashboard-login`), sem commit:

- `SessionService.signConnectState`/`verifyConnectState`: JWT de 10 min com `{ sub, tv, purpose: 'strava-connect', client: 'ios', nonce }`, mesmo segredo da sessão. `verifyConnectState` recusa token sem esse `purpose`/`client`, ou seja, um token de sessão comum não vale como `state`.
- **Furo fechado, fora da spec**: o `extractSession` agora recusa qualquer JWT com `purpose`. Sem isso, o `state` (que passa pela URL da Strava) funcionaria como Bearer por 10 min.
- `POST /strava/connect/start` (`StravaConnectController`, `AuthGuard` da classe + `AccountThrottlerGuard`) devolve `{ url }` com **201** (o `APIClient` aceita qualquer 2xx).
- `GET /strava/auth/callback`: um `state` com formato de JWT (3 partes) vai para `connectFromApp`, e todo resultado volta para `sotreina://strava/connected?status=ok|conflict|error`. Os casos `error` são: não verifica, `tv` obsoleto (`AuthService.authenticate`), sem `code` (recusou na Strava, `error=access_denied`) e falha na troca. Com `ok`, dispara `StravaSyncService.sync(userId)` fire-and-forget e não grava cookie. O `state` de 64 hex da web segue o caminho antigo, intacto (os testes da web não mudaram).
- Testes: 3 seams combinados com o usuário (`session.service`, callback, `start`), suíte do servidor 642 verdes. Fumaça no servidor local com conta descartável (criada e apagada): `start` → `exp − iat = 600`, `state` como Bearer em `/auth/me` = vazio, callback com code falso e com `access_denied` → `status=error`, callback da web sem cookie → `/?auth_error=1`.

Ficou para o ticket do app (anotado lá): teste no iPhone só contra produção, e sync pulado quando o lock está ocupado.
