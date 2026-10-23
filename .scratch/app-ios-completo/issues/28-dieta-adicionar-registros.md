# Dieta: adicionar Registros

Type: task
Status: resolved
Blocked by: 27

## Question

Portar o `AddMealPage.tsx` sem scanner, cadastro manual e Refeições salvas: busca local com debounce (`GET /foods/search`), carrinho local, **QuantitySheet** (modo unidade/gramas, passos 0,5 unidade / 10 g, atalhos, `= N g` ao vivo, prévia de kcal/macros, trocar de modo carrega o peso), editar item do carrinho e Registro já salvo (`PATCH /food-logs/:id` otimista com rollback), "Salvar refeição" com um `POST /food-logs` por item. **Backend**: `FoodLog.clientId` nullable + `@@unique([userId, clientId])` e `clientId` opcional no `POST /food-logs`, com o mesmo comportamento do `WorkoutSet` (reenvio devolve o Registro já gravado, `P2002` engolido só com `clientId`), migration aplicada no Neon antes do deploy do backend; a web não muda. Falha de um item vira ⚠ com reenvio pelo mesmo `clientId`. `quantityFormat.ts` vai pro Kit com os testes da web traduzidos. Se estourar a sessão, divide em busca+carrinho e edição do Registro salvo. Termina com o checklist da Fase D no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase D (Dieta)](26-fatiamento-fase-d.md).

## Answer

**Feito e validado no iPhone (2026-10-23).** O usuário aprovou a galeria da Fase D, linhas 08–13. As linhas 14 (funcional, inclusive o ⚠) e 15 (Dynamic Type) ficaram pro [Uso real da Fase D](32-uso-real-fase-d.md), a pedido do usuário.

- **Backend**: `FoodLog.clientId` (nullable) + `@@unique([userId, clientId])`, `clientId` UUID opcional no `POST /food-logs`. Um reenvio com `clientId` já gravado devolve o Registro guardado. Dois reenvios em corrida caem no `P2002`, que só é engolido quando há `clientId`, e aí o servidor relê o vencedor. O `assertOwned` da refeição roda antes até do reenvio. A web não muda. Testes de dto e service seguindo o padrão do `WorkoutSet`, 594 passando. Conferido no servidor local: três POSTs com o mesmo `clientId` (dois em corrida) gravaram um Registro só. **Pendente em produção**: migration `20261023175242_add_food_log_client_id` no Neon, depois o deploy do backend. Até lá o backend antigo ignora o campo, e o app funciona, só que sem deduplicar.
- **Kit** (`DietQuantity.swift`, 268 testes):
  - `Quantity` é o port do `quantityFormat.ts`, com os testes da web traduzidos. O plural segue o `Intl.PluralRules`: em PT "one" vale abaixo de 2, então fica "1,5 unidade", como na web.
  - `QuantityInput` guarda o estado do QuantitySheet: modo, texto aceitando vírgula, passos, atalhos, teto de 5 kg, troca de modo levando o peso junto, prévia das macros.
  - `MealCart`: o `clientId` é a identidade do item e a chave de idempotência. Um item com ⚠ fica travado, porque um reenvio devolveria a quantidade antiga guardada no servidor.
  - `CreateFoodLogRequest`/`UpdateFoodLogRequest`, `DietFormat.dayShort`.
- **App**:
  - `AddMealView`/`AddMealStore`: tocar numa Refeição da Visão geral empilha a tela, com a refeição e a data no topo, o campo de busca próprio (debounce de 250 ms), "Nesta refeição" (Registros salvos + carrinho), os resultados com prévia e +/✓, e a barra de baixo com os totais. A tab bar some nessa tela.
  - Registro salvo: editar é `PATCH` otimista e remover é `DELETE` otimista, os dois voltam atrás se o servidor recusar.
  - "Salvar refeição" envia item a item. O que deu certo vai pra lista dos salvos; o que falhou fica com ⚠ "Não salvo" e o próximo Salvar reenvia com o mesmo `clientId`. A tela só fecha quando o carrinho fica vazio.
  - `QuantitySheetView` em sheet nativo do tamanho do conteúdo.
  - Strings PT/EN `diet.addMeal.*`/`diet.quantity.*`.
- **Desvios aceitos**:
  - Linha fina entre os resultados (a web não tem).
  - Sheet nativo, com alça e fundo menos escurecido.
  - ⚠ por item, onde a web para no primeiro erro e, ao tentar de novo, duplicaria os itens já salvos.
- Corrigido na validação: o `.searchable` não aparecia na tela empilhada e, com a lista vazia, a `ScrollView` encolhia até a largura das margens. A busca virou um campo próprio, que é onde os botões de scanner e de Refeições salvas vão entrar na próxima tarefa.
- Ficam pras próximas tarefas: o link "Adicionar manualmente" e o scanner ([Dieta: cadastro manual e scanner](29-dieta-manual-scanner.md)), e "Salvar como refeição salva" ([Dieta: Refeições salvas](30-dieta-refeicoes-salvas.md)).
