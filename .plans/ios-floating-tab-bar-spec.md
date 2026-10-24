# Pílula flutuante no app iOS

**Data:** 2026-10-24 · **Escopo:** só o app iOS (`ios/`). A web (`MobileTabBar` em `client/src/features/nav/MobileChrome.tsx`) não muda.

## Problema

O `AppShell` usa a tab bar do sistema (`TabView` + `.tabItem`). No iOS 27 ela aparece como a barra nativa de vidro, com rótulo em todas as abas. A web tem outra cara: uma pílula centralizada que mostra só os ícones, e a aba ativa ganha um chip com o rótulo ao lado do ícone. O objetivo é que o app tenha a mesma pílula, com alguns comportamentos próprios do iPhone.

## Decisões (entrevista de 2026-10-24)

| Tema | Decisão |
|---|---|
| Visual base | Pílula da web: abas só com ícone, e a ativa num chip com ícone + rótulo |
| Ícones | **SF Symbols atuais** (`AppTab.symbol`: house / figure.run / dumbbell / fork.knife), não os paths da web |
| Material | **Liquid Glass no iOS 26+** (`glassEffect`). No iOS 18–25, **sólido `pageBg` + borda hairline**, igual à web |
| Degradê de rodapé da web | **Não** vem para o app |
| Troca de aba | O chip **desliza e expande** até a nova aba e o rótulo entra com fade, numa mola curta |
| Haptics | `.sensoryFeedback(.selection)` na troca de aba |
| Retoque na aba ativa | Volta à raiz da aba. Se já está na raiz, rola até o topo |
| Telas empilhadas | A pílula **continua visível**. Só some nas telas que já escondem a tab bar hoje (ver §4) |
| Rolagem | **Encolhe ao rolar pra baixo** e volta ao rolar pra cima |
| Encolhida | Só o ícone ativo, num **círculo de 50pt no canto inferior esquerdo** |
| Toque na encolhida | **Só expande**, sem trocar de aba |
| Limiar | Encolhe depois de ~40pt rolados pra baixo, e nunca nos primeiros 40pt do conteúdo. Expande com ~20pt pra cima |
| Treino em andamento | **Cápsula de vidro acima da pílula**, na largura do conteúdo. Com a pílula encolhida, **desce pra linha dela**, ao lado do círculo |
| Dynamic Type | O rótulo cresce até `.xxLarge` |
| Reduzir movimento | Os comportamentos continuam, mas os estados trocam por **crossfade** em vez de deslizar ou morph |
| Uma área só | Sem pílula, como hoje (`AppTab.showsTabBar`) |

## 1. Arquitetura

- **O `TabView` fica.** Ele já mantém um `NavigationStack` vivo por aba, guarda o estado de cada tela e trabalha com o `@SceneStorage("selectedTab")`. A barra do sistema é escondida, e a pílula entra por cima como overlay do `AppShell`. Trocar o `TabView` por um container próprio (`ZStack` com opacidade) também funcionaria, mas teria que reimplementar a retenção de estado de cada aba sem nenhum ganho.
- A barra nativa fica escondida com `.toolbar(.hidden, for: .tabBar)` na raiz de cada aba (`AreaScreen`), sempre, no lugar do `.automatic`/`.hidden` condicional de hoje.
  - **Verificar no iPhone (iOS 27)** se a barra nativa some também nas telas empilhadas. Se ela reaparecer num push, a alternativa é aplicar o modifier no destino ou trocar para `TabView` com `.tabViewStyle(.tabBarOnly)` + barra escondida. Registrar no `ios/README.md` o que funcionou.
- Componente novo `FloatingTabBar` em `ios/Sources/SoTreina/App/FloatingTabBar.swift` (o app recebe a view; o pacote `SoTreinaDesign` recebe os tokens que faltarem).
- **A lógica pura vai pro Kit**, em `SoTreinaKit/Navigation.swift` ou num `TabBarBehavior.swift` novo, testada com `swift test`:
  - a máquina de estado expandida/encolhida a partir de uma sequência de offsets de scroll (limiar de 40pt pra baixo, zona morta de 40pt no topo, 20pt pra cima pra expandir);
  - o retoque: "estou na raiz?" → pop, senão → rolar pro topo.

## 2. Visual

Valores tirados da web, convertidos em pt:

- **Pílula expandida:** padding interno 5, gap 2 entre botões, botões com 46 de altura e 50 de largura mínima, `Capsule`. Centralizada na horizontal e largura do conteúdo (não ocupa a tela toda).
- **Distância do rodapé:** `max(20, safeArea.bottom + 8)`. No iPhone com home indicator, isso dá 8pt acima da área segura.
- **Aba inativa:** só o ícone, 22pt, em `Color.mutedFg`, com peso de símbolo `.regular`.
- **Aba ativa:** chip `Color.chip` em `Capsule`, padding 12 à esquerda e 16 à direita, gap 7. O ícone fica em `Color.accTx` com peso `.semibold`, e o rótulo (`AppTab.label`) em 13.5 semibold `Color.fg`, escalando com Dynamic Type até `.xxLarge`.
  - No iOS 26+ o chip pode ficar como `Capsule` sólido `chip` dentro do vidro. Não precisa ser vidro sobre vidro. Decidir no aparelho qual fica melhor e registrar.
