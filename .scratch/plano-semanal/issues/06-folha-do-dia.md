# Folha do dia: Ajustes no app

Type: task
Status: open
Blocked by: 04

## Question

Construir a §6.5 da spec. Tocar numa coluna da faixa (com plano ativo) abre um `.sheet` com uma linha por Área ligada:
- **trocar Rotina**, **Mover pra…** (chips de hoje até o domingo da próxima, inválidos desabilitados com o motivo) e **Folga** (o botão diz "Pular");
- **Desfazer** em Folga e em metade de move (desfaz as duas);
- **Adicionar** numa Área não planejada;
- **Folga o dia todo** quando há duas Áreas planejadas.

Dia passado: só Folga e desfazer Folga, com a nota. Mutações otimistas pela fila do `PlanStore`, e a janela do servidor substitui o estado. Rodapé "Editar padrão semanal ›".

Quando o [Editor do Padrão no app](05-editor-padrao.md) já existir, ligar o seletor "Esta semana / Próxima" dele a esta folha, pra alcançar os dias da próxima semana.

Destinos de validação `planDaySheet` e `planDaySheetPast`. Termina com o usuário fazendo no iPhone cada Ajuste (inclusive um move que cruza o domingo e uma Folga retroativa) e vendo o Hoje e o "X de Y" responderem.
