# Editor do Padrão no app

Type: task
Status: open
Blocked by: 04

## Question

Construir a §6.6 da spec: `WeekPlanEditorView`.
- Grade Área × dia, só das Áreas ligadas, com toque pra ligar/desligar e vibração.
- Toque longo numa bolinha de Treino abre a lista de Rotinas + "Qualquer rotina". A abreviação aparece na bolinha.
- Legenda e dica fixa abaixo da grade. VoiceOver com toggle + ação "Escolher rotina".
- Salvar numa chamada só (`PUT /plan/pattern`), confirmação ao voltar com alteração pendente e o aviso de grade vazia.
- `.hidesFloatingTabBar()`.

Entradas: o botão da faixa, o convite do Hoje (troca o placeholder do [Hoje com o Plano da semana no app](04-hoje-com-plano.md)) e a linha **Perfil › Metas › "Plano da semana"**. Com plano ativo, o stepper de Treinos do Perfil vira "definido pelo plano". O seletor "Esta semana / Próxima" do editor só aparece depois da [Folha do dia: Ajustes no app](06-folha-do-dia.md). Até lá, deixar o lugar reservado.

Destino de validação `weekPlanEditor`. Termina com o usuário montando o próprio Padrão no iPhone (contra a API local ou de produção) e conferindo o Hoje mudar, a meta de Treinos na web acompanhar e a grade vazia desligar o plano.
