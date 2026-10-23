# Navegação: abas, header de área e sessão minimizável

Type: task
Status: resolved
Blocked by: 06, 14

## Question

Montar a casca de navegação (spec §3, Fase S): `TabView` com Hoje, as áreas ativas e Perfil (mesma regra de `mobileTabsFor` da web, portada pro Kit com teste); header de área com título grande e abas de texto das sub-páginas; aviso "Em breve no app" com link pra web nas áreas ainda não portadas; e a sessão de treino como tela cheia minimizável, com a barra "Treino em andamento" acima da tab bar.

## Answer

**Feito e validado no iPhone (2026-10-22).** O usuário conferiu as 6 telas da Fase S na mão. A sessão que começou o ticket caiu no meio, e esta só conferiu, compilou e instalou o que ela tinha escrito, sem mexer no código.

- **Kit**: `Navigation.swift`. `Area`, `AppTab.tabs(for:)` porta o `mobileTabsFor` da web (com uma área só, a aba dela some), `pages`/`landingPage` por aba, `AppPage` sem a Análise (que está desligada na web), e rótulos PT/EN. `Me.enabledAreas` ignora valores desconhecidos. Testes em `NavigationTests`.
- **App**:
  - **`App/AppShell.swift`**: `TabView`. A aba escolhida fica em `@SceneStorage` e cai na primeira se a área tiver sido desligada. É dono do `WorkoutStore`, recarrega ao voltar pro primeiro plano e guarda o link pendente da Live Activity.
  - **`App/AreaScreen.swift`**: header de área (título + abas de texto com sublinhado mostarda) dentro de um `NavigationStack` por aba, mais o `ComingSoonView` com link pra web. `AreaScreen.portedPages` diz quais sub-páginas existem; uma aba abre na página de entrada da web só se ela já foi portada, senão na primeira que foi. **Hoje só `gymRoutines` existe**: cada fase acrescenta as suas ali.
  - **Sessão minimizável**: `fullScreenCover` com a sessão ou o resumo. `WorkoutStore.sessionMinimized` é ligado pelo chevron ↓ da sessão e volta a `false` quando o treino muda ou quando o "✓" da Live Activity é tocado. `ActiveWorkoutBar` (nome + cronômetro) fica no `safeAreaInset` de toda aba.
  - **Perfil**: por enquanto é o `SettingsView(asTab: true)`, até o ticket do Perfil do app.

**Pendente:**
- **Strings das telas em PT/EN**: o shell ainda usa ternários `pt ?` e os rótulos do Kit, e o alerta "Não deu certo" está fixo em PT.
- **Teste: app abre numa tela via `dvt launch --env`**: agora desbloqueado.
