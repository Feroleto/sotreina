# Corrida: Atividades

Type: task
Status: open
Blocked by: 31

## Question

Portar a vista mobile de Atividades (`Dashboard.tsx`, `MobileWeeklySummary.tsx`, `ActivityList.tsx`): resumo da semana (semana atual em Geist Mono contra a passada, faixa de 3 KPIs, barras de 12 semanas com a atual em `--acc`), lista agrupada por semana e filtro de período (presets + calendário em sheet nativo, semana começando na segunda), a partir de `GET /activities?limit=1000` com o Cache JSON. Distância e pace na unidade do usuário (`UnitConversion`). "Powered by Strava" no rodapé, preto no claro e branco no escuro: os assets de `client/src/assets/strava/` são SVG, então converter pra PDF/PNG @3x sem alterar o desenho (as guidelines proíbem modificar), em `ios/Resources/`. `bins.ts` e `activityFormat.ts` vão pro Kit com os testes da web traduzidos. "Corrida" entra em `AreaScreen.portedPages` (abre em Atividades até a [Corrida: Visão geral](37-corrida-visao-geral.md) entrar). Tocar numa atividade abre o detalhe da [Corrida: detalhe da atividade](35-corrida-detalhe.md), então até lá a linha não navega. Sem mudança no backend. Termina com o checklist da Fase C no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase C (Corrida)](33-fatiamento-fase-c.md).
