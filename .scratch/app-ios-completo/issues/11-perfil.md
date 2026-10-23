# Perfil do app

Type: task
Status: claimed
Blocked by: 05, 07, 09, 14, 15

## Question

Montar o Perfil (spec §2 e §3, Fase S): nome, áreas (a última ligada fica travada, como na web), metas semanais e diária de dieta, tema, idioma, unidades e sair. Strava e "adicionar senha" ficam na web, com um link pra lá.

## Progresso (2026-10-23, falta a validação no iPhone)

- **Kit** (`Profile.swift`, 8 testes em `ProfileTests`, 115 no total passando):
  - `MeSettings` (`GET`/`PATCH /users/me`, ignora área desconhecida) e `MeSettingsPatch` (só manda os campos não nulos e se aplica localmente pro estado otimista).
  - `Me.applying(_:)` e `Me.email` (novo, `nil` em conta só-Strava).
  - `ProfileRules`, portado de ProfilePage/EditNamePage/WeeklyGoalsPage/GoalPage: nome (trim, 60), iniciais, a última área fica travada, faixas das metas, meta de corrida em mi que volta intacta se ninguém mexer, % das calorias e a checagem dos macros (tolerância de 3%).
- **App** (`Features/Profile/`):
  - `ProfileStore`: carrega `/users/me` pelo cache. Áreas e unidades salvam otimistas, com rollback e erro na seção. Nome e metas esperam o servidor. O que `/auth/me` também tem volta pro `Me` da sessão por `SessionStore.setMe`, então as abas acompanham na hora.
  - `ProfileView`: foto do Strava ou iniciais, chaves de área, metas das áreas ligadas, tema/idioma (PT/EN, como a web)/unidades da área ligada, Strava com "Gerenciar na web", Sair, links de privacidade e suporte. O catálogo do design system ficou só em debug.
  - `EditNameView`, `WeeklyGoalsView`, `DietGoalView`.
  - `SettingsView` apagado. `ThemePicker` e os rótulos do `ValueStepper` agora passam pelo L10n.
  - Strings PT/EN geradas do JSON da web (`nav.profile.*`, `today.goals.*`, `diet.goal.*`, `diet.macro.*`, `common.theme.*`), mais 2 só do app: `manageOnWeb` e `goalsLoadFailed`.
- `xtool dev build` passa, e a primeira versão foi instalada no iPhone. A troca da foto por `AsyncImage` foi feita depois e ainda não foi instalada.
- Linhas 07–14 da Fase S no `ios/README.md`. Pares web 07–09 capturados em `ios/validation/S/`.
- **Falta**: reinstalar, capturar as linhas do app (07–09 e 14 pelo `launch.sh`, 10–13 com o usuário navegando) e a aprovação do usuário. O iPhone estava em uso, então o agente parou de reabrir o app.
