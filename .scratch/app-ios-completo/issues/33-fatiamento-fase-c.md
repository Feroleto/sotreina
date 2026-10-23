# Fatiamento da Fase C (Corrida)

Type: grilling
Status: resolved
Blocked by:

## Question

Em que tickets `task` de construção a Fase C se divide, em que ordem e com que bloqueios? Cada fatia cabe numa sessão de agente, termina validada no iPhone (checklist da fase com a coluna App) e deixa a paridade web ↔ app em vigor para o que portou. Escopo da fase (spec §3, Fase C): Visão geral (totais, calendário, recordes, tênis), Atividades (resumo da semana, lista por semana, filtro de período), detalhe (stats, mapa MapKit, voltas, "View on Strava"), editor de voltas, selos da Strava e distância/pace em km ou mi. Decide também o que da lógica da web vai pro Kit em cada fatia, se o editor de voltas (e a Análise, que segue fora) ganha mi junto com o port, se alguma fatia mexe no backend, e onde a Fase C entra na fila em relação às Fases T e D.

## Answer

**Decidido com o usuário (2026-10-23).** A Fase C vira cinco tarefas `task`, **em fila**, cada uma bloqueada pela anterior.

1. [Corrida: Atividades](34-corrida-atividades.md): vem primeiro, junto do detalhe, porque é o que se abre depois de cada corrida. Até a Visão geral entrar, a aba Corrida abre em Atividades.
2. [Corrida: detalhe da atividade](35-corrida-detalhe.md).
3. [Corrida: editor de voltas](36-corrida-editor-voltas.md): se estourar a sessão, divide em lista+cobertura e Salvar.
4. [Corrida: Visão geral](37-corrida-visao-geral.md).
5. [Uso real da Fase C](38-uso-real-fase-c.md).

**Regras da fase:**
- **Começa depois da [Dieta: histórico 7/14 dias](31-dieta-historico.md)** e corre junto com o [Uso real da Fase D](32-uso-real-fase-d.md), pela mesma razão da Dieta: o working tree e o `deploy.sh` são compartilhados.
- **O editor de voltas fica em metros e segundos, sem mi**, igual à web, que passa `'KM'` fixo. Os tamanhos são distâncias de pista, que continuam métricas pra quem usa milhas, e dar mi ao editor obrigaria a mudar a web junto. Distância e pace do resto (lista, detalhe, resumo da semana, totais) seguem a unidade do usuário. A Análise continua fora.
- **A comemoração de recorde novo entra** na Visão geral: `prSnapshot` no Kit, snapshot no `UserDefaults` separado do da web, selo "Novo" com um pop em mola, sem o brilho.
- **Nenhuma fatia mexe no backend.**
- **Lógica pura vai pro Kit com os testes da web traduzidos**: `bins.ts` e `activityFormat.ts` (tarefa 1), `polyline.ts` (tarefa 2), `lapBoundaryMath.ts` (tarefa 3) e `prSnapshot.ts` (tarefa 4).
- **Os selos da Strava são SVG**, que o SwiftUI não desenha solto. A tarefa 1 converte pra PDF/PNG sem alterar o desenho. Antes de adotar o MapKit (tarefa 2), checar se ele depende de ferramenta exclusiva do Xcode.
- **Validação por tarefa**, com as linhas da Fase C no checklist do README.

**Emenda (2026-10-23, com o usuário):** a regra "começa depois da Dieta: histórico 7/14 dias" caiu. A fila era só de ferramenta, então a Corrida roda em paralelo com o Treino, num git worktree próprio (`../strava_dashboard-corrida`, branch `fase-c`). As regras de convivência estão nas Notes do mapa. [Corrida: Atividades](34-corrida-atividades.md) deixou de esperar a Dieta.
