# Cache JSON de leitura

Type: task
Status: resolved
Blocked by:

## Question

Implementar o `ResponseCache` da spec §5.2: a última resposta de cada `GET` gravada em `Caches/<userId>/<chave>.json`, mostrada na hora e substituída pela busca em segundo plano; apagado no logout e no 401. A lógica de chave e invalidação fica no Kit com testes. Aplicar às rotinas e ao treino ativo, que já existem.

## Answer

Implementado e testado no iPhone (2026-10-22). Funciona como a spec §5.2 pede, inclusive no modo avião.

- **Kit**: `ResponseCache` (`SoTreinaKit/Sources/SoTreinaKit/ResponseCache.swift`), com 7 testes em `ResponseCacheTests.swift`.
  - **Chave**: um slug legível mais um hash FNV-1a estável de path + query ordenada.
  - **Separação por usuário**: um diretório por `userId`.
  - **`Hit<Value>`**: distingue "não está no cache" de "o servidor respondeu vazio" (o `workouts/active` sem treino aberto).
  - **Arquivo que não decodifica mais** (o modelo mudou numa atualização) vale como sem cache.
  - **`clearAll()`** apaga tudo.
- **App**: `Core/CachedAPI.swift`.
  - `cached` lê na hora, `get` busca e regrava os bytes recebidos (só depois de decodificar), e `store` grava o estado que uma mutação produziu.
  - A raiz é `Caches/ResponseCache`. O sistema pode apagar essa pasta, e o custo é só uma abertura mais lenta.
  - O `APIClient` ganhou `getData` (o `send` agora delega pro `sendData`, que devolve os bytes).
  - O `SessionStore.cachedAPI` dá o cache do usuário logado. O `signOutLocally` (logout e 401) chama `clearAll()`.
- **Aplicado ao Treino**:
  - `WorkoutStore.load()` restaura rotinas e treino ativo do cache **só na primeira carga** (`restoreFromCacheOnce`). Recarregar de novo traria de volta um estado que o app já deixou pra trás.
  - O `didSet` de `active` grava o treino ativo a cada mudança, então um treino finalizado ou cancelado não reaparece ao reabrir.
  - Sem rede, com cache, a lista fica na tela sem erro.
- **Pra quem portar as próximas áreas**: buscar pelo `session.cachedAPI` em vez do `session.api`, restaurar do cache uma vez na primeira carga e gravar com `store` o estado que mutações produzem quando ele pode reaparecer ao abrir o app.
