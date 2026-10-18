# Spec — SoTreina no iPhone: PWA + app nativo do treino ao vivo (via xtool, sem Mac)

Data: 2026-10-18 · Status: **Fase A implementada** (aguardando deploy, cadastro do ping e validação no iPhone) · Fases 0–2 não iniciadas
Ferramenta-base do nativo: [xtool](https://github.com/xtool-org/xtool), que substitui o Xcode no Linux/WSL: builda pacotes SwiftPM, assina e instala no iPhone.

## 1. Objetivo

Usar o SoTreina no iPhone no dia a dia, resolvendo duas dores:

1. **Atrito de abrir**: um ícone que abre direto, já logado, e responde rápido.
2. **Integração com o iOS durante o treino**: timer de descanso na Dynamic Island e na tela bloqueada, com notificação quando acaba.

### Estratégia (resultado da revisão)

A primeira versão do plano reescrevia a web inteira em SwiftUI. A revisão mudou isso: **cada dor é resolvida pela ferramenta mais barata que a resolve.**

- **PWA** resolve o atrito de abrir em **todos os módulos**, com custo de uma tarde (§3).
- **Render acordado** resolve a lentidão de abrir pra web, PWA e app ao mesmo tempo (§4).
- **App nativo** existe **só** pro que um PWA não alcança: a **Live Activity** do treino ao vivo. Ele cobre só o treino (rotinas, sessão, resumo) e nada mais.

Isso evita manter duas UIs completas, numa linguagem nova, sem simulador e com reinstalação semanal.

## 2. Decisões

| Tema | Decisão |
| --- | --- |
| Estratégia | **PWA agora** + **nativo restrito ao treino ao vivo + Live Activity**. Sem "paridade gradual" |
| Cold start | **`GET /health` sem banco + ping agendado**. Cache local no app vira "desejável", não requisito |
| Público | **Só o usuário**, instalado via xtool. App Store não é objetivo |
| Conta Apple | **Apple ID grátis**: a assinatura expira a cada 7 dias, reinstalar em **1 comando**, e o app **avisa antes de vencer** (§6.5) |
| Go/no-go | A Fase 0 só passa se uma **Live Activity mínima** aparecer no iPhone instalada pelo xtool |
| Telas do nativo | **4**: login, rotinas (só leitura, iniciar/retomar), sessão, resumo simples |
| Rede ruim | **MVP online**: série com ⚠ e reenvio manual, protegida por `clientId` idempotente. Fila offline é fase **condicional** |
| Live Activity | `+15s`, `Pular` e `✓ Registrar` com valor proposto. **Sem stepper** |
| Descanso por exercício | Mora **na rotina**: `WorkoutTemplateExercise.restSeconds`, usado pela web e pelo app |
| Integração PWA↔app | **Nenhuma** no MVP. O PWA mantém a sessão de treino intacta, como **reserva** pra semana em que o app vencer |
| Login no app | **Só email/senha**, com **Bearer token** (JWT) no Keychain |
| Idioma do app | **Só PT**, mas toda string no **String Catalog** (adicionar EN depois é só tradução). A web continua PT/EN |
| Visual do app | **iOS nativo** (`NavigationStack`, `List`, sheets, SF Symbols) com o acento e as cores do SoTreina, claro/escuro automático |
| iOS alvo | **iOS 18+**, iPhone com Dynamic Island |
| Repo | **`ios/` no monorepo**. Fatia vertical: mudança de API, web e app no mesmo commit |
| Contrato de tipos | **Structs `Codable` à mão** + testes de decode contra fixtures reais (§5.4) |
| Experiência com Swift | **Nenhuma**. Fatias pequenas, e cada fase explica os conceitos novos |

## 3. PWA (primeira entrega, independente do nativo)

Hoje o `client/` não tem manifest nem `apple-touch-icon` (só `favicon.svg` em `public/`).

- `client/public/manifest.webmanifest`: `name: "SoTreina"`, `short_name: "SoTreina"`, `display: "standalone"`, `start_url: "/"`, `background_color`/`theme_color` com os tokens do tema, ícones PNG 192/512 (+ `maskable`).
- `client/index.html`: `<link rel="manifest">`, `<link rel="apple-touch-icon">` (PNG 180×180, o iOS **ignora** o ícone do manifest pra Tela de Início), `<meta name="apple-mobile-web-app-capable">`/`apple-mobile-web-app-status-bar-style`, `<meta name="theme-color">` (claro e escuro via `media`).
- Os ícones derivam do logo "ST".
- **CSP**: conferir se `manifest-src` (ou `default-src`) do `client/vercel.json` cobre o manifest servido de `'self'`. Se precisar mudar o `index.html` dentro do script inline de pré-paint, recalcular o hash (`npm run csp:hash`). Tags no `<head>` fora do script não afetam o hash.
- O layout já usa `viewport-fit=cover` + `env(safe-area-inset-*)`, o que cobre o modo standalone. Validar no iPhone: app bar, drawer, sheets e o scanner de código de barras dentro do standalone.
- **Sem service worker** no MVP. Ele só agregaria cache offline, que não é o problema aqui, e traria o risco clássico de servir bundle velho depois de deploy.
- **Cookies**: no iOS, o app instalado na Tela de Início tem **armazenamento separado** do Safari. É preciso fazer login uma vez dentro dele. O `active-page` em `localStorage` também é separado, o que é esperado.

## 4. Render acordado

- `GET /health` no backend: responde `{ ok: true }` **sem tocar no Prisma**. Sem `AuthGuard`, com throttle próprio baixo (ex: 30/min/IP).
- Ping a cada ~10 min por um agendador externo gratuito (cron-job.org ou um GitHub Action com `schedule`), apontando direto pra `https://sotreina.onrender.com/health`. Não passa pelo proxy da Vercel, pra não gastar invocação lá.
- **Orçamento**: o free tier do Render dá 750 h/mês por conta, o bastante pra **um** serviço ligado o mês todo (~744 h). Se um dia houver um segundo serviço free, a conta deixa de fechar.
- **O ping nunca pode chegar ao Postgres.** O Neon free também tem cota de computação e suspende sozinho. Um ping que consulta o banco (ex: `GET /auth/me`) o manteria acordado 24 h e queimaria a cota. Um primeiro request depois de o Neon suspender custa ~1 s, aceitável.
- Registrar a decisão e o motivo no CLAUDE.md (seção "Deploy").

## 5. Mudanças no backend pro app nativo

### 5.1 Autenticação por Bearer

- `SessionService.extractSession(req)` (`server/src/auth/session.service.ts`) passa a ler **também** `Authorization: Bearer <jwt>`. Hoje ele só lê o cookie `session`. É o ponto único que `AuthGuard` e `GET /auth/me` usam, então toda rota ganha Bearer de graça. Mesmo JWT (`{ sub, tv }`, `JWT_EXPIRES_IN=30d`): o `tokenVersion` continua valendo, e o logout em qualquer dispositivo derruba o app.
- Se vierem cookie e header, **o header ganha**. Isso fica pinado por um teste.
- Endpoint novo `POST /auth/token` (email+senha, mesmo throttle de 5/min/IP do login) que devolve `{ token, user: MeResponse }` no corpo, sem setar cookie. Fica separado de `POST /auth/login` pra não mexer no contrato da web.
- `POST /auth/logout` com Bearer funciona igual (incrementa `tokenVersion`).
- CSRF não piora: um Bearer nunca é enviado automaticamente pelo navegador.
- Sem refresh token. O JWT expira em 30 dias e o app volta pro login.

### 5.2 Idempotência das séries

O reenvio manual de uma série com ⚠ pode **duplicá-la**: o servidor gravou, a resposta se perdeu, e o app reenvia.

- `POST /workouts/:id/exercises/:weId/sets` aceita `clientId` opcional (UUID gerado no app). Migration: `WorkoutSet.clientId String?` + `@@unique([workoutExerciseId, clientId])`.
- Se esse `clientId` já existir, o servidor devolve o `WorkoutDetail` atual sem criar nada. A web não manda `clientId` e não muda.
- `PATCH`/`DELETE` de série já são idempotentes.

### 5.3 Descanso por exercício na rotina (Fase 2)

- Migration: `WorkoutTemplateExercise.restSeconds Int?` (`null` = padrão global).
- `POST`/`PATCH /workout-templates` aceitam `restSeconds` por exercício (validação manual, 15–600 s).
- `GET /workouts/:id` e `GET /workouts/active` já expõem a meta por exercício, e `restSeconds` entra junto.
- **Web**: o editor de rotina ganha o campo, e o `useRestTimer` passa a usar o valor do exercício quando existir.

### 5.4 Contrato de tipos

**Structs `Codable` à mão**, só pros endpoints que o app consome (`/auth/*`, `/workout-templates`, `/workouts/*`, `/exercises` e `.../last-performance`), com **testes de decode contra fixtures JSON reais** capturadas da API local e commitadas em `ios/Tests/.../Fixtures/`.

Gerar via OpenAPI foi descartado: exigiria anotar os módulos NestJS com `@nestjs/swagger` (o projeto valida tudo à mão, sem DTO class) pra um app que consome meia dúzia de endpoints. **Pra pegar drift**: um teste no `server/` que bate nesses endpoints e compara as chaves com as fixtures, falhando quando um campo some ou muda de nome.

Datas: o backend serializa ISO-8601 com milissegundos, o que exige um `JSONDecoder` com estratégia customizada. `weightKg`/`rpe` já chegam como `number`.

## 6. App nativo

### 6.1 Restrições do ambiente

- **Não há simulador** (ele só roda em macOS). Todo teste visual é no iPhone físico. Lógica pura roda com `swift test` no Linux, se ficar num target sem UIKit/SwiftUI e sem rede (o `URLSession` do Linux vive em `FoundationNetworking` e diverge do da Apple).
- **Não há Interface Builder.** Só SwiftUI em código.
- **USB no WSL2** exige `usbipd-win` (Windows) + `usbmuxd` (Linux). A alternativa é Wi-Fi depois do primeiro pareamento.
- **O setup do xtool** baixa o Xcode (`.xip`, pelo site de developer da Apple, logado) uma vez, pra extrair o SDK.
- **Apple ID grátis**: o login do xtool usa a opção "password" (APIs privadas da Apple), já que "API key" exige conta paga. O app expira em 7 dias e não abre até ser reinstalado. Os dados locais sobrevivem à reinstalação por cima se o bundle ID não mudar. Não há push remoto, mas o timer usa notificação **local**, que não precisa de entitlement. **A Live Activity não precisa de App Group**: o app passa o `ContentState` direto pro ActivityKit, e o `Text(timerInterval:)` conta sozinho.

### 6.2 Estrutura

```
ios/
├── Package.swift
├── xtool.yml                # bundle ID, nome, ícone, extensão, Info.plist extra
├── scripts/deploy.sh        # build + install em 1 comando
├── Sources/
│   ├── SoTreina/            # app (SwiftUI)
│   │   ├── App/             # @main, gate de login, aviso de expiração
│   │   ├── Core/            # APIClient, Keychain, LiveActivityController, Notifications
│   │   ├── Features/
│   │   │   ├── Auth/
│   │   │   └── Workout/     # rotinas, sessão, resumo, timer
│   │   └── Resources/       # Localizable.xcstrings (PT), Assets (cores, ícone)
│   ├── SoTreinaKit/         # lógica pura: models Codable, RestTimer, proposta de série,
│   │                        # parsing do perfil de provisionamento. `swift test` no Linux
│   └── SoTreinaLiveActivity/ # extensão: UI da Live Activity + ActivityAttributes
└── Tests/
    └── SoTreinaKitTests/
```

**Regra de ouro:** tudo que não desenha tela vai pro `SoTreinaKit`, porque é a única parte testável sem o iPhone. O `ActivityAttributes` (o tipo compartilhado entre app e extensão) também mora num lugar que os dois targets enxergam.

### 6.3 Camadas

- **`APIClient`** (`URLSession` + `async/await`): base URL `https://sotreina.com/api` (fallback `sotreina.vercel.app/api` até a migração do domínio terminar), `Authorization: Bearer`, `Accept-Language: pt` (o backend localiza o nome dos exercícios por esse header). Um 401 apaga o token e volta pro login.
- **Estado**: `@Observable`, um `ActiveWorkoutStore` espelhando o papel do `useActiveWorkout.ts` da web. Toda mutação recebe o `WorkoutDetail` completo de volta (convenção atual) e substitui o estado.
- **Foreground**: no `scenePhase == .active`, recarrega `GET /workouts/active`. Isso cobre "editei na web" (o último a escrever ganha, e isso foi aceito).

### 6.4 Telas (MVP)

1. **Login**: email + senha → `POST /auth/token` → Keychain → `GET /auth/me`.
2. **Rotinas**: `GET /workout-templates` (nome, chips de grupo muscular, "última vez"), só leitura, com o botão **Iniciar** (`POST /workouts` com `templateId`). Se houver treino aberto (`GET /workouts/active`), o app abre direto na sessão.
3. **Sessão**: um card por exercício e a grade de séries (peso/reps editáveis, sugestão de `last-performance` série a série). Registrar série (`POST` com `clientId`). Adicionar exercício com busca (`GET /exercises?search=`) e remover. Cronômetro do treino a partir de `startedAt`. **Finalizar** e **Cancelar**, os dois com confirmação.
   - **Série que falhou ao enviar**: fica visível com ⚠ e o mesmo `clientId`, e um toque reenvia. Nada de fila automática. O botão Finalizar fica bloqueado enquanto houver série com ⚠.
4. **Resumo**: lista simples com duração, volume, séries e os PRs (`summary` do `PATCH .../finish`). **Sem** as animações de celebração da web.

Fora do app (continuam no PWA): detalhe da rotina, detalhe do exercício, criar e editar rotina, histórico, calendário, treino livre sem rotina.

### 6.5 Aviso de expiração

- O app lê o `embedded.mobileprovision` do próprio bundle (um plist dentro de um envelope CMS: basta extrair o trecho entre `<?xml` e `</plist>`) e pega `ExpirationDate`. O parsing fica no `SoTreinaKit`, com teste.
- A partir de 2 dias antes: um banner fixo no topo ("O app expira sexta. Rode `ios/scripts/deploy.sh`").
- Uma notificação local agendada pra véspera, às 20h, reagendada a cada launch.
- Se o arquivo não existir ou não parsear, o app não mostra nada (falha silenciosa e segura).

### 6.6 Timer de descanso

- Ao registrar uma série, o descanso começa com o `restSeconds` do exercício (Fase 2) ou com o padrão global de 90 s, ajustável no app.
- Cálculo por **timestamp absoluto** (`endsAt`), o mesmo princípio do `RestTimerEngine` da web, no `SoTreinaKit`, com teste.
- **Notificação local** (`UNUserNotificationCenter`) agendada pra `endsAt`, com som. Reagendada no `+15s` e cancelada no `Pular`. A permissão é pedida no primeiro treino.

### 6.7 Live Activity (Fase 2)

- Começa ao iniciar ou retomar o treino e termina ao finalizar ou cancelar. Uma por treino. Fica dentro do limite de ~8 h do ActivityKit pra uma atividade ativa.
- **`ContentState`**: exercício atual, "Série N de M", `restEndsAt` (ou `nil` = "em série") e a série proposta (peso e reps).
- **Dynamic Island compacta**: ícone + `mm:ss` (`Text(timerInterval:)`). **Expandida e tela bloqueada**: exercício, série, timer e botões.
- **Botões** (`LiveActivityIntent`, que roda no processo do app):
  - `+15s` e `Pular`, durante o descanso.
  - `✓ Registrar`: grava a série proposta (`POST` com `clientId` novo) e inicia o descanso.
- **Série proposta**, em ordem de precedência:
  1. a série de mesmo número em `last-performance`;
  2. a série anterior deste treino;
  3. nenhuma (primeira série de um exercício nunca feito): o `✓` vira "Abrir app".
- Se o `POST` do `✓` falhar, a Live Activity mostra ⚠ e a série aparece com ⚠ na sessão, sujeita ao reenvio manual normal.

## 7. Fases

Cada fase termina com uso real por alguns dias.

### Fase A — PWA + Render acordado (independente do nativo, entrega imediata)

§3 e §4. Vale pra todo módulo e pra web no desktop também.

### Fase 0 — Spike do nativo (go/no-go)

Pra seguir, **tudo** abaixo precisa funcionar:

1. **Build e install pelo WSL**: `xtool setup` concluído, hello world SwiftUI no iPhone via USB (usbipd), e `ios/scripts/deploy.sh` reinstalando em 1 comando. Bônus: reinstalação por Wi-Fi.
2. **Live Activity mínima**: a extensão builda, instala junto, e um botão no app inicia uma Live Activity com um timer contando na Dynamic Island e na tela bloqueada. Sem botões interativos ainda. **Este é o critério decisivo.**
3. **API**: §5.1 no backend, login contra a API local e contra produção, JWT no Keychain, `GET /auth/me` mostrando o nome.
4. **Logs**: ver o `os.Logger` e o crash log do app no iPhone a partir do WSL (`idevicesyslog` do libimobiledevice ou o que o xtool oferecer).

**Se o item 2 falhar**: o nativo é arquivado. O timer da web/PWA ganha **web push** (iOS 16.4+ entrega push a um PWA instalado): o backend agenda o push de "descanso acabou" pro `endsAt`. Esse plano B tem spec própria, a escrever se necessário.

Saída: `ios/README.md` com o passo a passo do setup e um aprendizado no CLAUDE.md sobre o xtool no WSL.

### Fase 1 — MVP online

§5.2, §6.3 a §6.6: as 4 telas, `clientId`, ⚠ e reenvio manual, timer na tela + notificação local, aviso de expiração, strings em PT no catálogo.

### Fase 2 — Timer completo

§5.3 (`restSeconds`, com backend + editor de rotina da web + `useRestTimer` da web + app) e §6.7 (Live Activity com `+15s`, `Pular` e `✓`).

### Fase condicional — Fila offline

**Só se** a rede da academia atrapalhar no uso real. O desenho já está pensado:
- operações persistidas em FIFO, aplicadas de forma otimista;
- mapeamento id local → id do servidor;
- edições numa série ainda não enviada se fundem no `POST`, e apagar uma série não enviada cancela o `POST`;
- backoff com retry, mais drenagem ao voltar pro foreground ou quando a rede volta (`NWPathMonitor`);
- o `WorkoutDetail` do servidor é ignorado enquanto houver pendências;
- Finalizar espera a fila esvaziar.

O `clientId` da Fase 1 já é o alicerce.

## 8. Riscos

| Risco | Impacto | Como validar | Plano B |
| --- | --- | --- | --- |
| Extensão/Live Activity não funciona via xtool | O nativo perde a razão de existir | Fase 0, item 2 | Arquivar o nativo, web push no PWA |
| `LiveActivityIntent` exige desbloqueio na tela bloqueada | O `✓` custa um Face ID | Fase 2, no device | Aceitar (o Face ID é rápido) |
| usbipd/usbmuxd instável no WSL2 | A reinstalação semanal vira sofrimento | Fase 0, item 1 | Wi-Fi. O PWA cobre a semana sem app |
| Login "password" do xtool quebrar com mudança da Apple | Não consegue reinstalar | Acompanhar as issues do xtool | Conta paga com API key, ou ficar só no PWA |
| Ciclo build+install lento sem simulador | Produtividade | Medir na Fase 0 | Máximo de lógica no `SoTreinaKit` |
| Esquecer de reinstalar | App não abre no treino | — | Aviso §6.5. O PWA é a reserva |
| Segundo serviço free no Render | O ping deixa de caber nas 750 h | — | Rever o ping ou o plano |

## 9. Fora de escopo (revisitável)

- **Dieta e Corrida nativas**. O melhor argumento pra voltar é o scanner do VisionKit (`DataScannerViewController`), que resolveria na raiz o problema do decoder no iOS registrado nos aprendizados.
- **Widget** da tela inicial (dependeria de App Groups, incerto no Apple ID grátis, e de dados que o app não busca mais).
- **Stepper** de peso/reps na Live Activity. Volta se, no uso real, o valor proposto precisar de ajuste com frequência.
- Inglês no app.
- Integração PWA↔app (`sotreina://`).
- Cache local no app (o Render acordado resolve o cold start).
- Service worker no PWA.
- App Store, TestFlight, outros usuários, OAuth do Strava no app, HealthKit, Siri/Atalhos, Apple Watch, push remoto pro app.

## 10. Convenções

- **Fatia vertical**: toda mudança de API sai com o app e a web no mesmo commit, quando os afeta.
- No backend, as convenções atuais valem pros endpoints novos: validação manual sem `class-validator`, 404 pra recurso de outro usuário, `order` derivado da posição no array.
- Lógica no `SoTreinaKit`, com teste. UI fina por cima.
- Toda string visível no String Catalog, nunca literal no código.
- Peso e reps com teclado `.decimalPad`/`.numberPad` e alvos de toque ≥ 44 pt: a tela do treino é usada com uma mão, entre séries.
