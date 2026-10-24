# Teste: OAuth da Strava por ASWebAuthenticationSession no build do xtool

Type: task
Status: open
Blocked by:

## Question

Antes de construir a conexão Strava no app (spec §5.2, risco §10), confirmar no iPhone:

1. Uma `ASWebAuthenticationSession` com `callbackURLScheme: "sotreina"` compila e abre no build do xtool. AuthenticationServices é um framework comum, mas a regra das Notes manda conferir.
2. Um redirect HTTP 302 de uma URL https para `sotreina://strava/connected?status=ok` fecha a sessão e entrega a URL ao app.
3. Com `prefersEphemeralWebBrowserSession = false`, o login da Strava já feito no Safari é aproveitado.

Teste mínimo: uma rota de teste temporária no backend local que só redireciona, e um botão de debug no app. Nada disso fica no código depois. Registrar o resultado no `ios/README.md`. Se o passo 2 falhar, a [Conexão Strava: backend](07-conexao-strava-backend.md) precisa de outro retorno, e isso volta para decisão com o usuário.
