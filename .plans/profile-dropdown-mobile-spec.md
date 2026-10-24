# Menu de perfil no canto superior direito (mobile), via Kokonut UI

Data: 2026-10-23. Origem: entrevista `/interview`.

## Objetivo

No mobile (< `md`), o Perfil **sai da pílula inferior** e passa a ser um **menu suspenso** aberto pelo avatar no canto superior direito do `MobileHeader`. O estilo segue o `profile-dropdown` do Kokonut UI: o painel cresce a partir do gatilho (morph por `clip-path`), tem a linha de tema segmentada e "segure pra sair". As cores usam os tokens Monolito.

O desktop (≥ `md`) **não muda**. O rodapé da `Sidebar` continua com avatar, nome, tema/idioma e sair.

## Fora de escopo

- Desktop/Sidebar.
- Status (online/ausente/ocupado), trocar de conta, adicionar conta e "Billing" do Kokonut. Esses conceitos não existem no SoTreina e saem do código.
- Mudanças no conteúdo da `ProfilePage`. Nada é removido de lá: tema e idioma ficam duplicados de propósito, porque o menu é só um atalho.

## Decisões (da entrevista)

| Tema | Decisão |
|---|---|
| Referência de estilo | O próprio Kokonut `profile-dropdown` |
| Gatilho mobile | **Só o avatar** (34px, foto Strava ou iniciais), na mesma posição de hoje |
| Posição | **Rola com o header** (em fluxo, como hoje). Não é fixo |
| Desktop | Não muda |
| Pílula com 1 área | **Some** (pílula e degradê). Sem o Perfil, sobraria só a aba Hoje |
| Itens do menu | Cabeçalho (avatar + nome + email) → Tema Auto/Claro/Escuro → Idioma PT/EN → separador → **Configurações** → separador → Segure pra sair |
| Configurações | Abre a `ProfilePage` |
| ProfilePage no mobile | **Tela cheia com voltar**: esconde header e pílula, o voltar retorna à página de origem |
| Sair | **Segurar 1,2 s** (hold-to-confirm do Kokonut). O logout incrementa `tokenVersion` e derruba todas as sessões, web e iOS |
| Conta sem email (só Strava) | A segunda linha mostra "Conectado via Strava" / "Connected via Strava" |
| Após trocar tema/idioma | O menu **fica aberto**. Fecha ao tocar fora, com Esc ou com Tab |
| Cores | Tokens Monolito no lugar de `zinc-*` |
| Código | `npx shadcn add` e **adaptar o arquivo no lugar**, mantendo o cabeçalho de crédito MIT |
| Bundle | **Lazy no primeiro toque**: o avatar é HTML puro no chunk principal; o painel com Motion só baixa ao tocar |

## Instalação

```bash
cd client
npx shadcn@latest add https://kokonutui.com/r/profile-dropdown.json
```

- Gera `client/src/components/kokonutui/profile-dropdown.tsx`. O alias `@/components` vem do `components.json`, e o arquivo usa `@/lib/utils`, que já existe.
- As dependências `lucide-react` e `motion` já estão instaladas (`motion@^14.3.0`). Conferir que o CLI **não** alterou o `package.json`/lockfile além disso.
- Remover a diretiva `"use client"` (projeto Vite, não é RSC) e os comentários `biome-ignore`. O projeto usa ESLint: trocar pelo `eslint-disable-next-line react-hooks/exhaustive-deps` equivalente onde o lint reclamar.

## Adaptações no `profile-dropdown.tsx`

Editar no lugar. Nada de cópia intacta ao lado (o CLAUDE.md pede pra não deixar código morto).

### Remover
- `Account[]`, `SAMPLE_ACCOUNTS`, `defaultAccountId`, `onAccountChange`, `onAddAccount`, a página `accounts`, o item "Switch account", o `pageX`/`pageTransform`, o efeito de troca de página e o atalho `Backspace`/`ArrowLeft`.
- `STATUSES`, `StatusRow`, o ponto de status do `Avatar` e as props `status`.
- `SAMPLE_ITEMS`, `CreditCard`, `User`, `plan`.
- `AVATAR_TONES` com vários tons. Fica um tom só: `bg-chip text-foreground`, igual ao avatar atual do header.

