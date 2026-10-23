# Fatiamento da Fase T (Treino completo)

Type: grilling
Status: resolved
Blocked by:

## Question

Em que tickets `task` de construção a Fase T se divide, em que ordem e com que bloqueios? Cada fatia cabe numa sessão de agente, termina validada no iPhone (checklist da fase com a coluna App) e deixa a paridade web ↔ app em vigor para o que portou. Escopo da fase (spec §3, Fase T): Visão geral, Rotinas (lista, detalhe, detalhe do exercício, criar/editar), Histórico (lista, detalhe do treino, detalhe do exercício na sessão), treino livre, atualizar rotina ao finalizar, e `UnitConversion` (lb) na sessão, no resumo e na Live Activity. Decide também o que da lógica da web vai pro Kit em cada fatia e se alguma precisa de mudança no backend.

## Answer

**Decidido com o usuário (2026-10-23).** A Fase T vira sete tarefas `task`, **em fila**, cada uma bloqueada pela anterior. As sessões paralelas já esbarravam nos mesmos arquivos (`WorkoutStore`, `AreaScreen.portedPages`), e cada fatia reaproveita a anterior.

1. [Peso em lb na sessão, no resumo e na Live Activity](19-peso-lb-sessao.md): vem primeiro porque hoje o app mostra kg pra quem escolheu lb. Daqui em diante, toda tela nova nasce com a unidade.
2. [Sessão: treino livre e atualizar rotina ao finalizar](20-sessao-livre-atualizar-rotina.md): o que o usuário usa todo dia na academia.
3. [Rotinas: detalhe da rotina e detalhe do exercício](21-rotinas-leitura.md): vem antes do editor, que reaproveita as linhas e o detalhe do exercício.
4. [Editor de rotina: criar e editar](22-editor-rotina.md): uma tarefa só, porque criar e editar compartilham o modelo. Se estourar, divide em editar e criar.
5. [Histórico do Treino](23-historico-treino.md).
6. [Visão geral do Treino](24-visao-geral-treino.md): por último, porque reaproveita o calendário e os agregados do Histórico. Uma tarefa só. Se estourar, divide em calendário + recorde.
7. [Uso real da Fase T](25-uso-real-fase-t.md): o uso real é da fase inteira, não de cada tarefa.

**Regras da fase:**
- **Nenhuma fatia mexe no backend.** `PATCH .../finish` com `syncTemplate`, `POST /workouts` sem `templateId`, `history-stats` e `GET /exercises/:id` já existem.
- **Lógica pura vai pro Kit com os testes da web traduzidos**: `isDirty`/`exercisesSignature` no editor, `historyBins` e Epley no Histórico.
- **Validação por tarefa**, com as linhas da Fase T no checklist do README e a coluna App preenchida.
- A Visão geral entrando em `AreaScreen.portedPages` faz a aba Treino abrir nela, como na web.
- **A tarefa do peso em lb também espera** a [Strings das telas da Navegação em PT/EN](17-strings-telas-navegacao.md). As duas mexem nas mesmas chamadas de `WorkoutFormat.weight` na Sessão.
- **Fica pra decidir dentro da tarefa da Sessão**: onde fica o botão de entrada do treino livre.
