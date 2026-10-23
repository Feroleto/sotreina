# Peso em lb na sessão, no resumo e na Live Activity

Type: task
Status: resolved
Blocked by: 17

## Question

Aplicar a unidade de peso do usuário (`Me.weightUnit`, `UnitConversion` do Kit) a tudo que o app já mostra em kg: grade de séries e Proposta de série da Sessão (entrada convertida de volta pra kg antes do `POST`/`PATCH`, passos de ±2,5 kg / ±5 lb), Resumo (volume, PRs) e Live Activity (a unidade precisa ir no `ContentState`, como o `lang`). Mesmas regras de arredondamento da web (`lib/units.ts`: lb com 1 casa, kg com 2). A partir desta tarefa, toda tela nova da Fase T usa a unidade. Termina com o checklist da Fase T no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Inclui também a conferência em EN que ficou pendente em [Strings das telas da Navegação em PT/EN](17-strings-telas-navegacao.md): Sessão (botões, diálogos, sheet de edição) e barra de treino minimizado. Regras da fase em [Fatiamento da Fase T (Treino completo)](18-fatiamento-fase-t.md).

## Answer

**Feito e validado no iPhone (2026-10-23).** O usuário aprovou a galeria da Fase T, linhas 01–08.

- **Kit** (120 testes passando):
  - `WorkoutFormat.weight/set/volume` recebem `unit:` (default `.kg`) e convertem por `UnitConversion.display`. "45 lb × 5". Saiu a sobrecarga `weight(_:)`, que não tinha mais uso.
  - **Volume como na web** (`formatVolume` + `volumeLabel`): milhares da unidade, sempre com uma casa ("1,8 t", "4.0 k lb"). Antes o resumo mostrava "1.820 kg", formato que não existe na web e não tem equivalente em lb.
  - `SetInput.weightKg(_, unit:)` converte o que foi digitado. `SetInput.editedWeightKg` devolve o kg guardado intacto quando o campo do sheet de edição não mudou, senão 20,03 kg → 44,2 lb → 20,05 kg.
  - `WorkoutActivitySnapshot.weightUnit` (opcional, pra decodificar estado antigo, `nil` = kg) e `proposalText`. O link "✓" continua em kg.
- **App**: `SessionStore.weightUnit` → `WorkoutStore.weightUnit`. Na Sessão, as séries, as pendentes, o placeholder da proposta, o rótulo do campo, "última vez" e o sheet de edição usam a unidade. O Resumo recebe a unidade do `AppShell`. A Live Activity usa `proposalText`.
- **Passos de ±2,5 kg / ±5 lb**: o app não tem stepper de peso na Sessão, só campo de texto, então não entraram. `UnitConversion.stepped` segue no Kit pro dia em que houver stepper.
- **Limite conhecido**: trocar a unidade com um treino aberto só chega à Live Activity na próxima mudança do treino.
- **Bug corrigido pelo caminho, anterior a este ticket**: o `lastPerformance` do `WorkoutStore` era buscado uma vez por exercício enquanto o app estivesse aberto. Depois de finalizar, o treino seguinte propunha os números de antes. Agora o `finish()` limpa o cache.
- **Validação** (linhas 01–08 da Fase T no `ios/README.md`, capturas em `ios/validation/T/`): a ida e volta 44,1 → 45 lb pelo sheet de edição voltou "45 lb × 5", e o recorde em lb aparece no Resumo. A conferência em EN da Sessão, que vinha das [Strings das telas da Navegação em PT/EN](17-strings-telas-navegacao.md), também fechou aqui.
- **Fora do escopo, anotado**: na web, o Resumo em PT escreve "0.2 k lb" com ponto (`toFixed`) e o cabeçalho "SÉRIE" encosta em "ANTERIOR" na grade da sessão. Um exercício sem séries num treino finalizado apaga a proposta dele no treino seguinte (fog no mapa).
- **Dados de teste**: em produção ficaram 2 treinos finalizados e a conta em lb, com o OK do usuário. No banco local ficou 1 treino "Upper" finalizado, e a conta voltou pra kg.
