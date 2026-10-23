# Dieta: o dia e o modo de edição das Refeições

Type: task
Status: resolved
Blocked by: 24

## Question

Portar a Overview da Dieta (`DietOverviewPage.tsx`): kcal em Geist Mono com a barra de progresso (vira `--neg` acima da meta, mesma comparação estrita da web), faixa de macros com opacidades 1/.7/.45 e a lista de Refeições na ordem do servidor (`GET /meals`, `GET /food-logs?date=` e `/summary`), somando os Registros por `mealId` no cliente. Modo de edição: reordenar (`PUT /meals/order` com a lista inteira), renomear pelo vocabulário fechado (`MealTypePicker`), apagar com a confirmação que mostra o `logCount` e avisa que some de todos os dias (lixeira desabilitada na última Refeição). A engrenagem abre a Meta diária que já existe no Perfil do app. Cache JSON como nas rotinas ([Cache JSON de leitura](08-cache-json.md)). Tocar numa Refeição ainda não adiciona nada (fica pra [Dieta: adicionar Registros](28-dieta-adicionar-registros.md)). "Dieta" entra em `AreaScreen.portedPages`. Ainda sem mudança no backend. Termina com o checklist da Fase D no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase D (Dieta)](26-fatiamento-fase-d.md).

## Answer

**Feito e validado no iPhone (2026-10-23).** O usuário conferiu o funcional e a galeria da Fase D, linhas 01–07.

- **Kit** (`Diet.swift`, 234 testes passando, 17 novos; fixtures `meals`/`food-logs`/`food-logs-summary` da API local):
  - Modelos `Meal`, `FoodLogItem`, `FoodListItem`, `DailySummary`. `MealType` é `RawRepresentable`, não enum: um nome novo do servidor decodifica, e o reorder (que manda todos os ids) continua possível.
  - `DietDay`: kcal contra a meta com a regra estrita `> meta` da web, "faltam" arredondado, "acima" arredondado pra cima, porcentagem, macros com a barra limitada a 100% e opacidades 1/.7/.45, kcal e contagem por Refeição somadas no cliente (arredonda uma vez, depois da soma). Sem `/users/me` ainda, usa os padrões 2000/150/250/65.
  - `MealList`: `moving` (lista inteira de ids pro `PUT /meals/order`), `canDelete` (nunca a última), `canAdd` (teto de 12 do servidor).
  - `DietFormat`: cabeçalho do dia, `?date=` no fuso local, milhar por idioma ("2.000"/"2,000").
- **App**:
  - `DietStore`: Refeições, Registros e resumo de hoje pelo cache de leitura (um dia novo começa vazio, nunca mostra o de ontem); recarrega ao aparecer e ao voltar pro primeiro plano. Toda mutação grava a lista devolvida no cache; reordenar é otimista com rollback; excluir recarrega o dia.
  - `DietOverviewView`: data + engrenagem, kcal em Geist Mono 64, linha da meta (vira `--neg` acima), faixa de macros, Refeições com contagem e kcal. Modo de edição: ↑ ↓, renomear (sheet com o vocabulário fechado, do tamanho do conteúdo), excluir (diálogo nativo com o `logCount` e "de todos os dias"), "Adicionar refeição" tracejado. Atribuição TACO/OFF no fim.
  - Um único `ProfileStore` no `AppShell`, passado ao Perfil e à Dieta: a engrenagem abre a mesma `DietGoalView`, e salvar atualiza a Visão geral sem refetch.
  - `APIClient.put`; "Dieta" em `AreaScreen.portedPages` (a aba abre na Visão geral; Histórico segue "Em breve"); strings PT/EN com plurais.
- **Desvios aceitos**: confirmação de exclusão no diálogo nativo (a web confirma em linha); "0 itens" no plural (a web escreve "0 item", mesmo caso do Treino). Tocar numa Refeição ainda não faz nada, como previsto.
- Corrigido na validação: o "/ 150g" das macros em mono, como na web; o sheet do seletor com ~100 pt sobrando embaixo; "Carboidrato" quebrando no meio da palavra em Dynamic Type grande.
- A lixeira desabilitada da última Refeição ficou só no teste do Kit, pra não apagar Refeições reais.
- Nenhuma mudança de backend.
