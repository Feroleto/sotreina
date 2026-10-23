# Peso em lb na sessão, no resumo e na Live Activity

Type: task
Status: open
Blocked by: 17

## Question

Aplicar a unidade de peso do usuário (`Me.weightUnit`, `UnitConversion` do Kit) a tudo que o app já mostra em kg: grade de séries e Proposta de série da Sessão (entrada convertida de volta pra kg antes do `POST`/`PATCH`, passos de ±2,5 kg / ±5 lb), Resumo (volume, PRs) e Live Activity (a unidade precisa ir no `ContentState`, como o `lang`). Mesmas regras de arredondamento da web (`lib/units.ts`: lb com 1 casa, kg com 2). A partir desta tarefa, toda tela nova da Fase T usa a unidade. Termina com o checklist da Fase T no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase T (Treino completo)](18-fatiamento-fase-t.md).
