# Corrida sem Strava no app: conectar, primeiro sync e desconectar

Type: task
Status: open
Blocked by: 06, 07, 11

## Question

O app, spec §5.1, §5.3, §5.4 e §3.5:

- **Estado vazio da Corrida** quando `hasStravaAccount == false`: texto, a linha sobre o que é importado e o botão oficial **Connect with Strava** (asset de `client/src/assets/strava/` sem alteração, variante por tema, 48pt).
- **Fluxo**: `POST /strava/connect/start`, depois `ASWebAuthenticationSession`, depois a leitura do `status`. Com `ok`, recarrega o `/auth/me`. Com `conflict`, mostra a mensagem própria. Cancelar não mostra nada.
- **Progresso do primeiro sync**: polling de `GET /strava/sync/status` a cada 2 s com a aba visível, contador, ETA e a fase `rate_limited` mostrada como espera. Ao terminar, recarrega o `RunStore`. Não há design para essa tela: partir do `FirstSyncPage` da web e mostrar ao usuário antes de fechar.
- **Perfil › Conta**: linha Strava com "Conectar" ou "Desconectar" (confirmação com o texto da web, `DELETE /strava/connect`).

Atualizar o `.plans/app-ios-completo-spec.md` (§2, §4 e §5.4 diziam "sem Strava no app"). Termina conferido no iPhone conectando uma conta Strava do zero numa conta nova, contra o backend local, e desconectando.

## Notas da Conexão Strava: backend (2026-10-24)

- **O teste no iPhone tem que ser contra produção, não o backend local.** O `STRAVA_REDIRECT_URI` local é `http://localhost:3000/strava/auth/callback`, e a Strava só aceita `redirect_uri` no "Authorization Callback Domain" (`sotreina.com`) ou em localhost, que o iPhone não alcança. Então o backend do ticket 07 precisa estar no Render antes do teste final (o usuário commita e faz o merge em `main`). A UI até lá dá pra montar contra o local, até o `POST /strava/connect/start`.
- **Sync pulado com lock ocupado**: o callback chama `sync()`, que retorna sem fazer nada se outro sync (cron ou de outra conta) segura o `isSyncing`. Se o `GET /strava/sync/status` vier `idle` logo depois do `ok`, o app chama `POST /strava/sync` (ou mostra o estado vazio com "sincronizando em breve").
- `POST /strava/connect/start` responde **201** com `{ url }`.

## Progresso (2026-10-24, não resolvido)

Código pronto, commitado (`d94adac`, merge em `main`) e com o backend em produção:

- **Kit**: `StravaConnect.swift` (`StravaConnectReturn`, `SyncStatus`, `FirstSyncProgress`, modelos do `start`/`DELETE`), 308 testes verdes. Destinos de validação `runConnect`, `runFirstSync`, `runFirstSyncPaused`.
- **App**: `StravaWebAuth` (sessão), `SessionStore.connectStrava`/`disconnectStrava`/`refreshMe`, `RunStore.firstSync` (polling de 2 s, `POST /strava/sync` se o status vier `idle` logo após o `ok`), `RunStravaViews.swift` (estado vazio e importação), linha Strava do Perfil com Conectar e Desconectar (confirmação com o texto da web). Botão oficial em PNG @3x a partir do SVG da web, variante laranja nos dois temas, como na web.
- **Tela de importação**: aprovada pelo usuário pelas capturas (claro, escuro, pausa). O tempo estimado some durante a pausa, porque o servidor manda nele a própria duração da pausa.
- `.plans/app-ios-completo-spec.md` atualizada (§2, §5.4 e lista de fora de escopo).
- **Conferido no iPhone, em produção**, com conta descartável e a Strava do usuário (já ligada à conta principal): conflito pela Corrida e pelo Perfil, cancelar sem mensagem, recusar na Strava → "Não foi possível conectar". O log confirmou `start → 201` e os status.

**Falta**: ligar uma conta Strava livre, ver a importação real e desconectar. Depende do [Aumento do limite de atletas na Strava](11-limite-atletas-strava.md). Com a vaga, é só refazer o roteiro com uma Strava nova (uma ou duas corridas manuais) e fechar o ticket.

