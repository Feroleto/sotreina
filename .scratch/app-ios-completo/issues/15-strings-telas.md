# Strings das telas em PT/EN

Type: task
Status: resolved
Blocked by: 06

## Question

Montar o pipeline de strings da interface e migrar todas as telas existentes pra ele, com o formato decidido no [Teste: localização PT/EN sem Xcode](02-teste-localizacao.md) e a infraestrutura do [Idioma PT/EN no app](09-idioma.md):
- `Localizable.strings` + `Localizable.stringsdict` em `pt.lproj`/`en.lproj` num target que o app **e** a extensão da Live Activity enxerguem (provavelmente `SoTreinaDesign`, que já tem recursos), com um helper de bundle;
- `Text(key, bundle:)` nas views (o `locale` já vem do `AppLanguageStore` na raiz) e `String(localized:bundle:locale:)` fora delas;
- migrar login, rotinas, sessão, resumo, conta, banner e a Live Activity (usando `state.lang`), passando `lang:` pros formatadores do Kit;
- vocabulário igual ao da web (`client/src/i18n/locales/{pt,en}`) e ao `GLOSSARY.md`.

Bloqueado pelo Design system porque ele está reescrevendo essas mesmas telas.

## Answer

**Pipeline pronto, com metade das telas migrada (2026-10-22).** A Navegação estava reescrevendo as outras telas em outra sessão, então o usuário decidiu migrar só os arquivos que ela não toca. O restante virou [Strings das telas da Navegação em PT/EN](17-strings-telas-navegacao.md).

- **Pipeline**: `Localizable.strings` + `.stringsdict` em `ios/Sources/SoTreinaDesign/Resources/Strings/{pt,en}.lproj` (`.process("Resources/Strings")` no `Package.swift`). O build copia os dois `.lproj` pro bundle `SoTreina_SoTreinaDesign.bundle` do app **e** da `.appex` (conferido no build).
- **`SoTreinaDesign/L10n.swift`**:
  - `Bundle.l10n` é pras views: `Text("chave", bundle: .l10n)`, e o `\.locale` da raiz escolhe o `.lproj`.
  - `L10n.string(_:lang:_:)`/`(arguments:)` é pra código fora de view. Lê o `.lproj` do idioma e resolve `%@`/`%lld` e plural.
- **Chaves**: são as da web com o namespace (`gym.summary.done`, `auth.login.invalidCredentials`). Um valor interpolado entra na chave do jeito que o `LocalizedStringKey` monta: `"gym.summary.prFrom %@"`, `"gym.summary.prTitle %lld"` (plural no `.stringsdict`).
- **Kit**: `WorkoutFormat.weight/set/volume` ganharam `lang:` (EN: `22.5`, `12,345.5`). `weight(_:)` sem `lang` continua existindo, porque um `lang` com default não converte pra `(Double) -> String` em `.map(WorkoutFormat.weight)`. Esse é o mesmo motivo de `MuscleGroup.label(_:)`. Tem teste novo em `LangTests`, e os 96 testes passam.
- **Telas migradas**:
  - **Login**: o erro virou um enum, então ele também troca de idioma.
  - **Resumo** do treino, **RestBar** (com `accessibilityLabel` em −15s/+15s/Pular) e **ExercisePickerView** (grupos musculares com `lang`).
  - **Banner e notificação de expiração**, **notificação do descanso** e o nome "Treino livre" da Live Activity. Esses três usam `AppLanguageStore.current` na hora de agendar.
  - **Live Activity**: "Em série", "Próxima:", "Série não enviada", "Adicione um exercício", "Pular". Usa `state.lang` e resolve pra texto puro com `L10n.string`, porque o `\.locale` da extensão não é o do app.
- **Build e instalação**: `xtool dev build` passa e o `deploy.sh` instalou no iPhone. O usuário conferiu as telas no aparelho em 2026-10-22, e está tudo certo.
- **Pendente**: o seletor de idioma continua no ticket do Perfil.
