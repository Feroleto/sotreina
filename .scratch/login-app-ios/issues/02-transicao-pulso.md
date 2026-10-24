# Transição "bola percorre o pulso"

Type: task
Status: resolved
Blocked by: 01

## Question

Implementar a transição da spec §4 depois de um login ou cadastro com sucesso, nunca na abertura a frio. Etapas:

1. O login sai em 320 ms.
2. A logo entra com fade, zoom e blur em 520 ms.
3. A bola percorre o traço e acende a linha, com mínimo de 1,6 s e espera em 88% enquanto o carregamento não termina.
4. Pulso de 1,3×.
5. A mostarda expande e revela o destino: o Hoje, ou a escolha de áreas numa conta nova.

O carregamento é o `GET /auth/me` mais o primeiro fetch do destino. A falha de rede tem timeout de 10 s e volta ao Entrar com o token mantido.

A regra de progresso (`p` em função do tempo, de `loaded`, da duração mínima e do teto de 88%) vai para o Kit como função pura (`EntryProgress`), escrita com `tdd`. Os casos de teste são carregamento instantâneo, carregamento lento que segura e solta, e o progresso que nunca recua. A view usa `TimelineView(.animation)` com `Path.trimmedPath`. Com **Reduzir movimento**, vira um crossfade com a logo estática. O traço segue o tema e a bola é sempre `acc`.

Termina conferido no iPhone em claro e escuro, com Reduzir movimento e com rede lenta (para ver a bola segurar). Se a mostarda sobre o claro incomodar, decidir o ajuste com o usuário (spec §10).

## Progresso (2026-10-23, worktree `../strava_dashboard-login`, sem commit)

- **Kit** `EntryPulse.swift` (testes antes, 7 em `EntryPulseTests`, 288 no total): `step` é a regra do design (easeInOutQuad, mínimo de 1,6 s, segura em 88%, velocidade máxima de recuperação, nunca recua). Também tem a geometria do traço e do caminho da bola em polilinha (`ballPoint`, `litFraction`).
- **SessionStore**: `login`/`register` só salvam o token e devolvem o `Me`. `enter(_:animated:)` troca de tela, e `entryTransition`/`entryTransitionEnded()` controlam o overlay.
- **LoginView**: a raiz toca a saída (320 ms, ou fade de 200 ms com Reduzir movimento) e então chama `enter`. Funciona tanto pelo Entrar quanto pelo Criar conta.
- **EntryTransitionView** (novo): é um overlay no `RootView`. A logo entra, o `TimelineView` move o percurso por um `TravelClock` fora do estado do SwiftUI, a bola pulsa e o círculo mostarda expande. O destino entra com opacidade e 12pt de deslocamento.
- **RootView/AppShell**: o destino fica escondido sob o overlay. O "pronto" é o fim do primeiro `WorkoutStore.load()`; na escolha de áreas é imediato. A capa de um treino aberto espera a transição acabar (`holdsCovers`).
- **Desvios da spec §4, a confirmar**:
  - Não há `GET /auth/me`, porque a resposta do login já traz o `Me`. O "carregamento" é o primeiro load do shell (o Hoje ainda não existe no app).
  - Depois de 10 s, o destino aparece com os estados de carregando e erro dele mesmo, em vez de voltar ao Entrar: com o token já salvo, não há falha de autenticação possível nesse ponto.

## Answer

Feito e conferido pelo usuário no iPhone (2026-10-23): escuro, claro, Reduzir movimento, rede lenta, treino aberto e abertura a frio sem animação. O que entrou está no Progresso acima.

- **Desvios aceitos**:
  - O "carregamento" é o primeiro `WorkoutStore.load()`, sem `GET /auth/me`.
  - Depois de 10 s, o destino aparece com os estados de carregando e erro dele mesmo, sem voltar ao Entrar.
- **Expansão mantida como no design.** O usuário perguntou se não seria melhor trocar de tela logo depois do pulso. A expansão ficou, porque fecha o gesto (o ponto da logo vira a entrada do app) e o login é raro (token de 30 dias). Se um dia parecer longo, encurtar o ritmo: expansão de ~450 ms e pausa de ~200 ms depois do pulso, em vez de tirar o gesto.
- Quando a [Verificação de email no app](04-verificacao-email-app.md) entrar, a transição do cadastro dispara depois da tela do código. Hoje ela dispara direto no `onSignedIn` do `RegisterView`.