### Mudar
- **Props** passam a ser: `name`, `secondary` (email ou o texto de fallback), `avatarUrl?`, `initials`, `theme`/`onThemeChange` (controlado), `language`/`onLanguageChange`, `onSettings`, `onSignOut`, `labels` (todas as strings traduzidas, ver i18n), `defaultOpen?`, `holdDuration = 1200`.
- **Avatar**: renderiza `<img>` quando há `avatarUrl` (`avatarMediumUrl(...)`, `object-cover`, contorno `outline outline-1 -outline-offset-1 outline-black/10 dark:outline-white/10`, mesma regra das imagens de conteúdo) e as iniciais quando não há.
- **Gatilho**: deixa de ser o cartão `w-60` com nome e email e vira o botão de **44×44** (alvo de toque) com o avatar de 34px alinhado à direita. Fica igual ao botão atual do `MobileHeader`, sem o `ChevronsUpDown`. Recebe `aria-label={labels.menu}`, `aria-haspopup="menu"` e `aria-expanded`.
- **Identity compartilhada**: só o avatar faz o `layoutId` entre gatilho e cabeçalho, porque nome e email não aparecem no gatilho. No painel, nome e email entram com o `bodyOpacity`, como o resto do corpo.
- **Morph**: o `clip-path` parte do retângulo de 44×44 do gatilho. Manter `RADIUS = 16`, `PANEL_W = 288` e a âncora `top-0 right-0`. Numa tela de 360px com gutter de 22px, o painel fica entre 50px e 338px e cabe.
- **Motion**: `motion.*` vira `m.*` (o projeto usa `LazyMotion`). O componente inteiro fica dentro de `MotionProvider` (`components/MotionProvider.tsx`), que já faz `LazyMotion` + `MotionConfig reducedMotion="user"`. O `useReducedMotion` do Kokonut continua cobrindo os casos de `animate()` imperativo.
- **ThemeRow**: os ids passam a ser `auto | light | dark` (o `ThemePref` do app), com ícones `Monitor`/`Sun`/`Moon`. Ordem: Auto, Claro, Escuro, a mesma do resto do app.
- **LanguageRow** (nova): copia a `ThemeRow`, com dois botões de texto `PT` / `EN`, `data-row="language"` e o mesmo `layoutId` de indicador, com outro sufixo.
- **Configurações**: um único item fixo (ícone `Settings`, `ChevronRight` à direita) no lugar do array `items`. `onSelect` fecha o menu **sem devolver o foco ao gatilho**, porque a tela vai trocar, e depois chama `onSettings`.
- **HoldSignOut**: strings vêm de `labels` ("Sair", "Segure", "Continue segurando" e o sr-only ", pressione e segure para confirmar"). O preenchimento invertido usa `bg-foreground text-background`. A transição de `clip-path` de recuo continua, mas vai atrás de `prefers-reduced-motion`: sob reduce, o recuo é instantâneo. O preenchimento linear durante o hold fica, porque ele é o feedback do gesto.
- **Classes `zinc-*` → tokens Monolito**:
  - superfície do painel `bg-white dark:bg-zinc-900` → `bg-card`; borda `bg-zinc-200 dark:bg-zinc-800` → `bg-border`
  - item focado `focus:bg-zinc-100` → `focus:bg-chip`, texto `text-zinc-700` → `text-foreground/80`, focado → `text-foreground`
  - textos secundários `text-zinc-500/400` → `text-muted-foreground`
  - trilho do segmentado `bg-zinc-100` → `bg-chip`; indicador `bg-white dark:bg-zinc-700` → `bg-card` com a mesma sombra
  - separador → `bg-border`
  - **sem `--acc`** no menu: o acento fica restrito a progresso, estado ativo de navegação e botão principal
  - sombras `drop-shadow` mantidas. A do escuro (`0.5`) funciona sobre `#0B0B0C`
- `text-sm` dos itens fica, porque não há `<input>` e o piso de 16px do iOS não se aplica.

### Manter como está
- A navegação por teclado (setas, Home/End, Esc/Tab fecham), o hover que foca o item e o clique fora que fecha com morph.
- O `ResizeObserver` de altura, que cobre a troca de idioma: os rótulos mudam de largura e de altura.

## Integração

### `features/nav/ProfileMenu.tsx` (novo)
Faz a ponte entre o app e o componente vendorizado:

