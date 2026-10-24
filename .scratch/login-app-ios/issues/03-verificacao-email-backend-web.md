# Verificação de email: backend e web

Type: task
Status: resolved
Blocked by:

## Question

O backend e a web da spec §6:

- **Backend**:
  - Migration `add_email_verification`: `User.emailVerifiedAt` mais a tabela `EmailVerificationCode` (hash SHA-256, 10 min, 5 tentativas).
  - `POST /auth/email/send-code` (1 a cada 60 s e 5 por hora por conta) e `POST /auth/email/verify`.
  - O `register` envia o primeiro código (template `verify-email`), e um reset de senha bem-sucedido marca o email como verificado.
  - `MeResponse.emailVerified`.
  - **`POST /auth/register-token`** (cadastro que devolve `{ token, user }`, mesmo throttle do register).
  - Contas existentes ficam não verificadas.
  - Testes no padrão de `PasswordResetToken`.
- **Web**: a etapa de código no cadastro da `LoginPage` (pulável) e o aviso "Email não verificado" com "Verificar" no Perfil, com strings PT/EN.

Termina com os testes passando, conferido localmente com `run-sotreina`, e a migration listada como pendente para o Neon (aplicar antes do deploy do backend). A exclusão de conta não entra aqui.

## Answer

Feito no worktree `login`, sem commit (o usuário commita).

- **Backend**:
  - Schema: `User.emailVerifiedAt` e a tabela `EmailVerificationCode`. A migration `20261023233418_add_email_verification` é DDL puro e já está aplicada no banco local.
  - `AuthService`: `sendVerificationCode`, `verifyEmail` e `issueVerificationCode`.
  - Rotas novas: `POST /auth/email/send-code`, `POST /auth/email/verify` e `POST /auth/register-token`.
  - Também: `parseVerifyEmailInput`, o template `verify-email.template.ts` e `MeResponse.emailVerified`.
  - O `register` envia o primeiro código, e um reset de senha bem-sucedido marca o email como verificado.
  - Os limites por conta são contados na própria tabela. O 429 traz `retryAfterSeconds`, que o app pode usar na contagem do "Reenviar".
- **Web**: `EmailCodeForm` (compartilhado), a view `'verify'` no cadastro da `LoginPage`, a linha Email em Perfil › Conta com a `VerifyEmailPage`, e as strings PT/EN.
- **Testes**: no servidor, 60 arquivos e 626 testes passando, e o `tsc` está limpo nos dois lados.
- **Conferido com `run-sotreina`**: o servidor e o cliente do worktree rodaram em 3001/5174 com uma chave Resend falsa. As contas descartáveis (`@example.invalid`) foram apagadas no fim.
  - Cadastro → etapa de código → código errado → "Fazer depois" → escolha de áreas.
  - Perfil → "Verificar" → código certo → check, nos temas claro e escuro.
  - Por curl: `register-token`, 429 com a contagem, 400 para código errado, verificação ok e 409 depois de verificado.
- **Decisão do usuário (2026-10-23)**: o cadastro manda **só** o email do código, que faz as vezes de boas-vindas. O `register` não chama mais o `sendWelcomeEmail`, e o teste trava isso. O template de boas-vindas continua existindo pro ramo de conta nova do callback Strava (hoje código morto, a Strava não devolve email).
- **Pendente**:
  - Aplicar `add_email_verification` no Neon antes do deploy do backend. O Render e o Resend ficam com o ticket 09.
  - O banco local já tem a migration. Se uma sessão no `main` rodar `prisma migrate dev` antes do merge de `login`, vai acusar drift: usar `migrate deploy` ou trazer `login` antes.

