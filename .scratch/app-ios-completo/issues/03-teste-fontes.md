# Teste: fontes Geist e Geist Mono embutidas

Type: task
Status: resolved
Blocked by:

## Question

As fontes Geist e Geist Mono, empacotadas como recurso SwiftPM e registradas em runtime com `CTFontManagerRegisterFontsForURL`, aparecem no iPhone e acompanham o Dynamic Type via `Font.custom(_:size:relativeTo:)`? Usar os mesmos arquivos de fonte da web (`@fontsource-variable/geist`, `geist-mono`) e conferir a licença (OFL). Registrar o resultado no `ios/README.md` (spec §3, Fase S, teste 3).

## Answer

**Funciona.** Testado no iPhone em 2026-10-22: as duas famílias registram, a fonte variável dá 6 pesos distintos via `.fontWeight`, e o texto acompanha o Dynamic Type com `Font.custom(_:size:relativeTo:)`.

- Arquivos: os TTF **variáveis** do pacote npm `geist` 1.4.2 (`Geist-Variable.ttf`, `GeistMono-Variable.ttf`, ~250 KB juntos), não os `.woff2` do `@fontsource-variable` da web, que vêm cortados por faixa de Unicode. Mesma família. Licença OFL 1.1, embutir é permitido, cópia em `ios/Sources/SoTreina/Resources/Fonts/OFL.txt`.
- Mecanismo: `resources: [.copy("Resources/Fonts")]` no target `SoTreina` + `CTFontManagerRegisterFontsForURL(.process)`, sem `UIAppFonts`. Fica no app: `ios/Sources/SoTreina/Core/AppFonts.swift` (`Font.geist(_:relativeTo:)`, `Font.geistMono(_:relativeTo:)`), pronto pro design system. A tela de teste foi removida.
- Pendente pro design system: a Live Activity (outro processo e outro target) não foi testada, e a regra de recursos precisa ser conciliada com o `.process("Resources")` da localização. Detalhes em `ios/README.md`, seção "Fontes".
