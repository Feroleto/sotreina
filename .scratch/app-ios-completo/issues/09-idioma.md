# Idioma PT/EN no app

Type: task
Status: resolved
Blocked by: 02

## Question

Com o formato decidido no teste de localização, migrar todas as strings do app pra PT/EN; idioma padrão = o do iPhone (outros caem em EN, como a web), com seletor no Perfil que sobrescreve; `Accept-Language` acompanhando o idioma do app; e o envio de `X-Time-Zone` com o fuso do iPhone (spec §3, Fase S; §6.2).

Inclui levar o idioma escolhido até a **Live Activity**, que roda em outro processo e não lê o `@AppStorage` do app (pelo `ContentState` ou pelo App Group), e dar strings à extensão. Ver o `## Answer` de "Teste: localização PT/EN sem Xcode".

## Answer

**Infraestrutura pronta (2026-10-22); a troca das strings das telas virou o ticket [Strings das telas em PT/EN](15-strings-telas.md).** O usuário decidiu dividir o ticket porque a sessão do Design system estava reescrevendo todas as telas ao mesmo tempo.

O que foi feito:
- **Kit**:
  - **`Lang.swift`**: `Lang` (`pt`/`en`, com `acceptLanguage` e `localeIdentifier`) e `AppLanguage` (`auto`/`pt`/`en`). A regra do `auto` é a da web: o primeiro idioma preferido começando com `pt` vira PT, e o resto vira EN.
  - **Formatadores do Kit em PT e EN**, com `lang:` e padrão PT (as telas atuais não mudaram): `RoutineFormat.lastPerformed`, `MuscleGroup.label` (inglês copiado de `client/src/i18n/locales/en/gym.json`; a sobrecarga `label(_:)` sem `lang` existe pra `.map(MuscleGroup.label)` continuar compilando), `WorkoutFormat.target` e `AppExpiry.banner`.
  - **Strings do Kit**: são **dicionários/ternários em Swift**, não `.strings`, pra continuarem testáveis no Linux e servirem igual pro app e pra extensão.
  - **Testes**: 13 em `LangTests.swift`.
- **Live Activity**: `WorkoutActivitySnapshot.lang: Lang?`, preenchido pelo `snapshot(..., lang:)`. É opcional pra um estado gravado por build antigo continuar decodificando (`nil` = PT). O `setLabel` sai "Set 2 of 3" em EN. As outras strings da extensão ("Em série", "Próxima:") ficam pro ticket das telas, usando `state.lang`.
- **App**:
  - **`Core/AppLanguageStore.swift`**: `@Observable`, guarda `choice` em `UserDefaults["appLanguage"]`, expõe `lang`/`locale`, e tem `nonisolated static var current` pra código fora da main actor.
  - **`SoTreinaApp`**: segura o store como `@State` e aplica `.environment(\.locale, language.locale)` e `.environment(language)` na raiz.
  - **`APIClient`**: manda `Accept-Language` do idioma do app (não mais `pt` fixo) e `X-Time-Zone` com `TimeZone.current.identifier`.
  - **`WorkoutStore`**: passa o idioma pra Live Activity.
- **Instalado no iPhone sem regressão.** A API aceita os cabeçalhos novos.

**Pendente, por ticket:**
- **Strings das telas em PT/EN**: o pipeline `.strings`/`.stringsdict` (onde ficam os recursos compartilhados entre app e extensão) e a migração das telas.
- **Perfil do app**: o seletor de idioma, que só precisa ler e gravar `AppLanguageStore.shared.choice`.
- **Live Activity**: uma troca de idioma só chega a ela na próxima mudança de estado do treino. Aceitável; se incomodar, chamar o `refreshLiveActivity` quando o `choice` mudar.
