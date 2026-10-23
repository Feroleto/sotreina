# Corrida: Visão geral

Type: task
Status: resolved
Blocked by: 35

## Question

Portar o `RunOverviewPage.tsx`: totais all-time, calendário mensal navegável (`RunCalendar`), recordes pessoais (`GET /personal-bests`, 12 distâncias, top 3 expansível, selo PR) e tênis (`GET /gear`, barra até 800 km), com "Powered by Strava". **Comemoração de recorde novo**: `prSnapshot.ts` vai pro Kit com os testes da web, com o snapshot por usuário no `UserDefaults` (separado do da web: o mesmo recorde comemora uma vez em cada lugar); um top 1 que mudou mostra o selo "Novo" com um pop simples em mola, sem o brilho. A Visão geral entrando em `portedPages` faz a aba Corrida abrir nela, como na web. Termina com o checklist da Fase C no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase C (Corrida)](33-fatiamento-fase-c.md).

## Progresso (2026-10-23, no worktree `../strava_dashboard-corrida`, branch `fase-c`, sem commit)

- **Kit** (210 testes, 22 novos em `RunOverviewTests`): `RunOverview.swift` com `PersonalBestRecord`/`Gear`, `RunTotals`, `RunCalendarMonth`/`RunCalendar` (semana começando na segunda, navegação do mês da primeira corrida até o atual), `PersonalRecords` (as 12 distâncias, 1k/5k/10k no mobile, corrida mais longa), `PrSnapshot` (port de `prSnapshot.ts`, com os 4 testes da web traduzidos), `Shoes` (desgaste até 800 km, faixas da barra, selo, meta) e os formatadores `durationLong`/`hms`/`monthShortYear`/`monthDayYear`/`calendarTitle`/`monthName`. Fixtures `personal-bests.json` e `gear.json` tiradas da API local.
- **App**:
  - `RunStore.loadOverview()`: `GET /personal-bests` e `GET /gear` em paralelo, pelo Cache JSON. O snapshot de recorde fica no `UserDefaults` (`pr-snapshot:<userId>`) e só muda depois de um fetch que deu certo.
  - `RunOverviewView`: grade 2×2 dos totais, calendário (tocar num dia com corrida mostra a leitura no rodapé), recordes 1k/5k/10k + corrida mais longa, sheet "Ver todos" com as 12 distâncias (2º/3º expansíveis, selo PR), carrossel de tênis e "Powered by Strava". Recorde novo: selo "Novo" + pop em mola no chip, sem o brilho, e sem animação com movimento reduzido.
  - `.runOverview` em `portedPages`. **A aba Corrida continua abrindo em Atividades**: o `MOBILE_TABS` da web leva a `run/activities`, então "a Visão geral faz a aba abrir nela, como na web" estava errado no ticket.
- **Bugs achados no aparelho e corrigidos**: a rolagem começava deslocada por causa de um `LazyVGrid` no calendário (virou linhas simples). Os dias do calendário ficavam apagados por causa do `.disabled` (virou `allowsHitTesting`). E, com o texto no máximo, a data dos recordes era cortada (nome e data agora vão pra linhas separadas a partir de `.xxLarge`).
- README: linhas 14–20. Pares web 14–17 em `ios/validation/C/`.

## Answer

**Feito e validado no iPhone (2026-10-23)**, no worktree `../strava_dashboard-corrida`, branch `fase-c` (sem commit: fica com o usuário). O usuário aprovou a galeria da Fase C, linhas 14–19.

- **Kit** (210 testes): `RunOverview.swift` com totais, calendário, recordes (12 distâncias, mais longa), `PrSnapshot` (port de `prSnapshot.ts` com os testes da web), tênis e os formatadores da página.
- **App**: `RunStore.loadOverview()` (recordes e tênis pelo Cache JSON, snapshot de recorde no `UserDefaults` por usuário) e `RunOverviewView`, com totais, calendário com leitura do dia tocado, recordes 1k/5k/10k + mais longa, sheet "Ver todos" com 2º/3º e selo PR, carrossel de tênis, "Powered by Strava" e o recorde novo com selo "Novo" + pop em mola.
- **A aba Corrida continua abrindo em Atividades**, como o `MOBILE_TABS` da web. O ticket dizia o contrário, e estava errado.
- **Desvios aceitos**:
  - "Ver todos" em sheet nativo;
  - recorde novo sem o brilho;
  - vírgula decimal em PT;
  - com texto grande, nome e data dos recordes em linhas separadas e o texto do chip parando em `.large`.
- **Pendente pro [Uso real da Fase C](38-uso-real-fase-c.md)**: a linha 20 (comemoração de recorde novo), que só aparece com um recorde real.
