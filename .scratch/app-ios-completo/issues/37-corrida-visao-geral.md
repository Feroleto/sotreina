# Corrida: Visão geral

Type: task
Status: open
Blocked by: 36

## Question

Portar o `RunOverviewPage.tsx`: totais all-time, calendário mensal navegável (`RunCalendar`), recordes pessoais (`GET /personal-bests`, 12 distâncias, top 3 expansível, selo PR) e tênis (`GET /gear`, barra até 800 km), com "Powered by Strava". **Comemoração de recorde novo**: `prSnapshot.ts` vai pro Kit com os testes da web, com o snapshot por usuário no `UserDefaults` (separado do da web: o mesmo recorde comemora uma vez em cada lugar); um top 1 que mudou mostra o selo "Novo" com um pop simples em mola, sem o brilho. A Visão geral entrando em `portedPages` faz a aba Corrida abrir nela, como na web. Termina com o checklist da Fase C no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase C (Corrida)](33-fatiamento-fase-c.md).
