# Excluir conta

Type: task
Status: claimed
Blocked by:

## Question

Spec §3.5 e §6, backend e app:

- **Backend**: `DELETE /users/me { password }`. Senha errada responde 401, com o throttle de 5/min.
  - Antes de tudo, revoga o token Strava (best-effort, a mesma rotina do `disconnectAccount`).
  - Depois, numa transaction: `purgeStravaData`, apagar `Food` CUSTOM e `Exercise` USER criados pelo usuário (com `SET NULL` virariam linhas órfãs) e apagar o `User`. Responde 204.
  - Um teste de integração confere que nenhuma tabela guarda linha daquele usuário.
- **App**: a linha destrutiva "Excluir conta" no fim de Perfil › Conta. A tela explica o que é apagado, pede a senha e tem o botão em `--neg`. Com sucesso, limpa o Keychain, encerra a Live Activity e volta ao Entrar com "Conta excluída".

Não entra na web. Termina com os testes passando e conferido no iPhone com uma conta descartável (backend local). Não usar a conta real do usuário.
