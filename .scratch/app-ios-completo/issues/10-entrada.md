# Entrada: cadastro, esqueci a senha e escolha de áreas

Type: task
Status: resolved
Blocked by: 06, 09, 14, 15

## Question

Completar a entrada do app (spec §3, Fase S): cadastro (`POST /auth/register` seguido de `POST /auth/token` com as mesmas credenciais pra obter o Bearer), esqueci a senha (`POST /auth/forgot-password`, o link do email abre a web), e a tela "O que você quer acompanhar?" quando `enabledAreas` vier vazio (`PATCH /users/me`). Conta só-Strava (sem senha) não entra no app: a tela de login explica isso.

## Answer

**Feito e conferido no iPhone (2026-10-22)**: o usuário criou a conta descartável `teste@gmail.com` em produção e "a princípio tudo funcionando".

- **Kit** (`Entry.swift`, 4 testes novos em `EntryTests`, 100 no total):
  - `EntryForm.registerProblem` repete as checagens da web antes de enviar: e-mail, senha de no mínimo 8 e confirmação igual.
  - `EntryForm.canonicalAreas` põe as áreas escolhidas na ordem do servidor.
  - `RegisterRequest` apara o e-mail e omite o nome vazio. `ForgotPasswordRequest`. `EnabledAreasPatch`.
- **App** (`Features/Auth/`; o `LoginView` saiu da raiz e veio pra cá):
  - **`LoginView`**: abas **Entrar | Criar conta**. No cadastro, Nome (opcional), Confirmar senha e `textContentType(.newPassword)`. Os erros vêm da web: credenciais erradas limpam a senha; um 409 mantém os campos e mostra "Este e-mail já está cadastrado.". Abaixo de "Esqueci a senha" fica o aviso de conta só-Strava, com link pra web.
  - **`ForgotPasswordView`** (push): mostra sempre a mesma mensagem de sucesso, mesmo com erro de rede. É o anti-enumeração da web. O link do e-mail abre a web.
  - **`AreaPickerView`**: é a 21a da web, com o logo, linhas com ícone das abas e o check mostarda, contador com plural e Continuar. O `RootView` mostra essa tela enquanto `me.enabledAreas` estiver vazio, antes do `AppShell`.
  - **`SessionStore`**: `register` faz `POST /auth/register` e depois o `login` de sempre (`POST /auth/token`), sem mudar o backend. Também ganhou `requestPasswordReset`, e `saveAreas`, que faz `PATCH /users/me` e copia o `enabledAreas` da resposta (um snapshot, não o `Me`) pro `Me` da sessão. O **Perfil deve reusar o `saveAreas`** nas chaves de área.
  - **`APIClient`**: `httpShouldHandleCookies = false`, porque o `register` devolve o cookie de sessão da web, e o client só usa Bearer. Ganhou também `postIgnoringBody`.
  - **`SoTreinaDesign/Logo.swift`**: o `LogoMark` "Pulso", com a mesma geometria da web.
  - `AppTab.symbol` deixou de ser `private`, pra a escolha de áreas usar os ícones das abas.
- **Strings**: as chaves `auth.login.*` e `onboarding.areas.*` foram adicionadas aos dois `.lproj`, e `onboarding.areas.count %lld` ao `.stringsdict`.
- **Observado**: o `add_enabled_areas` já está em produção. O backend com ele está no `main` publicado, e as contas existentes não caem na escolha de áreas. A nota "pendente" no `CLAUDE.md` estava desatualizada.
- **Pendente**: apagar a conta `teste@gmail.com` do Neon. O agente não tem a URL de produção, então o usuário roda o `DELETE`.
