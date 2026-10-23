# Fatiamento da Fase D (Dieta)

Type: grilling
Status: resolved
Blocked by:

## Question

Em que tickets `task` de construção a Fase D se divide, em que ordem e com que bloqueios? Cada fatia cabe numa sessão de agente, termina validada no iPhone (checklist da fase com a coluna App) e deixa a paridade web ↔ app em vigor para o que portou. Escopo da fase (spec §3, Fase D): o dia (kcal, macros, Refeições com modo de edição), adicionar Registros (busca, carrinho, QuantitySheet, editar item e Registro salvo, cadastro manual), scanner nativo (`DataScannerViewController`), Refeições salvas (lista, editor, aplicar ao dia), histórico 7/14 dias e Meta diária. Decide também o que da lógica da web vai pro Kit em cada fatia (`quantityFormat.ts` e o que mais), se `POST /food-logs` precisa de `clientId` pra reenvio seguro (spec §5.2), e se a Fase D espera a Fase T acabar ou pode andar em paralelo.

## Answer

**Decidido com o usuário (2026-10-23).** A Fase D vira seis tarefas `task`, **em fila**, cada uma bloqueada pela anterior.

1. [Dieta: o dia e o modo de edição das Refeições](27-dieta-dia.md): o modo de edição fica junto porque é a mesma lista com outros botões. A engrenagem abre a Meta diária que já existe no Perfil do app, então a Meta diária não precisa de tarefa própria.
2. [Dieta: adicionar Registros](28-dieta-adicionar-registros.md): busca, carrinho, QuantitySheet e edição de Registro. Se estourar a sessão, divide em busca+carrinho e edição do Registro salvo.
3. [Dieta: cadastro manual e scanner](29-dieta-manual-scanner.md): ficam juntos porque o 404 do scanner abre o cadastro pré-preenchido.
4. [Dieta: Refeições salvas](30-dieta-refeicoes-salvas.md).
5. [Dieta: histórico 7/14 dias](31-dieta-historico.md).
6. [Uso real da Fase D](32-uso-real-fase-d.md).

**Regras da fase:**
- **Começa depois da [Visão geral do Treino](24-visao-geral-treino.md)** e corre junto com o [Uso real da Fase T](25-uso-real-fase-t.md). Rodar em paralelo com as tarefas de código do Treino quebraria o build: as duas sessões usam o mesmo working tree e o mesmo `deploy.sh`, e mexem em `portedPages`/`Models`/`APIClient`.
- **A fase mexe no backend, ao contrário da Fase T**: os Registros ganham `clientId` (`FoodLog.clientId` + `@@unique([userId, clientId])`, opcional no `POST /food-logs` e no `POST /saved-meals/:id/apply`, mesmo padrão do `WorkoutSet`). Sem ele, um reenvio pelo ⚠ depois de um timeout em que o servidor já gravou duplicaria o Registro. Cada parte entra na primeira tarefa que grava por aquele caminho. A migration vai pro Neon antes do deploy do backend, e a web não muda.
- **Lógica pura vai pro Kit com os testes da web traduzidos**: `quantityFormat.ts` (tarefa 2), a normalização pra 100 g (tarefa 3), o estado sujo do editor de Refeição salva se a web tiver um (tarefa 4), e a escala e as cores do histórico (tarefa 5).
- **Antes de adotar um framework, checar se ele depende de ferramenta exclusiva do Xcode**: VisionKit na tarefa 3, Swift Charts na tarefa 5. Se o Charts não compilar, as barras são desenhadas à mão, como a web faz com `div`s.
- **Validação por tarefa**, com as linhas da Fase D no checklist do README.
