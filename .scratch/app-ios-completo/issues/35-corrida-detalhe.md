# Corrida: detalhe da atividade

Type: task
Status: resolved
Blocked by: 34

## Question

Portar o `ActivityDetailView.tsx`: badge de tipo, grid de stats, mapa em **MapKit** com a polyline decodificada do `summaryPolyline` (placeholder pra esteira), tabela de voltas na unidade do usuário, link "View on Strava" (texto literal, `#FC5200`, bold, usa o `stravaId` string de `GET /activities/:id`) e "Powered by Strava". `polyline.ts` vai pro Kit com teste. Antes de começar, confirmar que o MapKit do SwiftUI não depende de ferramenta exclusiva do Xcode. Termina com o checklist da Fase C no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase C (Corrida)](33-fatiamento-fase-c.md).

## Progresso (2026-10-23, no worktree `../strava_dashboard-corrida`, branch `fase-c`, sem commit)

- **MapKit sem Xcode**: confirmado no build. `Map`/`MapPolyline`/`Annotation` (iOS 17+) compilam e linkam pelo xtool, sem macro nem processador de metadados. Falta ver o mapa renderizando no aparelho.
- **Kit** (169 testes, 16 novos em `ActivityDetailTests`):
  - `ActivityDetail.swift`: `ActivityDetail`/`ActivityLap` (`GET /activities/:id`), `Polyline.decode` (port de `polyline.ts`; a web não tinha teste, então entrou o exemplo de referência do Google e uma string truncada), `route` (nil sem polyline ou com menos de 2 pontos) e `fastestLapPace`.
  - Em `RunFormat`: `lapLabels` (devolve chave + número, com os 4 testes da web traduzidos), `workoutTypeKey`, `minSec`, `lapDistance` (2 casas, vírgula em PT) e `dateFull` ("Terça-feira, 04 de agosto · 15:48" / "Tuesday, August 04 · 03:48 PM", como o `toLocale*String` da web).
  - Fixtures `activity-detail.json` (intervalado com GPS) e `activity-detail-treadmill.json` (esteira), tiradas da API local.
- **App**:
  - `RunStore.cachedDetail`/`detail` pelo Cache JSON.
  - `RunActivityDetailView`: badge de tipo na barra de navegação (no lugar do "← Voltar" + badge da web), nome, data e "View on Strava" (`Link`, #FC5200, semibold), as 6 stats do mobile, o mapa estático 8:3 (linha mostarda, ponto verde no início e `fg` no fim, com anel `card`), a grade "Sem dados de GPS" da esteira, a tabela de voltas mobile (#, volta, dist, tempo, pace, FC média) e "Powered by Strava". O cabeçalho e as stats saem da linha da lista na hora, e as voltas chegam com o fetch.
  - A linha da lista de Atividades empilha o detalhe (`navigationDestination(for: ActivityListItem.self)`).
- **Strings**: `activity.*` e `common.workout.*` da web, com o plural `activity.laps.count`.
- **Decisão minha, aprovada pelo usuário**: o mapa é **estático** (sem arrastar nem zoom), pra página rolar por cima dele. Na web o Leaflet aceita arrastar.
- "Editar voltas" ainda não aparece: entra com o [Corrida: editor de voltas](36-corrida-editor-voltas.md).
- README: linhas 08–13 da Fase C. Pares web 08 e 09 capturados em `ios/validation/C/`.
- **Parado por decisão do usuário**: a instalação espera o Histórico do Treino ser commitado em `main`. Depois: merge de `main` em `fase-c`, `deploy.sh` do worktree e captura das linhas 08–13.

### Retomada (2026-10-23)

- Histórico do Treino commitado em `main` (`ce68a80`). Guardei o trabalho num stash, fiz o merge de `main` em `fase-c` (conflitos de fim de arquivo nos `.strings`, `.stringsdict` montado pela união das chaves, `AppShell` com os dois stores, `portedPages` com as três páginas). O usuário commitou o merge (`15dc3a4`), e reapliquei o stash resolvendo os `.strings` do mesmo jeito.
- Instalado pelo worktree. Linhas 08, 09, 11, 12 e 13 capturadas.
- A linha 13 (Dynamic Type máximo) pediu três ajustes na tabela de voltas: deixar o texto encolher não bastou ("TEM…"), quebrar o cabeçalho em duas linhas partiu "TEMP/O" no meio. Ficou assim: a tabela para de crescer em `.xLarge`, o texto encolhe até 70% e a coluna FC média tem 52 pt (na web são 44).

## Answer

**Feito e validado no iPhone (2026-10-23)**, no worktree `../strava_dashboard-corrida`, branch `fase-c` (sem commit: fica com o usuário). O usuário aprovou a galeria da Fase C, linhas 08, 09, 11, 12 e 13.

- **MapKit funciona com xtool**: `Map`/`MapPolyline`/`Annotation` compilam sem nenhuma ferramenta exclusiva do Xcode e renderizam no aparelho, nos dois temas.
- **Kit** (188 testes com o Treino mesclado): `ActivityDetail.swift` (`ActivityDetail`/`ActivityLap`, `Polyline.decode` port de `polyline.ts`, com o exemplo de referência do Google porque a web não tinha teste) e, em `RunFormat`, `lapLabels` (com os testes da web traduzidos), `workoutTypeKey`, `minSec`, `lapDistance` e `dateFull`.
- **App**: `RunActivityDetailView`, aberto pela linha da lista de Atividades. Tem o selo de tipo, o nome, a data e "View on Strava" (abre o app da Strava), as 6 stats do mobile, o mapa, a grade "Sem dados de GPS" pra esteira, a tabela de voltas na unidade do usuário e "Powered by Strava". O fetch passa pelo Cache JSON (`RunStore.cachedDetail`/`detail`).
- **Desvios aceitos**:
  - o mapa é estático (sem arrastar nem zoom), pra página rolar por cima;
  - o logo "Maps" e o "Legal" do MapKit ficam no lugar da atribuição Leaflet/OSM;
  - o mapa escuro usa o estilo do MapKit;
  - o selo do tipo fica na barra de navegação, ao lado do voltar nativo;
  - a tabela de voltas para em `.xLarge` e a coluna FC média tem 52 pt.
- **Pendente pro [Uso real da Fase C](38-uso-real-fase-c.md)**: a linha 10 (esteira), que o usuário pulou. O botão "Editar voltas" entra com o [Corrida: editor de voltas](36-corrida-editor-voltas.md).
