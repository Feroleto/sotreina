# Dieta: o dia e o modo de edição das Refeições

Type: task
Status: open
Blocked by: 24

## Question

Portar a Overview da Dieta (`DietOverviewPage.tsx`): kcal em Geist Mono com a barra de progresso (vira `--neg` acima da meta, mesma comparação estrita da web), faixa de macros com opacidades 1/.7/.45 e a lista de Refeições na ordem do servidor (`GET /meals`, `GET /food-logs?date=` e `/summary`), somando os Registros por `mealId` no cliente. Modo de edição: reordenar (`PUT /meals/order` com a lista inteira), renomear pelo vocabulário fechado (`MealTypePicker`), apagar com a confirmação que mostra o `logCount` e avisa que some de todos os dias (lixeira desabilitada na última Refeição). A engrenagem abre a Meta diária que já existe no Perfil do app. Cache JSON como nas rotinas ([Cache JSON de leitura](08-cache-json.md)). Tocar numa Refeição ainda não adiciona nada (fica pra [Dieta: adicionar Registros](28-dieta-adicionar-registros.md)). "Dieta" entra em `AreaScreen.portedPages`. Ainda sem mudança no backend. Termina com o checklist da Fase D no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase D (Dieta)](26-fatiamento-fase-d.md).
