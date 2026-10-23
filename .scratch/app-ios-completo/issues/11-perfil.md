# Perfil do app

Type: task
Status: resolved
Blocked by: 05, 07, 09, 14, 15

## Question

Montar o Perfil (spec §2 e §3, Fase S): nome, áreas (a última ligada fica travada, como na web), metas semanais e diária de dieta, tema, idioma, unidades e sair. Strava e "adicionar senha" ficam na web, com um link pra lá.

## Answer

**Feito e validado no iPhone (2026-10-23).** O usuário aprovou as linhas 07–14 da Fase S. A troca pra mi foi testada pelo usuário depois que o backend de unidades entrou em produção.

- **Kit** (`Profile.swift`, 8 testes em `ProfileTests`, 115 no total):
  - `MeSettings` (`GET`/`PATCH /users/me`, ignora área desconhecida) e `MeSettingsPatch` (só manda os campos não nulos e se aplica localmente pro estado otimista).
  - `Me.applying(_:)` e `Me.email` (novo, `nil` em conta só-Strava).
  - `ProfileRules`, portado de ProfilePage/EditNamePage/WeeklyGoalsPage/GoalPage: nome (trim, 60), iniciais, a última área fica travada, faixas das metas, meta de corrida em mi que volta intacta se ninguém mexer, % das calorias e a checagem dos macros (tolerância de 3%).
- **App** (`Features/Profile/`):
  - `ProfileStore`: lê `/users/me` pelo cache. Áreas e unidades salvam otimistas, com rollback e erro na seção. Nome e metas esperam o servidor. O que `/auth/me` também tem volta pro `Me` da sessão por `SessionStore.setMe`, então as abas acompanham na hora.
  - `ProfileView`: foto do Strava (`AsyncImage`) ou iniciais, chaves de área, metas das áreas ligadas, tema/idioma (PT/EN, como a web)/unidades da área ligada, Strava com "Gerenciar na web", Sair, links de privacidade e suporte. O catálogo do design system ficou só em debug.
  - `EditNameView`, `WeeklyGoalsView`, `DietGoalView`.
  - `SettingsView` apagado. `ThemePicker` e os rótulos do `ValueStepper` agora passam pelo L10n.
  - Strings PT/EN geradas do JSON da web, mais 2 só do app: `nav.profile.manageOnWeb` e `nav.profile.goalsLoadFailed`.
- **Padrões que a validação fixou** (valem pras próximas telas em lista):
  - Lista plana = `.listRowBackground(Color.pageBg)` em toda linha.
  - Título de seção como **linha** (`.listRowSeparator(.hidden)`), não `Section { } header:`: numa lista `.plain` o header fica grudado no topo ao rolar, o que a web não faz. O mesmo vale pro footer.
  - Linha com ícone ou controle à esquerda leva `.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }`, senão a linha fina começa recuada.
- **Desvios aceitos (nativos)**: o botão das chaves é branco; os campos dos Dados pessoais ficam em cartão, como no login; título e voltar na barra de navegação; seletores segmentados não crescem com o Dynamic Type.
- **Observação**: o modo de validação sobrepõe o tema sem gravar, então o seletor mostra o tema salvo ("Auto"), não o forçado.
