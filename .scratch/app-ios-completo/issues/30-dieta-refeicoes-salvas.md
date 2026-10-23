# Dieta: Refeições salvas

Type: task
Status: open
Blocked by: 29

## Question

Portar `SavedMealsListPage.tsx`/`SavedMealEditPage.tsx`/`useSavedMealEditor.ts`: lista, editor (QuantitySheet só como entrada, confirma em gramas, como a web) e aplicar a uma Refeição do dia (`POST /saved-meals/:id/apply`). **Backend**: `clientId` opcional no `apply`, que, com o `FoodLog.clientId` da [Dieta: adicionar Registros](28-dieta-adicionar-registros.md), torna o reenvio idempotente (um reenvio devolve os Registros já gravados em vez de duplicar a Refeição salva inteira); migration, se precisar, no Neon antes do backend. Lógica pura do editor (sujo/assinatura, se a web tiver) vai pro Kit com teste. Termina com o checklist da Fase D no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase D (Dieta)](26-fatiamento-fase-d.md).
