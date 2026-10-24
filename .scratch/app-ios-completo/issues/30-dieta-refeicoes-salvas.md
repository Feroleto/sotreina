# Dieta: Refeições salvas

Type: task
Status: resolved
Blocked by: 29

## Question

Portar `SavedMealsListPage.tsx`/`SavedMealEditPage.tsx`/`useSavedMealEditor.ts`: lista, editor (QuantitySheet só como entrada, confirma em gramas, como a web) e aplicar a uma Refeição do dia (`POST /saved-meals/:id/apply`). **Backend**: `clientId` opcional no `apply`, que, com o `FoodLog.clientId` da [Dieta: adicionar Registros](28-dieta-adicionar-registros.md), torna o reenvio idempotente (um reenvio devolve os Registros já gravados em vez de duplicar a Refeição salva inteira); migration, se precisar, no Neon antes do backend. Lógica pura do editor (sujo/assinatura, se a web tiver) vai pro Kit com teste. Termina com o checklist da Fase D no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase D (Dieta)](26-fatiamento-fase-d.md).

## Answer

**Feito e validado no iPhone (2026-10-24).** As linhas 23–28 e 30 do checklist da Fase D foram conferidas. A 29 ("Usar" em modo avião sem duplicar) ficou pro [Uso real da Fase D](32-uso-real-fase-d.md), depois do deploy do backend.

- **Bug na web, corrigido pelo caminho**: o "Usar" da web nunca funcionou. Em `AddMealPage.applySavedMeal(meal: SavedMealSummary)`, o parâmetro sombreava a prop `meal` e mandava o id da refeição salva como `mealId`, então o `assertOwned` sempre respondia 404. O parâmetro virou `savedMeal`. A correção não foi conferida no navegador.
- **Backend (sem migration)**: `POST /saved-meals/:id/apply` aceita `clientId` opcional (UUID). Cada Registro grava `FoodLog.clientId = "<clientId>:<n>"`. O `POST /food-logs` só aceita UUID puro, então os dois não colidem. Um reenvio que acha qualquer `<clientId>:*` devolve o que já está gravado, em ordem: a transaction é tudo-ou-nada. Um `P2002` de corrida relê o vencedor. São 8 testes novos e 650 passando. **Pendente**: deploy do backend no Render. Até lá o app funciona contra produção, mas sem a proteção contra duplicar.
- **Kit** (`DietSavedMeals.swift`, 13 testes, 321 no total): os modelos; `SavedMealDraft`, que porta o `useSavedMealEditor` (sujo por ordem e gramas, + adiciona uma medida caseira, nome aparado, carrinho como semente); e `SavedMealApplyKeys` (o mesmo `clientId` até o "Usar" dar certo).
- **App**:
  - Botão de favoritos ao lado do scanner, que empilha `SavedMealsListView`: cards com nome, prévia, kcal, ✎, 🗑 com confirmação nativa e "Usar". O voltar é só a seta (`.toolbarRole(.editor)`), porque "Café da manhã" não cabia ao lado do título e o iOS mostrava "Back" no idioma do iPhone.
  - `SavedMealEditView` em tela cheia com Cancelar/Salvar, como o editor de rotina. O QuantitySheet ali só serve de entrada e sempre confirma em gramas.
  - "Salvar como refeição salva" embaixo do carrinho (só itens não enviados) abre o editor com eles e, depois de salvar, a lista. A navegação acontece no `onDismiss` do cover.
  - A busca saiu do `AddMealStore` pra `FoodSearch`, compartilhada com o editor.
  - Strings `diet.savedMeals.*` em PT/EN.
- **Desvios aceitos**:
  - Depois do "Usar", o app volta pro Adicionar com os Registros em "Nesta refeição", em vez de ir pra Visão geral como a web. Na web, o carrinho não salvo se perde nesse ponto.
  - Ícone de marcador simples no lugar do `BookmarkPlus`.
  - "Usar" no tamanho do botão primário (46 pt).
  - Campo de nome sem foco automático.
