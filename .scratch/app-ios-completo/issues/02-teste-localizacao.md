# Teste: localização PT/EN sem Xcode

Type: task
Status: resolved
Blocked by:

## Question

Qual formato de strings localizadas funciona com o xtool: `.xcstrings` (provavelmente exige o `xcstringstool` do Xcode) ou `Localizable.strings` em `pt.lproj`/`en.lproj` como recurso SwiftPM? E dá pra trocar o idioma em runtime por um seletor dentro do app, sem reiniciar? Teste com duas ou três strings na tela de login. Registrar o resultado no `ios/README.md` (spec §3, Fase S, teste 2).

## Answer

Resolvido em 2026-10-22, com um app mínimo à parte (`com.example.l10ntest`) instalado no iPhone e depois desinstalado. O `ios/` não foi tocado, exceto pela seção "Localização (PT/EN)" do `ios/README.md`.

- **Formato: `Localizable.strings` + `Localizable.stringsdict` em `pt.lproj`/`en.lproj`**, como recurso SwiftPM (`.process("Resources")`). O `.xcstrings` falha no build: o xtool não tem o `xcstringstool`.
- **Plural** por `.stringsdict` funciona no device (`1 série`/`2 séries`).
- **Troca em runtime sem reiniciar: sim.** Testado pelo usuário: as três formas trocam na hora, e o plural continua certo:
  - (A) `Text(key, bundle: <bundle do .lproj>)`;
  - (B) `Text(key, bundle: .module)` + `.environment(\.locale, …)` na raiz;
  - (C) `String(localized:bundle: <bundle do .lproj>)`.
- **Recomendação para "Idioma PT/EN no app"**: (B) nas views e (C) fora delas, por um único helper no app que resolve o idioma (Auto → `pt*` vira PT, o resto vira EN) e entrega o `Locale` e o bundle do `.lproj`. A regra de resolução é lógica pura e pode ir pro Kit, com teste.
- **Em aberto pra esse ticket**: a Live Activity roda em outro processo e não lê o `@AppStorage` do app. A escolha precisa chegar até ela, pelo `ContentState` ou pelo App Group (ver "Teste: App Group com xtool e Apple ID grátis"), e a extensão precisa das próprias strings ou de um recurso do Kit. O seletor por app nos Ajustes do iOS (`CFBundleLocalizations`) não foi testado e não é necessário.
