# Dieta: histórico 7/14 dias

Type: task
Status: resolved
Blocked by: 30

## Question

Portar o `DietHistoryPage.tsx` como sub-página da Dieta: segmentado 7/14 (`GET /food-logs/history`), barras com a altura relativa ao maior valor do período incluindo a meta, linha tracejada da meta, cor por dia (selecionado / acima da meta / dentro), lista "Dias" com a seleção sincronizada com o gráfico. Primeiro conferir que o **Swift Charts** compila e roda com o xtool; se não, barras desenhadas à mão como a web (que usa `div`s). As regras de escala e de cor vão pro Kit com teste. Termina com o checklist da Fase D no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase D (Dieta)](26-fatiamento-fase-d.md).

## Answer

**Feito e validado no iPhone (2026-10-24).** As linhas 31–36 do checklist da Fase D foram conferidas, e a galeria app | web foi aprovada pelo usuário.

- **Swift Charts**: está no SDK do xtool (`Charts.framework`) e a interface não declara nenhuma macro, então compila. Não foi testado rodando no aparelho, e não foi usado: as barras são desenhadas à mão, como o Histórico do Treino do app e como a web faz com `div`s. Fica registrado pra uma tela futura que precise de eixo ou linha de verdade.
- **Kit** (`DietHistory.swift`, 7 testes, 328 no total): `DailyHistoryPoint`; a escala (maior dia ou a meta, nunca abaixo de 1); a barra vazia com 2%; a cor por dia (selecionado / acima da meta, estritamente / dentro); as datas em toda barra no período de 7 dias e em barras alternadas no de 14; a seleção que sobrevive enquanto o dia estiver no período; a data longa e a linha de macros. A fixture `food-logs-history.json` é real da API local e está zerada, porque o banco local não tem Registros recentes.
- **App**: `DietHistoryStore` (cache de leitura por período; uma resposta atrasada do outro período não entra) e `DietHistoryView` (leitura do dia, barras com a linha tracejada da meta, "Dias" com a seleção compartilhada), ligados no shell e em `portedPages`. Strings `diet.history.*` em PT/EN.
- **Dynamic Type**: as datas sob as barras tinham `.fixedSize()` e, com a letra grande, as sete juntas ficavam mais largas que a tela e arrastavam a página inteira, o cabeçalho de área incluso. Agora encolhem dentro da barra (`minimumScaleFactor`). Subtítulo e 7/14 empilham se não couberem (`ViewThatFits`), e a linha de macros usa espaço que não quebra entre a letra e o valor.
- **Desvios aceitos**:
  - O título "Histórico" da web ficou de fora, porque o cabeçalho de área já o mostra.
  - O seletor 7/14 é o segmentado nativo.
  - Não há animação de entrada das barras (ver "Animações de entrada no app" no mapa).
