# Uso real da Fase D

Type: task
Status: open
Blocked by: 31

## Question

O usuário registra a dieta pelo app por alguns dias com a Fase D inteira (spec §3: toda fase termina com uso real). O agente registra o que quebrou ou incomodou, corrige ou cria tarefa pra cada item, e confere as linhas do checklist que dependem de uso (scanner em produtos reais, reenvio pelo ⚠, dia em fuso local perto da meia-noite). Fecha quando cada item estiver corrigido ou aceito pelo usuário, e a paridade web ↔ app da área Dieta estiver em vigor.

Herdado de [Dieta: cadastro manual e scanner](29-dieta-manual-scanner.md): linhas 19 (cadastro em escuro/EN), 21 (código desconhecido → cadastro já com o código → o próximo scan acha o alimento; **só depois do deploy do backend** com o novo `findByBarcode`) e 22 (Dynamic Type), e o botão de voltar do cadastro dizendo o nome da refeição.

Depende do deploy do backend com o `clientId` no `POST /saved-meals/:id/apply` ([Dieta: Refeições salvas](30-dieta-refeicoes-salvas.md)) pra conferir a linha 29 do checklist.
