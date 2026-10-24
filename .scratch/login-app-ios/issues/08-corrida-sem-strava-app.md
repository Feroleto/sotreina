# Corrida sem Strava no app: conectar, primeiro sync e desconectar

Type: task
Status: open
Blocked by: 06, 07

## Question

O app, spec §5.1, §5.3, §5.4 e §3.5:

- **Estado vazio da Corrida** quando `hasStravaAccount == false`: texto, a linha sobre o que é importado e o botão oficial **Connect with Strava** (asset de `client/src/assets/strava/` sem alteração, variante por tema, 48pt).
- **Fluxo**: `POST /strava/connect/start`, depois `ASWebAuthenticationSession`, depois a leitura do `status`. Com `ok`, recarrega o `/auth/me`. Com `conflict`, mostra a mensagem própria. Cancelar não mostra nada.
- **Progresso do primeiro sync**: polling de `GET /strava/sync/status` a cada 2 s com a aba visível, contador, ETA e a fase `rate_limited` mostrada como espera. Ao terminar, recarrega o `RunStore`. Não há design para essa tela: partir do `FirstSyncPage` da web e mostrar ao usuário antes de fechar.
- **Perfil › Conta**: linha Strava com "Conectar" ou "Desconectar" (confirmação com o texto da web, `DELETE /strava/connect`).

Atualizar o `.plans/app-ios-completo-spec.md` (§2, §4 e §5.4 diziam "sem Strava no app"). Termina conferido no iPhone conectando uma conta Strava do zero numa conta nova, contra o backend local, e desconectando.
