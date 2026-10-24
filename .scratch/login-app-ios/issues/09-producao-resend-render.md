# Produção: Resend no Render e migration no Neon

Type: task
Status: resolved
Blocked by: 03

## Question

Checklist para o usuário (HITL), antes do deploy do backend com a verificação:

1. Setar `RESEND_API_KEY` e `EMAIL_FROM` no Render (pendente desde 2026-07-28; sem elas, o código de verificação não chega).
2. `prisma migrate deploy` contra o Neon com a migration `add_email_verification`.
3. Deploy do backend, depois o da web.
4. Conferir que `contas@sotreina.com` envia e que um cadastro real recebe o código.

O agente prepara os comandos e confere as respostas. Quem executa no dashboard é o usuário.

## Progresso (2026-10-23)

Decidido com o usuário:
- O deploy espera o [Excluir conta](05-excluir-conta.md) fechar, porque ele está pela metade no mesmo branch `login` e mexe nos mesmos arquivos.
- Render e Vercel **deployam sozinhos no push de `main`**, então tudo o que precisa vir antes do código novo acontece antes do push.

### Checklist (o usuário executa; o agente prepara e confere)

**A. Antes do push, a qualquer momento**
1. Render › serviço › Environment: setar `RESEND_API_KEY` e `EMAIL_FROM` (`SoTreina <contas@sotreina.com>`), com os mesmos valores do `server/.env` do `main`. Aproveitar para conferir `FRONTEND_URL = https://www.sotreina.com` e setar `STRAVA_WEBHOOK_SUBSCRIPTION_ID`, que também está pendente. Salvar env no Render redeploya o código atual de `main`, o que é inofensivo.
2. Rodar no terminal do usuário, com a URL do Neon (que nunca entra na conversa): `cd server && DATABASE_URL='<url do Neon>' npx prisma migrate status`. Colar só a saída. Ela mostra o que falta além de `add_email_verification` (o `CLAUDE.md` ainda lista `add_food_log_client_id` como pendente).
3. Aplicar: `DATABASE_URL='<url do Neon>' npx prisma migrate deploy`. Todas as pendentes são DDL compatível com o código antigo (coluna nullable e tabela nova), então aplicar antes do push é seguro.

**B. Quando o Excluir conta fechar**
4. O agente roda os testes do servidor, do client e do Kit, o `tsc` dos dois lados e o build do app no branch `login`.
5. O usuário commita o `login`, faz merge em `main` e dá push. Render e Vercel deployam juntos. Se a Vercel terminar antes do Render, o cadastro da web mostra a etapa do código por alguns minutos e o envio falha com "Não foi possível enviar o código" (não bloqueia: "Fazer depois").

**C. Conferência em produção**
6. `curl -s -X POST https://www.sotreina.com/api/auth/register-token -H 'content-type: application/json' -d '{}'` deve responder 400 "email is required" (antes do deploy, 404).
7. No iPhone, com o servidor em "Usar produção", criar conta com um alias (`+prod1`) e conferir que o código chega e a verificação funciona.
8. Na web (`www.sotreina.com`), criar conta com outro alias e conferir o mesmo.

## Answer

Feito em 2026-10-23. Em produção, conferido pelo usuário.

- **Neon**: o usuário rodou `migrate status` + `migrate deploy`. A saída não foi colada, então a lista exata das migrations aplicadas não ficou registrada aqui. `add_email_verification` entrou com certeza, porque o backend novo depende dela e funciona.
- **Código**: o agente fez o commit `5bd040a` no `login` (53 arquivos, tickets 01–05) e o merge `a1bca0b` em `main`, a pedido do usuário. O usuário deu o push, e o deploy automático publicou a Vercel às 22:15:39 e o Render às 22:15:59.
- **Conferência**:
  - `register-token` → 400 sem corpo (era 404). `send-code`, `verify` e `DELETE /users/me` → 401 sem sessão.
  - O usuário criou contas com alias pelo iPhone e pela web: o código chegou e a verificação passou nos dois.
  - O Resend do Render está, portanto, configurado. O `CLAUDE.md` ainda o lista como pendente e deve ser atualizado no [Uso real da entrada nova](10-uso-real.md).
- **Sem confirmação**: `FRONTEND_URL` e `STRAVA_WEBHOOK_SUBSCRIPTION_ID` no Render (sugeridos no checklist, fora do destino deste ticket).
