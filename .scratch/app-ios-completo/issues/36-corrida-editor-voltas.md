# Corrida: editor de voltas

Type: task
Status: open
Blocked by: 35

## Question

Portar o editor de voltas (`features/activity/lap-editor/`) a partir do detalhe: `GET /activities/:id/streams`, lista com `.onMove`, tamanho por distância (metros) ou tempo (segundos), `+ Volta`/`+ Repetições`, barra de cobertura ao vivo, Salvar (`PUT /activities/:id/laps`) só com cobertura completa, confirmação ao fechar com alterações. **Fica em metros e segundos, sem mi**, igual à web. `lapBoundaryMath.ts` vai pro Kit com os testes da web traduzidos, inclusive a âncora de distância e a tolerância de 60 s. Se estourar a sessão, divide em lista+cobertura e Salvar. Termina com o checklist da Fase C no `ios/README.md` (linhas desta tarefa, coluna App preenchida, galeria app | web aprovada pelo usuário) e o app instalado no iPhone. Regras da fase em [Fatiamento da Fase C (Corrida)](33-fatiamento-fase-c.md).
