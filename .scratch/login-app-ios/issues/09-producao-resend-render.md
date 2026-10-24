# Produção: Resend no Render e migration no Neon

Type: task
Status: open
Blocked by: 03

## Question

Checklist para o usuário (HITL), antes do deploy do backend com a verificação:

1. Setar `RESEND_API_KEY` e `EMAIL_FROM` no Render (pendente desde 2026-07-28; sem elas, o código de verificação não chega).
2. `prisma migrate deploy` contra o Neon com a migration `add_email_verification`.
3. Deploy do backend, depois o da web.
4. Conferir que `contas@sotreina.com` envia e que um cadastro real recebe o código.

O agente prepara os comandos e confere as respostas. Quem executa no dashboard é o usuário.
