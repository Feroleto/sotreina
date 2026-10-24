# Entrar e Criar conta no visual do design

Type: task
Status: resolved
Blocked by:

## Question

Trocar o `LoginView` (Form com segmented) pela tela do design `Login Transicao.dc.html`, conforme `.plans/login-app-ios-spec.md` §3.1 e §3.2: **Entrar** (logo Pulso no topo, conteúdo ancorado embaixo, campos de 54pt com olho na senha, "Esqueci a senha", botão `bg-acc` com spinner, "Criar conta", rodapé Privacidade/Suporte) e **Criar conta** como tela empurrada (nome, email, senha `.newPassword`, **sem confirmar senha**, frase de privacidade). `ForgotPasswordView` restilizado no mesmo visual. Tema **segue o sistema**: o design é escuro e a versão clara sai dos tokens Monolito. O lugar do divisor "ou" e do botão Apple fica reservado e **não renderiza**. O campo de servidor sai da tela e vai para uma sheet aberta por **toque longo na logo**. O aviso de conta só-Strava aparece só depois de um 401. O banner de expiração (`ExpiryNotice`) e as mensagens de `SessionStore.expire()` têm que caber no layout novo.

O backend não muda: o cadastro continua com `register` + `token` até a [Verificação de email: backend e web](03-verificacao-email-backend-web.md) trazer o `register-token`. O `EntryForm` do Kit perde a checagem de confirmação no caminho do app, com o teste ajustado. Strings em PT/EN no `.strings`.

**Primeira tarefa do mapa**: criar o worktree (`git worktree add ../strava_dashboard-login -b login`), ver as Notes.

Termina com o app instalado no iPhone e o usuário conferindo claro, escuro, EN, Dynamic Type grande, teclado aberto (botão visível), senha errada e 409. Ao entrar, o app vai direto ao Hoje como hoje: a animação é a [Transição "bola percorre o pulso"](02-transicao-pulso.md).

## Progresso (2026-10-23, worktree `../strava_dashboard-login`, branch `login`, sem commit)

- Worktree criado a partir do `main` (`5a32247`).
- **Kit**: `EntryForm.registerProblem(email:password:)` sem confirmação; `RegisterProblem.passwordMismatch` removido; teste ajustado (281 testes passando).
- **App** (`Features/Auth/`):
  - `EntryComponents.swift`: `EntryScroll` (altura mínima da tela, conteúdo ancorado embaixo por `Spacer`, rola com o teclado e leva o botão junto ao focar), `EntryHeading`, `entryFieldBox()` (54pt, raio 14, `card` + `border`, 17pt), `EntryPasswordField` (olho, devolve o foco na troca), `EntryButtonStyle` (54pt, raio 14, 17/600, `press`), `EntryError`, `EntryLegalLinks` (o mesmo par do fim do Perfil), `entryPushedScreen()`.
  - `LoginView.swift`: `NavigationStack` com rotas `register`/`forgot`, email compartilhado com o cadastro. Entrar segue o design. Depois de um 401, mostra o aviso só-Strava com o link da web. O slot do Apple fica só como comentário.
  - `RegisterView.swift` (novo, push): nome, email e senha `.newPassword`, mais a frase de privacidade com link em markdown na string.
  - `ForgotPasswordView.swift`: restilizado.
  - `ServerSheet.swift` (novo): toque longo de 0,8 s na logo. URL validada (http/https com host), "Usar produção", Salvar grava `APIClient.storedBaseURL`.
- **Strings PT/EN**: as chaves novas entraram e `tabLogin`/`tabRegister`/`confirmPasswordPlaceholder`/`passwordMismatch` saíram.
- Build ok e instalado no iPhone. **Falta a conferência do usuário**: claro, escuro, EN, Dynamic Type grande, teclado aberto, senha errada, 409 no cadastro, esqueci a senha e a sheet de servidor.
- Fora do ticket: `SessionStore.expire()` não mostra mensagem nenhuma no login hoje, então não havia o que encaixar. O banner de expiração continua no `safeAreaInset` do `RootView`.

## Answer

Feito e conferido pelo usuário no iPhone (2026-10-23), no worktree `../strava_dashboard-login` (branch `login`, sem commit). O que entrou está no Progresso acima. Depois da primeira conferência:

- **O olho trocava `SecureField` por `TextField`.** Isso derrubava o foco (o teclado fechava e reabria) e o olho pulava. Virou um `UITextField` único (`PasswordTextField` em `EntryComponents.swift`), que alterna `isSecureTextEntry` no lugar. Detalhes:
  - Reaplica a fonte depois de cada troca.
  - Reinsere o texto ao voltar ao modo seguro durante a edição. Sem isso, o iOS apaga tudo na próxima tecla.
  - O foco da senha é um `Bool` próprio (`passwordFocused`), fora do `FocusState`, que não enxerga UIKit. Email e nome seguem no `FocusState`.
  - O `sizeThatFits` devolve a altura de uma linha. Sem ele, o campo comia o `Spacer` da tela.
- **Aceito pelo usuário**: ao tocar no olho, a barra de senhas acima do teclado pisca por um instante. É o iOS trocando o modo de teclado seguro, e não há opção do UIKit que evite. O truque do campo sempre seguro com texto sobreposto foi oferecido e recusado (o cursor sumiria com a senha visível).

Ficou para o próximo ticket: ao entrar, o app ainda vai direto ao Hoje, porque a animação é a [Transição "bola percorre o pulso"](02-transicao-pulso.md).
