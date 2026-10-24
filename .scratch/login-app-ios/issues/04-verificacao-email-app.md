# Verificação de email no app

Type: task
Status: open
Blocked by: 01, 02, 03

## Question

No app (spec §3.3 e §3.5):

- O cadastro passa a usar o `POST /auth/register-token`, uma chamada só.
- Depois de criar a conta, aparece a tela "Confirme seu email": 6 dígitos com `.oneTimeCode`, envio automático ao completar, "Reenviar" com espera de 60 s e "Fazer depois". O sucesso, ou o pulo, dispara a transição para a escolha de áreas.
- Em Perfil › Conta entra a linha Email, com o selo "Não verificado" e "Verificar", que reabre a mesma tela já pedindo um código novo.
- O modelo `Me` do Kit ganha `emailVerified`, com uma fixture nova.

Termina conferido no iPhone contra o backend local, com um email real chegando pelo Resend.
