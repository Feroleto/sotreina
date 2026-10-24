# Sessão de treino (iOS) — ajustes pós-redesign "Foco 2a"

Data: 2026-10-24. Continuação do redesign da tela de marcar séries do app iOS
(`ios/Sources/SoTreina/Features/Workout/WorkoutSessionView.swift`, Claude Design
"Treino Academia Foco", variante 2a). Saiu de uma conferência rápida no iPhone.

## Fora de escopo (não mexer)

- Timer de descanso (`RestBar`, `RestTimerController`, `RestTimer` no Kit).
- Live Activity: nenhum código dela muda. Ela **vai** passar a mostrar a meta
  editada ("Série 2 de 4") porque lê `target.sets` do `WorkoutDetail`, e isso é
  desejado (ver §4).
- Web: nenhum código do `client/` muda. Ela também passa a receber a meta do
  treino em `target.sets` (efeito colateral aceito, mesmo motivo).
- Histórico de treinos finalizados continua só leitura (editar série só com o
  treino aberto).

## 1. Cabeçalho do cartão ativo mais limpo

Hoje, embaixo do nome: "Meta: 3 × 5 · Última vez: 10 kg × 6 · descanso 2:00".

- Sempre visível: só "N de M" (posição) + nome do exercício + `•••`.
- **Tocar no nome (bloco do título) expande no próprio cartão** uma área de
  detalhe; tocar de novo recolhe. Sem sair da tela, sem folha.
- Conteúdo do detalhe, cada item só quando existir:
  - Meta: "3 × 5" (ou "3 × 8–12") — séries vêm da meta do treino (§4),
    reps da rotina.
  - **Última vez: todas as séries da última sessão**, em ordem, ex.
    "10×6 · 10×6 · 12,5×4" (com unidade de peso do usuário, `WorkoutFormat`).
    Hoje mostra só a mais pesada; trocar.
  - Descanso: "2:00" quando a rotina define `restSeconds` (só exibe, não
    controla o timer).
- Estado expandido é por exercício e em memória (`@State`), começa recolhido;
  não precisa sobreviver a relaunch.
- Affordance: chevron pequeno ao lado do nome ou o próprio nome tocável com
  `accessibilityHint`. Acessibilidade: o título é um botão com
  `accessibilityValue` expandido/recolhido.
- Animação: mola curta na altura (`.snappy`), nada sob Reduzir movimento.

## 2. Editar série registrada inline

Substitui o `SetEditSheet` (folha) na sessão. A folha pode ser apagada se não
houver outro uso (hoje só a sessão usa).

- Tocar numa série feita (✓) transforma **essa linha** em modo edição, com o
  mesmo visual da linha atual: campos kg/reps preenchidos com os valores
  atuais (na unidade do usuário), botão ✓ (salvar) e um ícone de **lixeira**.
- Só uma linha em edição por vez. Tocar noutra série troca a edição
  (descarta o não salvo). Tocar no ✓ salva via `store.updateSet` (mesma
  conversão de hoje: `SetInput.editedWeightKg`, `SetInput.reps`). Validação
  igual à da folha (`isValid`): texto digitado precisa parsear, e não pode
  ficar com os dois vazios.
- Fechar sem salvar: tocar de novo na mesma linha, ou o "OK" da barra do
  teclado (que só tira o foco; a linha segue aberta até salvar ou trocar —
  decidir na implementação se o OK também fecha; preferência: fecha sem salvar).
- **Apagar = segurar a lixeira** (~1,2 s, mesmo gesto do "segure pra sair" do
  menu da conta, `App/AccountMenu.swift`): preenchimento progressivo no ícone
  durante o hold, vibração ao completar, depois `store.deleteSet`. Soltar antes
  cancela. Toque curto mostra dica ("Segure para apagar"). Sob Reduzir
  movimento, o preenchimento vira troca de opacidade.
- Apagar uma série feita **não muda a meta** (§4): ela volta a aparecer como
  série por fazer.
- A linha da série atual (por registrar) continua como está.

## 3. Exercício concluído vira ativo para revisão

- Tocar num exercício da lista "Concluídos" o torna o cartão ativo (como já
  acontece), mostrando as séries feitas, editáveis por §2.
- Quando feitas ≥ meta, o cartão **não mostra a linha de registrar**. Pra fazer
  uma série a mais, usa "+ Série" (§4), que cria uma planejada e a linha de
  registrar reaparece.
- Isso vale pra qualquer exercício (inclusive o seguido pelo cursor): sem
  séries por fazer, sem linha de registrar.
- A regra "escolha manual volta pro cursor ao bater a meta" continua.

## 4. Número de séries editável durante o treino

### Interação (cartão ativo)

- Botão **"+ Série"** discreto no fim da lista de séries do cartão: adiciona
  uma série planejada (meta + 1).
