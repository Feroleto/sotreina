# Excluir conta

Type: task
Status: resolved
Blocked by:

## Question

Spec §3.5 e §6, backend e app:

- **Backend**: `DELETE /users/me { password }`. Senha errada responde 401, com o throttle de 5/min.
  - Antes de tudo, revoga o token Strava (best-effort, a mesma rotina do `disconnectAccount`).
  - Depois, numa transaction: `purgeStravaData`, apagar `Food` CUSTOM e `Exercise` USER criados pelo usuário (com `SET NULL` virariam linhas órfãs) e apagar o `User`. Responde 204.
  - Um teste de integração confere que nenhuma tabela guarda linha daquele usuário.
- **App**: a linha destrutiva "Excluir conta" no fim de Perfil › Conta. A tela explica o que é apagado, pede a senha e tem o botão em `--neg`. Com sucesso, limpa o Keychain, encerra a Live Activity e volta ao Entrar com "Conta excluída".

Não entra na web. Termina com os testes passando e conferido no iPhone com uma conta descartável (backend local). Não usar a conta real do usuário.

## Answer

Feito no worktree `login`, sem commit (o usuário commita).

- **Backend**:
  - `DELETE /users/me { password }` (5/min/IP), em `server/src/users/account-deletion.service.ts`.
  - Antes de apagar, revoga o token Strava (`StravaAuthService.revokeToken`, agora público e exportado pelo `StravaModule`). É best-effort e fica fora da transaction.
  - Depois, numa transaction, apaga o `User` (todo o resto cai em cascade, o dado Strava inclusive) e os `Food` CUSTOM e `Exercise` USER que ele criou. Os ids desses dois são lidos antes, porque o `SET NULL` apaga o autor junto com o `User`. Responde 204.
  - **Desvios da spec, ambos com o mesmo efeito**:
    - A senha errada responde **403**, não 401: o app trata qualquer 401 como sessão expirada e deslogaria a pessoa.
    - Não usa o `purgeStravaData`: apagar o `User` já leva todo o dado Strava (API Policy 7.4 mantida).
  - Conta sem senha responde 400. No app, a linha só aparece com `hasPassword`.
- **Teste de integração**: `test/users/account-deletion.integration.test.ts`, opt-in com `DB_INTEGRATION=1` porque escreve no banco do `DATABASE_URL`.
  - Monta uma conta que toca **todas** as tabelas, exclui e exige que cada tabela volte à contagem de antes.
  - Conferido por mutação: sem o delete das comidas, ele falha (`foods` 598 → 599).
  - Suíte do servidor: 630 testes passando, mais esse pulado. `tsc` limpo.
- **App**:
  - No Kit: `DeleteAccountRequest` e `AccountDeletion` (403 → senha errada, 429 → muitas tentativas). 291 testes passando.
  - `APIClient.deleteEmpty(_:body:)`.
  - `SessionStore.deleteAccount`: limpa Keychain e cache, encerra a Live Activity e deixa `signedOutNotice = .accountDeleted` até o próximo login.
  - "Conta excluída." no Entrar.
  - `DeleteAccountView`: o que é apagado, "não tem volta", senha e botão em `--neg`.
  - A linha "Excluir conta" no fim de Perfil › Conta.
  - Strings PT/EN.
- **Conferido no iPhone** (2026-10-23, backend local via LAN, conta descartável `teste-exclusao@example.invalid`):
  - Login → `DELETE users/me -> 403` (senha errada, continuou logado) → `-> 204` → Entrar com "Conta excluída".
  - A conta sumiu do banco.
- **API local no iPhone agora funciona**: `NSAllowsLocalNetworking` mais `NSLocalNetworkUsageDescription` no `SoTreina-Info.plist`, e o portproxy/firewall da porta 3001 no Windows. O passo a passo está no `ios/README.md`, "Testar contra a API local", e serve para o 04 e o 08.
- **Pendente**:
  - Deploy do backend (`DELETE /users/me`) junto com o resto da branch.
  - Sem migration nova.

