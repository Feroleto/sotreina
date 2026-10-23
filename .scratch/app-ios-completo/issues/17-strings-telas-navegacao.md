# Strings das telas da Navegação em PT/EN

Type: task
Status: claimed
Blocked by: 07

## Question

Terminar a migração de [Strings das telas em PT/EN](15-strings-telas.md) nos arquivos que a [Navegação: abas, header de área e sessão minimizável](07-navegacao.md) estava reescrevendo quando aquele ticket rodou, usando o pipeline que ele montou (`Text("chave", bundle: .l10n)` nas views, `L10n.string(_:lang:)` fora delas, chaves e vocabulário da web):
- `RootView`, `SettingsView`, `App/AppShell.swift`, `App/AreaScreen.swift` (hoje com ternários `pt ? … : …`);
- `RoutinesView`, `WorkoutSessionView`, `ActiveWorkoutBar` e as mensagens do `WorkoutStore`, passando `lang:` pro `WorkoutFormat.weight/set/volume`.
- Ao final, `grep` por `Text("` sem `bundle: .l10n`/`verbatim:` e por `pt ?` em `ios/Sources` não deve achar texto de interface.

## Answer

**Migrado e compilando (2026-10-22). Falta conferir no iPhone.** Outra sessão instalou no aparelho ao mesmo tempo ("IXSimpleInstaller canceling existing coordinator"), então o `deploy.sh` desta foi cancelado.

- **Strings novas**: um bloco acrescentado no fim dos `.strings` PT/EN, mais o plural `gym.routines.exerciseCount %lld` no `.stringsdict`. As chaves PT e EN batem, e o build copia tudo pro bundle do app e da `.appex`. O texto PT é o que o usuário já tinha aprovado nas telas. O EN segue a web onde ela tem o mesmo conceito, como "Return to your active workout" e "Try again".
  - `common.ok`, `common.retry`, `common.save` e `common.delete`.
  - `app.error.*`: o alerta "Não deu certo" e as mensagens do `WorkoutStore`.
  - `app.comingSoon.*`.
  - `gym.activeBar.*`, `gym.routines.*`, `gym.session.*`, e `gym.entry.weightLabel %@`/`repsLabel`/`deleteSet`.
- **Telas**:
  - **`AreaScreen`**: `ComingSoonView`.
  - **`ActiveWorkoutBar`**.
  - **`AppShell`**: o alerta.
  - **`RoutinesView`**: agora com `RoutineFormat.lastPerformed(…, lang:)` e `MuscleGroup.label(_, lang:)`.
  - **`WorkoutSessionView`**: todos os botões, diálogos, rótulos e o sheet de edição, mais `WorkoutFormat.set/weight/target(…, lang:)`.
  - **`WorkoutStore.message(for:lang:)`**.
- **Não migrados**: `RootView` não tem texto de interface. O `SettingsView` ficou de fora de propósito, porque o [Perfil do app](11-perfil.md) está substituindo esse arquivo em outra sessão.
- **Grep do critério**: `Text("` sem `bundle: .l10n`/`verbatim:` e `pt ?` em `ios/Sources` só acham o `SettingsView`. Números, "×", "S3" e "PR" viraram `verbatim:`.
- **Ainda em kg**: o rótulo "Peso (kg)" e as séries. O lb é da Fase T, e a chave `gym.entry.weightLabel %@` já recebe a unidade.
- `xtool dev build` passa, e os 115 testes do Kit passam.