```tsx
const ProfileDropdown = lazy(() => import('@/components/kokonutui/profile-dropdown'));

export function ProfileMenu({ themePref, onThemePref, onNavigate }: Props) {
  const { user, logout } = useAuth();
  const { t, i18n } = useTranslation('nav');
  const [armed, setArmed] = useState(false); // primeiro toque já aconteceu

  const trigger = <AvatarButton user={user} onClick={() => setArmed(true)} />;
  if (!armed) return trigger;

  return (
    <Suspense fallback={trigger}>
      <MotionProvider>
        <ProfileDropdown
          defaultOpen
          name={user?.firstName ?? t('runnerFallback')}
          secondary={user?.email ?? t('profileMenu.viaStrava')}
          avatarUrl={user?.profileImgUrl ?? undefined}
          initials={initialsOf(user)}
          theme={themePref}
          onThemeChange={onThemePref}
          language={currentLanguage()}
          onLanguageChange={setLanguage}
          onSettings={() => onNavigate('profile')}
          onSignOut={() => void logout()}
          labels={{ /* t('profileMenu.*') */ }}
        />
      </MotionProvider>
    </Suspense>
  );
}
```

- `AvatarButton` é o markup **idêntico** ao gatilho do componente adaptado: mesmas classes, 44×44, avatar de 34px. Assim a troca do fallback pelo componente carregado não pula nada.
- **`defaultOpen`** (prop nova): no mount, um `useLayoutEffect` chama `openMenu('pointer', 'menu')` uma vez. Com isso o primeiro toque abre o menu com o morph assim que o chunk chega, sem precisar de um segundo toque. Depois do primeiro uso o componente fica montado (`armed` não volta a `false`).
- `setLanguage`/`currentLanguage` são as mesmas funções que a `Sidebar` e a `ProfilePage` já usam. Reaproveitar, não duplicar.
- A troca de tema passa pelo `onThemePref` do `App.tsx`, que já congela as transições na troca.

### `MobileHeader`
- Recebe `themePref`/`onThemePref` (hoje só recebe `activePage`/`onNavigate`). O `App.tsx` passa os dois.
- O `<button onClick={() => onNavigate('profile')}>` com o avatar vira `<ProfileMenu ... />`.
- O header tem `overflow` visível, então o painel absoluto pode sair dele. Ele fica acima do conteúdo pelo `z-50` que o wrapper ganha quando o menu está aberto. **Conferir** que nenhum ancestral entre o header e o `body` cria contexto de empilhamento com `z-index` menor, `transform` ou `view-transition-name` permanentes (ver o aprendizado no CLAUDE.md). O `[data-vt-page]` só ganha nome durante a transição, então não deve atrapalhar.
- Trocar de página com o menu aberto (pelo item Configurações) desmonta o header, e com ele o menu. Isso é esperado.

### `navConfig.ts`
- Tirar a aba `profile` de `MOBILE_TABS`.
- `mobileTabsFor(areas)`: com 1 área, retorna `[]`. Com 2 ou 3 áreas, retorna Hoje + as abas das áreas.
- `MobileTabId` perde `'profile'`. Ajustar `activeTab()` no `MobileChrome`: `'profile'` deixa de ser um caso especial e a função retorna `null`.
- O título do header em `profile` (`t('profile.title')`) fica irrelevante no mobile, porque o header some nessa página (ver abaixo).

### `MobileTabBar`
- Com `tabs.length < 2`, retorna `null`, sem degradê. O `ActiveWorkoutBar` com `aboveTabBar` precisa saber disso: passar `aboveTabBar={!chromeHidden && hasTabBar}`, com `hasTabBar` derivado de `mobileTabsFor(user.enabledAreas).length >= 2`. Senão a barra flutua acima de uma pílula que não existe.
- O padding inferior do conteúdo que reserva espaço pra pílula também precisa olhar `hasTabBar`. Conferir no `App.tsx` onde esse espaço é reservado.

### ProfilePage no mobile: tela cheia com voltar
- `App.tsx` guarda `profileReturnPage: PageId`, gravado no `navigate('profile')` com a página atual. Não é persistido. Num reload direto em `profile` (o `active-page` salvo), o fallback é `'overview'`.
- `ProfilePage` recebe `onExit?: () => void`. Quando `useIsMobile()` é verdadeiro:
  - chama `useHideMobileChrome(true)`, que esconde header e pílula pelo contador já existente;
  - mostra no topo da tela principal (depth 0) uma barra com voltar (`ChevronLeft`, 44×44, `aria-label` "Voltar") + título "Perfil", no mesmo padrão das sub-telas do `DrillStack`. O voltar chama `onExit`, que faz `navigate(profileReturnPage)`.
