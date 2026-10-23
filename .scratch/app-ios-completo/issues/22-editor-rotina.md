# Editor de rotina: criar e editar

Type: task
Status: resolved
Blocked by: 21

## Question

Portar `RoutineEditPage`/`useRoutineEditor`/`RoutineExercisePicker`/`RoutineExerciseEditPage`: a Rotina inteira montada em memória e uma única chamada no Salvar (`POST` ao criar, `PATCH` com a lista inteira ao editar), busca multi-seleção com chips de grupo muscular, steppers de séries/faixa de reps/Descanso (passos de 15 s, "Padrão"), reordenar com `.onMove`, confirmação ao descartar alterações. A lógica de "tem alteração?" (`isDirty`/`exercisesSignature`) vai pro Kit com os testes da web traduzidos. Se estourar a sessão, dividir em "editar existente" e "criar" e registrar. Termina com o checklist da Fase T no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase T (Treino completo)](18-fatiamento-fase-t.md).

## Answer

**Feito e validado no iPhone (2026-10-23).** O usuário aprovou a galeria da Fase T, linhas 18–25, e fez o teste funcional da linha 26 em produção: criou uma rotina, reordenou arrastando, mudou metas, salvou, editou removendo um exercício e conferiu ordem e metas no detalhe. Não precisou dividir em "editar" e "criar".

- **Kit** (`RoutineEditor.swift`, 141 testes passando): `RoutineDraft` é o `useRoutineEditor` da web: rotina inteira em memória, `isDirty` contra o que carregou (ordem e metas contam, a identidade da linha não; ao criar, qualquer coisa digitada ou adicionada), `canSave` (nome obrigatório), `toggle` do seletor (adiciona com 3 × 10–12 ou remove), `remove`/`update`/`move` (contrato do `onMove`) e `request`. `TargetSteps` traz os limites dos steppers (séries 1–10, reps 1–50 com mín ≤ máx, descanso de 15 em 15 s entre 15 s e 10 min, "+" a partir de "Padrão" cai em 1:30, "−" no mínimo volta pra "Padrão"). `MuscleFilter` traz os chips do seletor e o `?muscles=`. **A web não tinha testes dessa lógica**, então os testes foram escritos a partir do comportamento dela.
- **Corpo do pedido**: `POST /workout-templates` ao criar, `PATCH /workout-templates/:id` com a lista inteira ao editar. **Sem `description`**: o app não tem campo, como a web no mobile, e omitir a chave faz o `PATCH` preservar a descrição escrita na web. Metas nulas são omitidas.
- **App**:
  - `RoutineEditView` abre em tela cheia, com Cancelar/Salvar na barra. Tem "NOME DA ROTINA", "EXERCÍCIOS" com a contagem, linhas com "≡", nome, metas e "×", e "+ Adicionar exercício".
  - O arraste é o long press nativo do `List` (`onMove`), e deslizar também apaga. Tocar numa linha empilha `RoutineTargetsEditView` (os três cartões de stepper). Cancelar com alteração pede "Descartar alterações?".
  - `RoutineExercisePickerView` é uma folha com busca, chips de músculo, "N selecionados" e "+/✓" por linha.
  - Entradas: "+ Nova rotina" no topo de Rotinas, ao lado de "N rotinas salvas" (como a web), "Nova rotina" no vazio de Rotinas (o texto mudou pra "Crie uma rotina ou comece um treino livre.") e o lápis no detalhe da rotina, que recebe a rotina salva de volta.
  - No `WorkoutStore` entraram `saveTemplate` (recarrega a lista) e `searchExercises`. A linha de metas virou `RoutineTargetsText`, compartilhada entre o detalhe e o editor.
- **Validação** (linhas 18–26 da Fase T no `ios/README.md`): a web foi capturada por um `--steps` que abre os editores e nunca toca em Salvar. Desvios aceitos:
  - linhas finas em vez de cartões (padrão das listas do app, e o que dá o arraste nativo), com "≡" no lugar dos seis pontos;
  - seletor em folha, não em tela cheia;
  - "Descartar alterações?" na folha nativa;
  - Cancelar/Salvar na barra.
- **Fica pra trás, como na web mobile**: editar a descrição da rotina (só pela web desktop).