- Cada série **planejada** (tracejada, ainda não feita) tem um controle de
  remover (× / −) à direita, no lugar do círculo tracejado ou ao lado: meta − 1.
- **Mínimo**: a meta nunca fica abaixo do número de séries já feitas
  (registradas + pendentes), e nunca abaixo de 1. Só série não feita pode ser
  removida. Pra tirar o exercício inteiro, `•••` › Remover exercício.
- A série atual (linha de registrar) conta como planejada pra esse fim: se a
  meta é 3 e há 2 feitas, a atual é a 3ª; remover tira a atual e o exercício
  fica concluído. Decidir na implementação se o × aparece na linha atual ou só
  nas tracejadas — preferência: só nas tracejadas, e a atual some ao baixar a
  meta pelo controle da última tracejada; se não houver tracejadas, a linha
  atual ganha um × pequeno.
- Atualização otimista: a UI muda na hora; a chamada vai pela fila de
  mutações (`WorkoutStore.enqueue`, mesma da sessão); em falha, volta ao valor
  do servidor e mostra o erro do jeito que as outras mutações já mostram.

### Persistência (servidor)

- Coluna nova `WorkoutExercise.targetSets Int?` (`target_sets`), migration
  `add_workout_exercise_target_sets`, DDL puro (coluna nullable). Ordem de
  deploy: migration no Neon → backend → app.
- **Copiada no início**: `POST /workouts` com `templateId` grava em cada
  `WorkoutExercise` o `targetSets` da `WorkoutTemplateExercise` correspondente.
  Editar a rotina depois não mexe no treino aberto.
- **Exercício adicionado no meio do treino** (`POST /workouts/:id/exercises`):
  começa com `targetSets = 1`. Vale pra treino livre e pra exercício extra num
  treino de rotina (o servidor faz isso; a web também ganha, sem mudança no
  `client/`).
- Edição: estender o `PATCH /workouts/:id/exercises/:workoutExerciseId` (hoje
  só `order`, `parseReorderExerciseInput`) pra aceitar `targetSets` (inteiro,
  1–20, e ≥ séries já gravadas; senão 400). `order` e `targetSets` opcionais,
  pelo menos um presente; a web continua mandando só `order`. Devolve o
  `WorkoutDetail` completo, como toda mutação. Posse pela cadeia relacional,
  404 nunca 403 (convenção do módulo).
- Leitura (`buildDetail`): `target.sets = we.targetSets ?? template.targetSets
  ?? null`. Quando o exercício não está na rotina mas tem `targetSets`,
  `target` vira `{ sets: we.targetSets, repsMin: null, repsMax: null,
  restSeconds: null }` (hoje seria `null`).
- **Treinos abertos antes do deploy** (`targetSets` null): caem na meta da
  rotina; exercício sem rotina e sem `targetSets` segue a regra antiga do app
  (nunca "concluído" sozinho) até alguém editar — aceitável, é transitório.
  Alternativa barata no app: tratar `target == nil` como meta 1.
- `getTemplateDrift`/`syncFromWorkout` não mudam: comparam/gravam o número de
  séries **feitas**, então mexer na meta durante o treino e fazer outra
  quantidade já dispara o "Atualizar rotina?" ao finalizar, como hoje.
- Testes no `server/test/`: parse do PATCH (só order, só targetSets, ambos,
  nenhum, abaixo do feito, fora da faixa), cópia no start com template,
  `1` no add, fallback de leitura, 404 de outro usuário. Teste pinando a
  migration como DDL puro (padrão das anteriores).

### App (Kit + store)

- Kit: nenhum tipo novo obrigatório (`ExerciseTarget.sets` já existe). Se a
  regra de "pode remover / mínimo" ganhar lógica, ela vai pro Kit com teste
  (`swift test`), ex. `SetPlan.canRemove(target:done:)`.
- `WorkoutStore`: `setTargetSets(workoutExerciseId:_:)` com otimismo + fila.
- `APIClient`: corpo `{ "targetSets": n }` no PATCH existente.

## 5. Verificação

- `npx tsc --noEmit` + testes do `server/`; `swift test` no Kit; `xtool dev
  build`; deploy no iPhone e conferir:
  - cabeçalho recolhido/expandido, "Última vez" com todas as séries;
  - editar peso de uma série de um exercício concluído; segurar lixeira apaga,
    toque curto não;
  - "+ Série" / remover planejada, mínimo respeitado, Live Activity mostrando
    "de N" novo;
  - exercício adicionado começa com 1 série e fica concluído após registrá-la;
  - concluído sem linha de registrar; "+ Série" a traz de volta;
  - finalizar com meta alterada oferece "Atualizar rotina?".
- Atualizar o `CLAUDE.md` (Backend: coluna nova e regra de leitura; App iOS:
  sessão).
