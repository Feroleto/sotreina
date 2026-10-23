# Formato da validação visual por fase

Type: grilling
Status: resolved
Blocked by:

## Question

Com a captura pelo cabo funcionando (`ios/scripts/screenshot.sh`, ver "Teste: screenshot do iPhone pelo cabo"), como cada fase é conferida contra a web mobile? Decidir: quais telas e estados entram no checklist de cada fase (claro/escuro, PT/EN, vazio/carregando/com dado); como os pares são montados (screenshot do app ao lado do `run-sotreina` na mesma largura lógica de 393 pt, mesmo usuário e mesmos dados); quem navega no iPhone entre as capturas (o usuário, sob comando do agente); onde os pares ficam (fora do git); e o que conta como "paridade aprovada" para fechar a fase (spec §8).

## Answer

Decidido com o usuário em 2026-10-22 (todas as recomendações aceitas):

1. **O par compara estrutura, não dados**: layout, hierarquia, cores, tipografia e estados. O app roda contra produção e a web (`run-sotreina`) contra o banco local; ninguém precisa dos mesmos números. Conferir valor é papel dos testes do Kit portados da web.
2. **Mesma largura e escala**: o driver do `run-sotreina` ganha `--iphone` (viewport 393×852, `deviceScaleFactor: 3`), saindo em 1179×2556 como o screenshot do iPhone 15.
3. **Matriz por tela**: claro e escuro em PT, com dado; EN uma vez, no claro; vazio só onde a web tem estado vazio desenhado; estados transitórios (⚠, descanso) só na fase que os introduz; carregando fica de fora (o cache mostra na hora). **Dynamic Type**: uma captura por tela, por fase, só no app, no último degrau da régua normal (sem os tamanhos de acessibilidade); quebra ali é bug.
4. ~~**O usuário navega no iPhone**~~ **Substituída em 2026-10-22 por [Modo de validação por variáveis de ambiente](16-modo-validacao-env.md): o agente navega** (`launch.sh` com a coluna App do checklist → `screenshot.sh`). O usuário só desbloqueia o iPhone, ajusta o Dynamic Type e leva o app às linhas `manual`. Texto original: **O usuário navega no iPhone** seguindo a lista numerada do agente e avisa; o agente captura com `ios/scripts/screenshot.sh`. A alternativa de o app abrir sozinho na tela vira o ticket [Teste: app abre numa tela via `dvt launch --env`](13-teste-launch-env.md).
5. **Capturas em `ios/validation/<fase>/`**, fora do git (`.gitignore`).
6. **Classes de diferença**: nativa e intencional (livre, sem anotar: navegação, sheets, gestos, cromo de lista, Dynamic Type); desvio aceito (registrado com motivo no checklist); bug (corrigido antes de fechar). O agente faz a triagem; quem aprova é o usuário.
7. **Galeria `ios/validation/<fase>/index.html`** por fase, gerada a partir do checklist: uma linha por par (app | web, legenda "tela · estado"), aberta no navegador do Windows.
8. **O checklist da fase no `ios/README.md` é a lista de capturas**: cada linha = tela, estado, equivalente web (PageId + passos do driver) e resultado (✓ / desvio aceito + motivo / bug). O agente escreve as linhas quando o ticket que constrói a tela começa.
9. **Superfícies sem web** (Live Activity, widgets, notificações, sheets nativos sem par): captura só do app, comparada com a spec e o design system, aprovada pelo usuário. Se o cabo não capturar a tela bloqueada, a linha vira "usuário confere e descreve".
10. **Validação por ticket**: um ticket `task` que constrói tela só fecha com os pares dela aprovados; no fim da fase só se recaptura o que mudou depois da aprovação.

As ferramentas (itens 2, 5 e 7) viraram o ticket [Ferramentas da validação visual](14-ferramentas-validacao.md).
