# Mapa: entrada do app iOS (login, conta e Strava pela Corrida)

## Destination

A parte "Apple ID grátis" de `.plans/login-app-ios-spec.md` **implementada e validada no iPhone com uso real**:

- a tela de Entrar e a de Criar conta do design, com a transição "bola percorre o pulso";
- a verificação de email por código (app e web);
- a exclusão de conta no app;
- a conexão Strava pela Corrida, com primeiro sync e desconexão.

Tudo em produção.

## Notes

- **Este mapa carrega a execução** (decidido com o usuário em 2026-10-23, mesmo modelo do mapa `app-ios-completo`): os tickets `task` constroem. Um ticket se resolve com o código pronto, compilando, testado (Kit/servidor) e conferido no iPhone, e o `## Answer` diz o que foi feito e o que ficou pendente.
- **Fonte das decisões**: `.plans/login-app-ios-spec.md`. O que está lá já foi decidido na entrevista de 2026-10-23 e não se reabre sem o usuário. Design: Claude Design, projeto `09e94a27-94a5-4ba4-a019-74685a73330f`, arquivo `Login Transicao.dc.html` (ler pelo `DesignSync get_file`).
- **Worktree próprio**: `../strava_dashboard-login`, branch `login`. Quem cria é o primeiro ticket ([Entrar e Criar conta no visual do design](issues/01-entrar-criar-conta.md)). Valem as regras do mapa `app-ios-completo` (`.scratch/app-ios-completo/map.md`, Notes):
  - O tracker é este `.scratch/` no working tree principal, editado pelo caminho absoluto `/home/ferol/projetos/strava_dashboard/.scratch/login-app-ios/…`.
  - Antes de cada `deploy.sh`, fazer merge de `main` em `login` (e a sessão do main traz `login` antes do dela).
  - O iPhone é de uma sessão por vez: antes de instalar, conferir `ps aux | grep "xtool dev run"`.
  - O usuário commita, e o agente não faz commit.
- **Skills**:
  - `tdd` para a lógica pura no Kit (`EntryProgress`) e nos services do backend.
  - `run-sotreina` para conferir a web.
  - `grilling` + `domain-modeling` se surgir decisão nova.
- **Preferências permanentes**:
  - Tudo que não desenha tela vai para o `SoTreinaKit`.
  - Antes de adotar qualquer framework da Apple, conferir se ele depende de ferramenta exclusiva do Xcode.
  - Migration no Neon antes do deploy do backend.
  - Contas de teste descartáveis, nunca a conta real do usuário, para cadastro e exclusão.
- **Muda o mapa `app-ios-completo`**: lá, "Login/conexão/desconexão Strava" estava fora de escopo. A conexão e a desconexão Strava passam a viver aqui, só pela Corrida e pelo Perfil, nunca na entrada.
- **Tracker**: markdown local. Os tickets ficam em `issues/NN-<slug>.md`, com `Type:`, `Status:` (`open`/`claimed`/`resolved`) e `Blocked by:`.

## Decisions so far

<!-- uma linha por ticket resolvido -->
- [Entrar e Criar conta no visual do design](issues/01-entrar-criar-conta.md): Entrar e Criar conta (push, sem confirmar senha) no visual do design, servidor no toque longo da logo e senha num `UITextField` único. A piscada da barra de senhas ao tocar no olho foi aceita
- [Transição "bola percorre o pulso"](issues/02-transicao-pulso.md): `EntryPulse` no Kit e overlay no `RootView` sobre o destino; espera o primeiro load do shell (timeout de 10 s), Reduzir movimento vira fade; expansão mantida depois de discutida com o usuário
- [Verificação de email: backend e web](issues/03-verificacao-email-backend-web.md): verificação por código (backend e web) e `register-token` prontos. O limite por conta é contado nas linhas da tabela, e o 429 devolve `retryAfterSeconds`. Migration pendente no Neon.

## Not yet specified

- **Ajustes visuais que o uso real trouxer** na transição (mostarda sobre o tema claro, duração percebida por quem entra e sai com frequência). Hoje vale o que a spec decidiu. Só vira ticket se o [Uso real da entrada nova](issues/10-uso-real.md) ou a [Transição "bola percorre o pulso"](issues/02-transicao-pulso.md) mostrarem um incômodo concreto.

## Out of scope

- **Fase Apple** (Sign in with Apple, vínculo por email verificado, relay do "Ocultar meu e-mail", revogação na exclusão): exige o Developer Program pago, e o usuário decidiu fazer só o possível com Apple ID grátis. Está planejada na spec §7 e volta como esforço novo quando a conta paga existir.
- **Submissão à App Store** (checklist da spec §8, incluindo a pesquisa sobre o xtool gerar um `.ipa` de distribuição): também depende da conta paga. Os itens que já cabem aqui (exclusão de conta, link de privacidade, campo de servidor escondido) estão nos tickets.
- Login Strava no app, Apple na web, "definir senha" no app, troca de email ou senha, exclusão de conta pela web, carência antes de excluir, verificação bloqueante, animação na abertura a frio (spec §9).
