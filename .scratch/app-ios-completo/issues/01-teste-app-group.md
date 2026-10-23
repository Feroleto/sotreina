# Teste: App Group com xtool e Apple ID grátis

Type: task
Status: resolved
Blocked by:

## Question

O xtool consegue aplicar o entitlement `com.apple.security.application-groups` no app e numa extensão de widget, e o perfil do Apple ID grátis aceita? Teste mínimo: o app grava um arquivo no container do App Group e um widget de teste lê e mostra o conteúdo. A resposta decide se a Fase W (widgets) existe (spec §3, Fase S, teste 1). Registrar o resultado no `ios/README.md`.

## Answer

**Não.** Widgets da Tela de Início são inviáveis com xtool + Apple ID grátis; por decisão do usuário a Fase W sai do plano.

O que foi testado no iPhone (2026-10-22):
- `entitlementsPath` por alvo no `xtool.yml` funciona, e o xtool registra o App Group no portal. Mas ele marca App Groups como recurso pago (`AppGroupEntitlement` → `DeveloperServicesCapability(.appGroups, isFree: false)`) e, em conta grátis, **filtra o entitlement antes de assinar**. O perfil instalado veio só com `application-identifier`, `team-identifier`, `get-task-allow` e `keychain-access-groups`. App e widget receberam `nil` de `containerURL(forSecurityApplicationGroupIdentifier:)`, com `client is not entitled` no log.
- Num time pago, o xtool renomearia o grupo pra `group.XTL-<team>.com.feroleto.sotreina` (`ProvisioningIdentifiers.groupID`), então o ID teria de ser derivado do bundle ID em runtime.
- Alternativa avaliada, o Keychain compartilhado (o widget lendo o token e buscando na API): o perfil concede `keychain-access-groups = KBVDP58W3Z.*`, mas o xtool sobrescreve o entitlement com `TEAM.<bundle ID do alvo>` (`EntitlementWithTeamOrBundleID`), então app e extensão ficam em grupos diferentes.
- Única saída restante: um patch no xtool preservando grupos de Keychain declarados. O usuário escolheu **tirar os widgets do plano** em vez de manter mais um patch.

Todo o código do teste foi removido (widget, gravação no container, arquivos `.entitlements`, `AppGroup` no Kit). Fatos registrados em `ios/README.md` › "Widgets: inviáveis com Apple ID grátis".
