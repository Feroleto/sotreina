# Hoje com o Plano da semana no app

Type: task
Status: open
Blocked by: 03

## Question

Construir as §6.2–§6.4 da spec:

- `PlanStore` no shell (janela atual + próxima, fila de mutações, recarga no primeiro plano e na virada do dia, `ResponseCache`);
- `TodayView` com plano ativo: status só do planejado + Dieta + Extra, linha de Dia livre, faixa seg–dom no lugar do `LastDays`, "Por área" com "X de Y" no Treino e o subtítulo da Corrida;
- `TodaySingleArea`/tela filtrada respeitando o plano;
- convite "Planeje sua semana" sem plano. Ele empilha um placeholder até o [Editor do Padrão no app](05-editor-padrao.md) existir;
- próximo Treino seguindo o plano no Hoje, no `GymOverviewView` e no selo "Próxima" do `RoutinesView`.

Destinos de validação `todayPlanned` e `todayRestDay` (dado fixo). O plano para testar é criado via `curl` na API local (o iPhone a alcança pela LAN, ver `ios/README.md`). A faixa ainda não abre a folha, isso fica pra [Folha do dia: Ajustes no app](06-folha-do-dia.md).

Termina com o app no iPhone e o usuário conferindo:
- claro, escuro, EN e VoiceOver na faixa;
- uma semana com feito, Perdido, planejado futuro, Folga e Extra;
- uma só Área ligada;
- sem plano.
