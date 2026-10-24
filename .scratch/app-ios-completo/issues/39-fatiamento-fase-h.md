# Fatiamento da Fase H (Hoje)

Type: grilling
Status: resolved
Blocked by:

## Question

Em que tickets `task` de construção a Fase H se divide, em que ordem e com que bloqueios? Em especial: o Hoje é construído aos poucos (cada área entra no Hoje junto da fase dela) ou só depois das três áreas prontas, como diz a spec? Escopo (spec §3, Fase H): status do dia por área, barras dos últimos 7 dias, "Por área" contra as metas (lápis abre as metas semanais), feed misto e a versão de uma área só (`TodaySingleArea`), com `todayStatus.ts` portado pro Kit com os testes.

## Answer

**Decidido com o usuário (2026-10-24).** As três áreas já estão no `main`, então a dúvida "aos poucos ou depois" acabou: o Hoje é feito agora, de uma vez, como a spec pedia. A Fase H vira três tarefas `task`, **em fila**, cada uma bloqueada pela anterior:

1. [Hoje: várias áreas](40-hoje-varias-areas.md): `todayStatus.ts` vai pro Kit e a tela de 2–3 áreas é montada.
2. [Hoje: uma área só](41-hoje-uma-area.md): o equivalente do `TodaySingleArea`.
3. [Uso real da Fase H](42-uso-real-fase-h.md).

**Regras da fase:**
- **Não espera os três Uso real** (Treino, Dieta e Corrida). O Hoje só lê os mesmos endpoints, então recebe de graça qualquer correção que saia deles.
- **Sem store própria**: o Hoje lê as stores que já vivem no shell (`RunStore`, `GymHistoryStore`, `DietStore`, `DietHistoryStore`, `WorkoutStore`, `ProfileStore`) e chama o `load` de cada uma. Uma `TodayStore` com fetch próprio duplicaria requisições e cache, e o Hoje poderia mostrar um número diferente da aba da área.
- **Toques trocam de aba, como na web**: tocar num status, numa linha de "Por área" ou num item do feed leva pra página da área (Corrida → Atividades, Treino → Visão geral, Dieta → Visão geral). Nunca abre o detalhe direto.
- **O lápis reaproveita as telas do Perfil**: empilha as metas semanais no stack do Hoje. Na versão de uma área só, a Dieta abre a Meta diária, como a engrenagem da Dieta já faz.
- **O app passa a abrir no Hoje**: o padrão do `selectedTab` muda de Treino pra Hoje, e a última aba usada continua lembrada. Treino aberto continua tomando a tela.
- **Sem animação de entrada**, como nas outras áreas. A pendência segue em "Not yet specified" no mapa.
- **Nenhuma fatia mexe no backend.**
- **Validação por tarefa**, com as linhas da Fase H no checklist do README.