- **Material:**
  - iOS 26+: `.glassEffect(.regular.interactive(), in: .capsule)`. Pílula e cápsula do treino ficam num `GlassEffectContainer`, pra o vidro das duas se fundir na transição para a linha única (§5). O `glassEffect` já respeita sozinho o "Reduzir transparência".
  - iOS 18–25: fundo `Color.pageBg`, `strokeBorder(Color.border, lineWidth: 1)` (hairline).
- **Sem degradê** atrás da pílula.

## 3. Interação

### Troca de aba
- O chip ativo usa `matchedGeometryEffect` (namespace local) e desliza do botão antigo para o novo. A largura acompanha porque o novo botão expande pra caber o rótulo. O rótulo entra com `.opacity`. A mola é curta, sem bounce visível (algo como `.snappy(duration: 0.3)`).
- Com Reduzir movimento, nada desliza: o chip e o rótulo trocam por crossfade de ~150ms.
- `.sensoryFeedback(.selection, trigger: selectedTab)`.

### Retoque na aba ativa
- Se a aba tem telas empilhadas, volta à raiz. Isso exige que o `NavigationStack` de cada `AreaScreen` use `path` explícito (`NavigationPath`) em vez de só `navigationDestination(isPresented:)`, ou um sinal equivalente que o `AreaScreen` observe para desempilhar o `showsProfile` e os pushes de cada feature.
  - **Levantar no código** quais telas empilham por `isPresented`/`item` (Perfil, detalhe de atividade, detalhe de rotina, histórico…) e escolher o mecanismo menos invasivo. Um sinal `popToRootToken` no environment, que cada destino observe, é aceitável se migrar tudo para `path` for grande demais.
- Se já está na raiz, rola até o topo. O `ScrollView`/`List` raiz de cada página precisa de um `ScrollViewReader` (ou `.scrollPosition`, iOS 18) ouvindo um token de "rolar pro topo" vindo do shell.
- O retoque também expande a pílula se ela estiver encolhida, porque rolar até o topo cai na zona morta.

### Encolher ao rolar
- **Fonte do scroll:** `onScrollGeometryChange` (iOS 18) no scroll principal de cada página. Um modifier `.reportsTabBarScroll()` publica o `contentOffset.y` num `@Observable` do shell (`TabBarState`) que o `AppShell` injeta no environment. Hoje são ~24 arquivos com `ScrollView`/`List`. **Só o scroll principal de cada página** recebe o modifier. Scrolls horizontais, sheets e pickers ficam de fora.
- **Regra** (Kit, testada): a direção é acumulada desde a última mudança de sentido. São 40pt pra baixo com `offset > 40` pra encolher, e 20pt pra cima pra expandir. `offset <= 40` sempre expande. Quique elástico (offset negativo ou além do fim) é ignorado.
- **Encolhida:** a pílula vira um círculo de 50pt no canto inferior esquerdo (16pt de margem lateral, mesma distância do rodapé), com só o ícone da aba ativa em `accTx`. A transição é um morph de forma e posição, com o chip e o ícone ativo como o elemento que permanece (`matchedGeometryEffect`). As outras abas somem com fade.
- **Toque no círculo:** só expande. Não troca de aba e não rola.
- **Reset:** a pílula volta a expandir ao trocar de aba, ao empilhar ou desempilhar uma tela, e ao voltar do segundo plano. Cada página nova começa expandida.
- Com Reduzir movimento, a regra continua igual, e a troca entre os dois estados é um crossfade sem morph.

## 4. Onde a pílula some

Hoje essas telas usam `.toolbar(.hidden, for: .tabBar)`. Esse modifier passa a não ter efeito sobre a pílula, então elas devem migrar para um modifier próprio, `.hidesFloatingTabBar()`, que publica uma preferência ou contador lido pelo shell:

- `ProfileView` (via `AreaScreen`)
- `AddMealView` (tem barra fixa no rodapé)
- `SavedMealsListView`
- `ManualFoodView`
- e qualquer outra que `grep "toolbar(.hidden, for: .tabBar)"` encontrar no momento da implementação.

Fazer como **contador**, não boolean, pra pushes aninhados se empilharem (mesma lição do `useHideMobileChrome` da web). A pílula some com fade (ou com fade + descida curta de 12pt sem Reduzir movimento) e volta do mesmo jeito.