- As sub-telas internas (EditName, VerifyEmail, metas) continuam com o próprio voltar do `DrillStack`, sem mudança.
- No desktop, `onExit` e a barra não aparecem e nada muda.
- Gesto de voltar do navegador/sistema: o app não usa history e não passa a usar. Mesmo comportamento das outras telas.

## i18n

Novas chaves em `nav.json` (pt/en), num bloco `profileMenu`:

| chave | pt | en |
|---|---|---|
| `menu` | Menu da conta | Account menu |
| `theme` | Tema | Theme |
| `language` | Idioma | Language |
| `settings` | Configurações | Settings |
| `viaStrava` | Conectado via Strava | Connected via Strava |
| `signOut` | Sair | Sign out |
| `hold` | Segure | Hold |
| `keepHolding` | Continue segurando | Keep holding |
| `holdHint` | , pressione e segure para confirmar | , press and hold to confirm |
| `back` | Voltar | Back |

Os rótulos de tema (`common:themeAuto` etc.) e o título do Perfil já existem: reaproveitar.

## Movimento e acessibilidade

- Abrir e fechar por teclado e sob `prefers-reduced-motion` é instantâneo, porque o Kokonut já faz `setInstant`. Conferir rodando com `reducedMotion: 'reduce'` e lendo `getComputedStyle`, não pelo screenshot.
- Nenhum `duration-*`/`transition` novo fora de `motion-safe:` (aprendizado do CLAUDE.md sobre `transition: all`).
- `role="menu"`/`menuitem`/`menuitemradio` + `aria-checked` nos segmentados (já vêm do Kokonut).
- O hold de sair funciona com o teclado (Enter/Espaço segurados) e com o toque (`touch-none`, `setPointerCapture`). Testar no iOS real que o long-press não abre o menu de contexto (`onContextMenu` preventDefault + `select-none`).

## Bundle

- O chunk principal **não** pode passar a incluir `motion`. Medir somando os chunks importados estaticamente pelo entry (aprendizado da Fase 3), antes e depois.
- O `profile-dropdown` vira um chunk próprio, que reaproveita o chunk do Motion já usado pelo `DrillStack`/`MotionProvider`.

## Verificação

1. `npx tsc --noEmit` e `npm run lint` no `client/`.
2. `/run-sotreina` no viewport mobile (390×844), claro e escuro:
   - com 3 áreas: a pílula tem Hoje + Corrida + Treino + Dieta, sem Perfil;
   - com 1 área: não há pílula nem degradê, e o conteúdo não reserva espaço embaixo;
   - tocar no avatar abre o menu no primeiro toque (com o chunk ainda não baixado);
   - trocar o tema com o menu aberto troca na hora, sem borrão, e o menu continua aberto;
   - trocar o idioma refaz os rótulos e o painel ajusta a altura;
   - Configurações abre a ProfilePage em tela cheia, e o voltar retorna à página de origem;
   - conta sem email mostra "Conectado via Strava";
   - segurar Sair por 1,2 s desloga; soltar antes mostra "Continue segurando".
3. Rodar com `reducedMotion: 'reduce'`: sem morph, abertura instantânea.
4. Viewport de desktop (1280): nada mudou.
5. Comparar o tamanho do entry antes e depois.
6. iPhone real (PWA instalado): long-press do Sair sem menu de contexto e sem zoom.

## Como usar o componente (referência rápida)

Depois de adaptado, o componente é controlado e sem estado de domínio:

```tsx
<MotionProvider>
  <ProfileDropdown
    name="Guilherme"
    secondary="guilherme@exemplo.com"
    avatarUrl={url}
    initials="GU"
    theme={themePref}            // 'auto' | 'light' | 'dark'
    onThemeChange={setThemePref}
    language="pt"                // 'pt' | 'en'
    onLanguageChange={setLanguage}
    onSettings={() => navigate('profile')}
    onSignOut={logout}
    labels={labels}              // strings já traduzidas
  />
</MotionProvider>
```

Ele sempre precisa estar dentro de `MotionProvider` (usa `m.*`) e ser importado com `React.lazy` fora de telas que já carregam o Motion.
