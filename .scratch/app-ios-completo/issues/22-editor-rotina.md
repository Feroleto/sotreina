# Editor de rotina: criar e editar

Type: task
Status: open
Blocked by: 21

## Question

Portar `RoutineEditPage`/`useRoutineEditor`/`RoutineExercisePicker`/`RoutineExerciseEditPage`: a Rotina inteira montada em memória e uma única chamada no Salvar (`POST` ao criar, `PATCH` com a lista inteira ao editar), busca multi-seleção com chips de grupo muscular, steppers de séries/faixa de reps/Descanso (passos de 15 s, "Padrão"), reordenar com `.onMove`, confirmação ao descartar alterações. A lógica de "tem alteração?" (`isDirty`/`exercisesSignature`) vai pro Kit com os testes da web traduzidos. Se estourar a sessão, dividir em "editar existente" e "criar" e registrar. Termina com o checklist da Fase T no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase T (Treino completo)](18-fatiamento-fase-t.md).
