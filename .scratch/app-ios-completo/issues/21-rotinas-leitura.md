# Rotinas: detalhe da rotina e detalhe do exercício

Type: task
Status: resolved
Blocked by: 20

## Question

Portar a leitura de Rotinas: `RoutineDetailPage` (somente leitura, com editar/excluir/iniciar; editar só aparece quando o editor existir, até lá some) e `RoutineExerciseDetailPage` (imagens do `free-exercise-db` via `GET /exercises/:id`, chips, stat cards, instruções no idioma do app), com push via `NavigationStack` a partir da lista que já existe. Excluir rotina com confirmação. Pesos já na unidade do usuário. Termina com o checklist da Fase T no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase T (Treino completo)](18-fatiamento-fase-t.md).

## Answer

**Feito e validado no iPhone (2026-10-23).** O usuário aprovou a galeria da Fase T, linhas 12–17, e conferiu uma exclusão real.

- **Kit** (129 testes passando): `ExerciseDetail` (`GET /exercises/:id`, fixture real em `Fixtures/exercise-detail.json`) com `instructionsText` (passos num parágrafo, ou o `instrFallback` da web); `RoutineFormat.repsRange` ("8–12"/"10"/"—") e `RoutineFormat.rest` ("1:30"), portes de `formatRepsRange`/`formatRestSeconds`; `Equipment.label` (rótulos do `equipment` da web, `nil` = "Musculação"); `LastPerformance.heaviestWeightKg` (o "Peso anterior": a série mais pesada, sem contar peso corporal).
- **App**:
  - `RoutineDetailView`: tocar numa linha de Rotinas, fora do "Iniciar", empilha o detalhe. Tem chips de músculo, a contagem e a última vez, "EXERCÍCIOS" com as metas ("3 séries · 12 reps · descanso 1:30") e "Iniciar treino". Depois de iniciar, a tela volta pra lista.
  - A lixeira na barra pede confirmação ("Excluir esta rotina?") e faz `DELETE /workout-templates/:id`. **Editar não aparece**: entra com o [Editor de rotina: criar e editar](22-editor-rotina.md), no mesmo lugar da barra.
  - `RoutineExerciseDetailView` mostra a foto do dataset (`AsyncImage`, com um bloco liso enquanto carrega, se falhar ou se não houver foto), chips de músculo e equipamento, os cards Séries/Reps/Peso anterior (na unidade do usuário) e "COMO EXECUTAR" no idioma do app. O equipamento e as instruções só aparecem depois da busca, pra o texto de fallback não piscar.
  - As buscas ficam no `WorkoutStore` (`templateDetail`, `exerciseDetail`, `lastPerformance(exerciseId:)` reaproveitando o cache da sessão, e `deleteTemplate`).
- **Design system**: `FlowLayout` (chips que quebram linha, `flex-wrap`) e `CapsTitle` (título em caixa alta e cinza, `text-[11.5px] uppercase`).
- **Bug corrigido pelo caminho**: o botão de voltar de qualquer tela empilhada a partir de uma aba dizia "Back" no idioma do iPhone, porque a raiz escondia a barra sem título. `AreaScreen` agora dá à raiz o nome da aba ("Treino"/"Training"): ele nunca aparece, mas é o que o botão de voltar mostra.
- **Validação** (linhas 12–17 da Fase T no `ios/README.md`, capturas em `ios/validation/T/`): as telas empilhadas não têm destino no modo de validação, então o agente abre Rotinas e o usuário toca. A web foi capturada por um `--steps` que só navega. Desvios aceitos: os chips do app são maiores (`Chip` do design system) e a confirmação de excluir é a folha nativa, não a faixa inline da web.
- **Não conferido no aparelho**: "Iniciar treino" a partir do detalhe. Usa o mesmo `store.start` da lista, que já foi conferido.
