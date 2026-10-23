# Sessão: treino livre e atualizar rotina ao finalizar

Type: task
Status: open
Blocked by: 19

## Question

Completar a Sessão: (1) **Treino livre** (`POST /workouts` sem `templateId`), exceção registrada à paridade, só no app; decidir com o usuário onde fica o botão de entrada na aba Treino. (2) **Atualizar a rotina ao finalizar**: o prompt da web (`WorkoutSession.tsx`, `session.syncTemplate*`) quando o Treino veio de uma Rotina e mudou em relação a ela, mandando `syncTemplate` no `PATCH .../finish`. A regra de "mudou em relação à rotina" vai pro Kit com teste, se a web tiver uma. Termina com o checklist da Fase T no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase T (Treino completo)](18-fatiamento-fase-t.md).
