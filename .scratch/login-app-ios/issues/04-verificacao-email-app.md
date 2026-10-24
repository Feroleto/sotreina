# Verificação de email no app

Type: task
Status: resolved
Blocked by: 01, 02, 03

## Question

No app (spec §3.3 e §3.5):

- O cadastro passa a usar o `POST /auth/register-token`, uma chamada só.
- Depois de criar a conta, aparece a tela "Confirme seu email": 6 dígitos com `.oneTimeCode`, envio automático ao completar, "Reenviar" com espera de 60 s e "Fazer depois". O sucesso, ou o pulo, dispara a transição para a escolha de áreas.
- Em Perfil › Conta entra a linha Email, com o selo "Não verificado" e "Verificar", que reabre a mesma tela já pedindo um código novo.
- O modelo `Me` do Kit ganha `emailVerified`, com uma fixture nova.

Termina conferido no iPhone contra o backend local, com um email real chegando pelo Resend.

## Progresso (2026-10-23, worktree `../strava_dashboard-login`, sem commit)

- **Kit**:
  - `EmailVerification.swift`: `EmailCode`, que só aceita dígitos e no máximo 6, lê o `retryAfterSeconds` do 429 (60 s quando o corpo não serve) e trata só o 400 como código errado. Também tem o `VerifyEmailRequest`.
  - `Me.emailVerified`: ausente conta como `true` (backend sem verificação, sem o que oferecer).
  - 9 testes novos em `EmailVerificationTests`, 297 no total.
- **App**:
  - `APIClient.postRaw`: o 429 do `send-code` tem corpo útil. O envio foi separado em `perform`.
  - `SessionStore.register` passou a usar `POST /auth/register-token`, uma chamada. Entraram também `sendEmailCode()` (`nil` = enviado, `Int` = espera) e `verifyEmail(code:)`, que já atualiza o `Me` da sessão.
  - `VerifyEmailView` (novo), em dois contextos:
    - `.signUp`: sem voltar, com "Fazer depois", e o primeiro código já foi enviado (contagem de 60 s).
    - `.profile`: pede um código ao abrir e fecha sozinho depois de verificar.
  - O campo usa `.oneTimeCode` e envia sozinho no 6º dígito.
  - `LoginView`: o cadastro empurra `.verify`, e o fim dele (verificado ou pulado) dispara a transição. Se o backend responder `emailVerified: true`, a etapa é pulada.
  - `ProfileEmailRow`: a linha Email em Perfil › Conta, com selo verificado ou "Não verificado" + "Verificar". É a única linha nova no `ProfileView`, porque o arquivo é compartilhado com a sessão do Excluir conta.
- **Strings PT/EN**: `auth.verify.*` e `nav.profile.emailUnverified`/`emailVerified`/`verifyEmail`.
- **Teste no iPhone**: um quick tunnel do cloudflared (binário no scratchpad da sessão) aponta para o servidor do worktree na porta 3001. A URL é configurada na sheet de servidor do app. O túnel deve ser fechado depois do teste, e o app volta a apontar para produção.

## Answer

Feito e conferido pelo usuário no iPhone (2026-10-23), contra o servidor do worktree, com email real chegando pelo Resend. O que entrou está no Progresso acima. Conferidos:

- Cadastro → código → transição → escolha de áreas.
- Código errado.
- "Fazer depois".
- Perfil › Conta › Email › Verificar → selo.

Dois bugs no caminho:

- **Tela preta depois do cadastro**: a conta recém-criada estava num `@State` lido dentro do `navigationDestination`, e o destino era montado com o valor antigo (`nil`). A conta passou a ir na própria rota (`Route.verify(RegisteredAccount)`, `Hashable` pelo `id`). Regra para o app: um dado que o destino precisa vai no valor da rota, nunca num `@State` lido no `navigationDestination`.
- **Código que não chegava**: não era o app. O servidor do worktree na porta 3001 (`nest start --watch`, de outra sessão) foi iniciado com `RESEND_API_KEY` falsa no ambiente (`re_fa…`), sobra do teste do ticket 03. A variável de ambiente ganha do `.env`, e o envio best-effort só loga a falha. O teste rodou num servidor próprio na 3002 (`env -u RESEND_API_KEY node dist/main`), já encerrado. **Quem for usar a 3001 de novo precisa reiniciá-la sem essa variável.**

Pendências:
- O app agora cadastra pelo `register-token`, então criar conta pelo app contra produção dá erro até o deploy do backend ([Produção: Resend no Render e migration no Neon](09-producao-resend-render.md)). Entrar não é afetado.
- O túnel (cloudflared no scratchpad da sessão) foi fechado.
- Ficaram no banco local as contas de teste `so.corre777@gmail.com` e os aliases `+teste` do usuário.