Continua como hoje:
- **Uma área só:** sem pílula (`AppTab.showsTabBar`). A cápsula do treino em andamento ainda aparece sozinha, no lugar dela.
- **Sessão de treino e resumo:** são `fullScreenCover`, então a pílula não aparece.
- **Teclado:** a pílula ignora a área segura do teclado e fica atrás dele. Não sobe junto.

## 5. Treino em andamento (`ActiveWorkoutBar`)

- Hoje é uma faixa de largura total presa por `.safeAreaInset(edge: .bottom)` em cada aba. Passa a morar no **mesmo overlay** da pílula, no `AppShell`, para que as duas se coordenem.
- **Pílula expandida:** a cápsula fica 8pt acima da pílula e ocupa a largura do conteúdo (16pt de margem dos dois lados), com cantos de raio ~22 ou `Capsule`, e o mesmo material da pílula (vidro no 26+, sólido + borda no 18–25). O conteúdo continua o atual: ponto mostarda 8pt, "Em andamento" em caption muted, nome da rotina, cronômetro Geist Mono e `chevron.up`.
- **Pílula encolhida:** a cápsula desce pra linha do círculo e ocupa o espaço à direita dele (8pt de gap e 16pt de margem direita), como o mini-player do Apple Music. No iOS 26+ o `GlassEffectContainer` + `glassEffectID` fazem as duas formas se fundirem e separarem. No 18–25 é só animação de frame. Com Reduzir movimento, é crossfade.
  - Na linha única pode faltar largura: o nome da rotina corta com `lineLimit(1)`, e o cronômetro nunca corta.
- Tocar na cápsula continua reabrindo a sessão (`store.sessionMinimized = false`), em qualquer estado da pílula.

## 6. Espaço do conteúdo

A pílula é overlay e não empurra nada. Para a última linha de cada lista poder rolar acima dela, o shell aplica uma `.safeAreaInset(edge: .bottom)` invisível na raiz de cada aba, com a altura que a barra ocupa no estado **expandido** (pílula + cápsula do treino + espaçamentos). Esse inset não diminui quando a pílula encolhe, senão o conteúdo pularia de altura. Telas que escondem a pílula (§4) não recebem o inset.

## 7. Acessibilidade

- Cada botão tem `accessibilityLabel` com o nome da aba, inclusive as inativas, que não mostram rótulo. A aba ativa leva o trait `.isSelected`. O container é anunciado como tab bar (`.accessibilityElement(children: .contain)` + `accessibilityAddTraits(.isTabBar)`, se disponível; senão, um label "Abas").
- Encolhida, o círculo diz "Expandir abas, aba atual: <nome>".
- Alvo de toque mínimo 44pt: os botões têm 46 de altura e 50 de largura mínima.
- Com o VoiceOver ligado, a pílula **não encolhe** (`UIAccessibility.isVoiceOverRunning` / `@Environment(\.accessibilityVoiceOverEnabled)`), pra não sumir alvo de navegação.

## 8. Validação

- **Testes do Kit** (`cd ios/SoTreinaKit && swift test`):
  - a máquina de encolher: sequência de offsets → estados, cobrindo a zona morta, a histerese, o quique negativo e o reset;
  - a decisão do retoque.
- **Destinos de validação** (`ValidationLaunch`), pra screenshot sem rolar na mão: `tabBarCollapsed` (aba Treino com a pílula encolhida) e `tabBarWithWorkout` (pílula expandida + cápsula do treino, com dado fixo). Se for barato, também `tabBarCollapsedWithWorkout`.
- **No iPhone (iOS 27)**, com `scripts/screenshot.sh`, conferir:
  - claro e escuro;
  - 2, 3 e 4 abas (combinações de áreas);
  - fonte em `.xxLarge`;
  - Reduzir movimento;
  - Reduzir transparência;
  - o retoque em tela empilhada e na raiz;
  - Perfil e Adicionar refeição sem pílula;
  - teclado aberto na busca de exercício.
- Não há como testar o fallback do iOS 18–25 no aparelho. Basta compilar o ramo `#available` e conferir a leitura do código.

## Fora de escopo

- Qualquer mudança na web (o chip animado e o encolher ficam só no app).
- Trocar os ícones pelos paths da web.
- Usar o `tabBarMinimizeBehavior`/`tabViewBottomAccessory` do sistema. Eles só existem no 26+, não deixam usar o visual da web, e a barra seria a do sistema de novo.

## Atualizar depois

- `CLAUDE.md` › "App iOS" › Telas: a tab bar virou pílula flutuante própria (`FloatingTabBar`), escondida por `.hidesFloatingTabBar()` em vez de `.toolbar(.hidden, for: .tabBar)`.
- `ios/README.md`: o que funcionou para esconder a barra nativa em pushes no iOS 27 (§1).
