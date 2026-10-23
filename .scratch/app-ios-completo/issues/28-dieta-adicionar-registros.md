# Dieta: adicionar Registros

Type: task
Status: open
Blocked by: 27

## Question

Portar o `AddMealPage.tsx` sem scanner, cadastro manual e Refeições salvas: busca local com debounce (`GET /foods/search`), carrinho local, **QuantitySheet** (modo unidade/gramas, passos 0,5 unidade / 10 g, atalhos, `= N g` ao vivo, prévia de kcal/macros, trocar de modo carrega o peso), editar item do carrinho e Registro já salvo (`PATCH /food-logs/:id` otimista com rollback), "Salvar refeição" com um `POST /food-logs` por item. **Backend**: `FoodLog.clientId` nullable + `@@unique([userId, clientId])` e `clientId` opcional no `POST /food-logs`, com o mesmo comportamento do `WorkoutSet` (reenvio devolve o Registro já gravado, `P2002` engolido só com `clientId`), migration aplicada no Neon antes do deploy do backend; a web não muda. Falha de um item vira ⚠ com reenvio pelo mesmo `clientId`. `quantityFormat.ts` vai pro Kit com os testes da web traduzidos. Se estourar a sessão, divide em busca+carrinho e edição do Registro salvo. Termina com o checklist da Fase D no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase D (Dieta)](26-fatiamento-fase-d.md).
