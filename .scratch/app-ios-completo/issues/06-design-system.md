# Design system Monolito no app (tokens, tema, fontes)

Type: task
Status: resolved
Blocked by: 03

## Question

Construir o `DesignSystem` do app (spec §3, Fase S): cores claro/escuro espelhando `client/src/index.css` (paleta Monolito, mostarda `#D9A441`, texto sobre mostarda sempre `acc-fg`), estilos de texto com Geist/Geist Mono, raios e espaçamentos, e os componentes base (número grande, KPI, barra de progresso, chips, stepper). Inclui o seletor de tema Auto/Claro/Escuro por dispositivo e a troca do azul atual pelo mostarda, inclusive na Live Activity. As telas existentes (rotinas, sessão, resumo) passam a usar o design system. As fontes já registram no app (`Core/AppFonts.swift`, ver o ticket [Teste: fontes Geist e Geist Mono embutidas](03-teste-fontes.md)); falta levá-las pra Live Activity, que é outro target e outro processo.

## Answer

Feito em 2026-10-22: compila, os testes do Kit passam (90) e foi conferido no iPhone pelo cabo, claro e escuro. Detalhes no `ios/README.md`, seção "Design system (Monolito)".

- **Onde mora**: target novo `SoTreinaDesign` no `ios/Package.swift`, dependência do app e da Live Activity. As fontes saíram do target `SoTreina` e foram pra ele (`Fonts.swift`, antigo `Core/AppFonts.swift`), e o xtool copia o bundle de recursos pras duas. **Live Activity em Geist e mostarda: conferida no iPhone.** Com isso some o conflito entre o `.copy("Resources/Fonts")` e o `.process("Resources")` da localização.
- **Kit**: `Monolito` (hex claro/escuro dos tokens) e `ThemePreference` (`auto`/`light`/`dark`, os valores da web). O `MonolitoTests` lê o `client/src/index.css` e falha se a paleta divergir.
- **App**: cores dinâmicas, `DSFont`, componentes (número grande, KPI, linha de progresso, chips, badge, stepper, título de seção), estilos de botão `.primary`/`.pill`/`.chip`, `.monolitoList()`/`.monolitoForm()`, `.monolitoTheme()` na raiz e `ThemePicker` na tela Conta (o Perfil deve absorvê-lo).
- **Telas migradas**: Rotinas, Sessão (faixa de KPIs no topo, séries em Mono, ✓ em `pos`, ⚠ em `neg`), barra de descanso, Resumo (número grande + KPIs + PRs), Login, Conta, busca de exercício, banner de expiração e Live Activity. O azul `#3987E5` saiu de tudo.
- **Conferido no iPhone**: Rotinas (escuro), catálogo (claro e escuro, troca de tema na hora), sessão com descanso (claro), Live Activity. **Não conferidos visualmente**: Resumo (exigiria finalizar um treino real) e Login (exigiria sair).
- Achado: no SwiftUI a fonte variável responde a `.weight`, mas no UIKit (barra de navegação) o peso precisa ir no eixo `wght`. Corrigido em `AppFonts.uiFont`.
- **Pendências pra outros tickets**: o `ThemePicker` e o catálogo ficam na tela Conta até existir o "Perfil do app"; o catálogo pode ser reaproveitado na "Formato da validação visual por fase".
