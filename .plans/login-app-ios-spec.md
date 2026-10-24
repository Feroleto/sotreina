# Spec: Entrada do app iOS (login, cadastro, transição, conta) e conexão Strava pela Corrida

Data: 2026-10-23. Design: Claude Design, projeto `09e94a27-…`, arquivo `Login Transicao.dc.html` ("Bola percorre o pulso").
Base: `ios/Sources/SoTreina/Features/Auth/LoginView.swift` (Form com segmented Entrar/Criar conta e campo de servidor), `.plans/app-ios-completo-spec.md` (§2 dizia "sem Strava no app": **esta spec muda isso**, a conexão Strava passa a existir na Corrida).

## 1. Objetivo

Trocar a entrada do app pela tela do design e deixar o app pronto, no que depende de código, para uma futura submissão à App Store:

- **Entrada só por email/senha** agora. **Sign in with Apple** fica planejado para quando houver o Apple Developer Program pago (fase Apple, §7). A conexão com a Strava **sai da porta de entrada** e vai para a aba Corrida.
- Uma conta criada no app **não precisa da web** em nada: conectar e desconectar a Strava, verificar o email e excluir a conta acontecem dentro do app.

## 2. Decisões (entrevista de 2026-10-23)

| Tema | Decisão |
|---|---|
| Distribuição | Fazer agora o que funciona com Apple ID grátis (xtool, 7 dias). Developer Program pago "mais pra frente": a fase Apple e o checklist da App Store (§7, §8) ficam prontos no papel |
| Botão "Continuar com Apple" | **Escondido** até a fase Apple (nada de botão morto). O layout reserva o lugar dele e do divisor "ou" |
| Cadastro | **Tela empurrada** a partir de "Criar conta", no mesmo estilo. Some o segmented. **Sem "Confirmar senha"** no app (a web mantém) |
| Tema | **Segue o sistema** (o design só mostra o escuro, então a versão clara sai dos tokens Monolito) |
| Animação | Toca **depois do token** (login com sucesso e conta criada), nunca na abertura a frio. Duração mínima de **1,6 s** mantida |
| Reduzir movimento | Crossfade: o login some, a logo aparece completa e parada, sem bola nem expansão, e a próxima tela entra em fade |
| Campo de servidor | **Escondido num gesto**: toque longo na logo abre a sheet "Servidor" |
| Rodapé | Links para Privacidade e Suporte. No cadastro, a frase "Ao criar a conta você concorda com a Política de Privacidade" |
| Verificação de email | **Código de 6 dígitos que não bloqueia** o uso, **no app e na web**. Contas existentes começam **não verificadas**, com aviso no Perfil |
| Apple × conta existente (fase Apple) | Vínculo automático pelo email **só se a conta existente tiver o email verificado**. Sem verificação, a conta Apple é criada separada |
| Conta Apple e a web | Conta Apple não usa a web. Não entra Apple na web nem "definir senha" pelo app |
| Exclusão de conta | **Apaga tudo na hora**, no app (Perfil › Conta), com **confirmação pela senha**. Na fase Apple, a confirmação é refazer o login com a Apple |
| Strava | **A Corrida sem Strava** mostra um estado vazio com o botão oficial "Connect with Strava". Ao conectar, o **sync inicial dispara sozinho** e a Corrida mostra o progresso. **Desconectar** fica em Perfil › Conta |
| Contas só-Strava existentes | Continuam pela web, como hoje: a pessoa adiciona uma senha na web e entra no app com email |

## 3. Telas

### 3.1 Entrar (`LoginView`, substitui o Form)

Layout do design, com o conteúdo ancorado embaixo: a logo "Pulso" com "SoTreina" no topo (112pt abaixo da safe area no design), espaço flexível, depois "Bem-vindo de volta" (30/600) e "Entre para continuar seus treinos." (16, texto secundário).

- **Campos**: email (`.username`, teclado de email, sem autocapitalização) e senha (`.password`) com o botão de olho, como o `PasswordInput` da web. Altura 54, raio 14, fonte 17 (acima do piso de 16 do iOS). No escuro: borda `#2A2A2C` e fundo `#18181A`, conforme o design. No claro: tokens equivalentes do Monolito.
- "Esqueci a senha" alinhado à direita leva ao `ForgotPasswordView`, restilizado no mesmo visual e com o email preenchido.
- **Entrar**: fundo `bg-acc`, texto `acc-fg`. Fica desabilitado com campos vazios e mostra um spinner dentro do botão durante o `POST /auth/token`.
- O lugar do divisor "ou" e de "Continuar com Apple" fica reservado e só é renderizado na fase Apple.
- "Não tem conta? **Criar conta**" leva ao cadastro.
- **Rodapé**: links pequenos para Privacidade (`https://www.sotreina.com/privacidade`) e Suporte (`/suporte`), abertos em `SFSafariViewController` ou `Link`. Ficam abaixo do "Criar conta", com o conteúdo rolando quando o teclado sobe.
- **Erros**: aparecem inline acima do botão, na cor `--neg`. As regras são as de hoje: um 401 limpa a senha e mantém o email. Para uma conta só-Strava, o 401 também mostra o aviso atual (`auth.login.stravaOnly` com link para a web). Esse aviso deixa de ficar fixo no rodapé e só aparece depois de um 401.
- **Teclado**: o Return no email pula para a senha; na senha, envia. O ScrollView usa `scrollDismissesKeyboard(.interactively)`, e a coluna ancorada embaixo sobe com o teclado sem cobrir o botão.
- **Toque longo na logo** abre a sheet "Servidor" com o `TextField` de URL atual (`APIClient.storedBaseURL`), mais "Usar produção" e "Salvar". Ninguém descobre isso sem saber, e o revisor da Apple não vê.

### 3.2 Criar conta (push)

Mesmo visual. Título "Criar conta". Campos: nome (`.givenName`), email e senha (`.newPassword`, para o iOS sugerir uma senha forte e salvar no Keychain), com o mesmo olho. Mínimo de senha igual ao backend (`EntryForm`). Abaixo, a frase de privacidade com link e o botão "Criar conta". Voltar retorna ao Entrar mantendo o email digitado.

**Erros**: 409 (email em uso) mantém os campos. Erro de formulário vem do `EntryForm.registerProblem`, sem o caso `passwordMismatch` no app.

### 3.3 Verificar email (depois do cadastro)

"Confirme seu email" e "Enviamos um código para <email>". Um campo de 6 dígitos com `.oneTimeCode` (o iOS sugere o código lido no Mail) envia sozinho ao completar.

Botões: "Reenviar código", desabilitado por 60 s com contagem, e "Fazer depois", que pula. O sucesso, ou o pulo, dispara a transição (§4) e revela o `AreaPickerView` (conta nova tem `enabledAreas` vazio).

O mesmo componente é reaberto pelo aviso no Perfil.

### 3.4 Transição (§4) → Hoje ou escolha de áreas

### 3.5 Perfil › Conta (novas linhas)

- **Email**: mostra o endereço e o selo "Não verificado" com "Verificar" (abre 3.3 e já pede um código novo). Quando verificado, mostra um check discreto.
- **Strava**: "Conectado" com "Desconectar". A confirmação diz que as corridas importadas da Strava serão apagadas, reaproveitando o texto da web, e chama `DELETE /strava/connect`. Sem conexão, a linha mostra "Conectar", que dispara o mesmo fluxo da §5.
- **Excluir conta**: linha destrutiva no fim. Abre uma tela que explica o que é apagado (treinos, rotinas, dieta, corridas, conexão Strava) e que isso não tem volta, pede a senha e tem o botão "Excluir conta" em `--neg`. Com sucesso, apaga o Keychain, encerra a Live Activity e volta ao Entrar com a mensagem "Conta excluída".

## 4. Transição "bola percorre o pulso"

Fonte: o roteiro do design. Em SwiftUI, o traço usa `Path.trimmedPath(from: 0, to: p)` e a bola é posicionada pelo mesmo `Path`.

**Gatilho**: o token já foi gravado no Keychain (login), ou o cadastro foi concluído e a etapa de código terminou. O que carrega durante a animação é o `GET /auth/me`, mais o primeiro fetch da tela de destino quando ele já estiver encapsulado num store (Hoje). É só isso, sem nada inventado para preencher o tempo.

1. **Saída do login** (320 ms, `cubic-bezier(.4,0,.6,1)`): opacidade 1→0, `translateY(-14)` e `scale(.98)`.
2. **Logo entra** (520 ms, `cubic-bezier(.2,.7,.2,1)`): opacidade, `scale(.92→1)` e `blur(6→0)`. A logo tem 168pt, com "SoTreina" (30/600) abaixo. O traço-base fica a 18% de opacidade, e a bola parada no início da linha.
3. **Percurso**: 650 ms depois que a logo surge, a bola segue o traço com easeInOutQuad e "acende" a linha atrás dela. A duração mínima é de 1600 ms. Enquanto o carregamento não terminar, a bola segura em **88%** e só desacelera, sem parar de forma brusca. A velocidade máxima de recuperação vem do design (`dt / (minDur*0.3)`). O caminho da bola vai além do traço visível (`…h12` contra `h4`) até o ponto final da logo.
4. **Confirmação**: pulso da bola até 1,3× em 320 ms, ease-out.
5. **Expansão** (380 ms depois): um círculo mostarda centrado na bola cresce até cobrir a tela (650 ms, `cubic-bezier(.65,0,.35,1)`). A tela de destino entra por baixo e o círculo some em fade (320 ms). O destino entra com `translateY(12)` e opacidade (400 ms, ease-out).

**Falhas durante o carregamento**: se o `/auth/me` falhar por rede, a bola fica segurando em 88% até um timeout de 10 s. Depois disso, a logo some e o Entrar volta com "Não foi possível conectar". O token fica guardado, e o próximo "Entrar" tenta de novo. Um 401 nesse ponto (caso raro) volta ao Entrar sem token.

**Reduzir movimento** (`accessibilityReduceMotion`): o login some em fade (200 ms), a logo aparece completa, já acesa e com a bola no ponto final. Quando o carregamento termina, sem mínimo de 1,6 s, a logo sai e o destino entra em fade.

**Tema**: o fundo e o traço seguem o tema (traço `#F2F1EE` no escuro, `#141414` no claro). A bola e a expansão usam sempre `acc`. Mostarda sobre fundo claro é o caso a conferir no iPhone.

**Implementação**: um `EntryTransitionView` com estado próprio (`TimelineView(.animation)` para o percurso, porque o progresso depende do relógio e de uma condição externa, e não de uma curva fixa), mais animações SwiftUI comuns para as etapas 1, 2, 4 e 5. A lógica de progresso (`p` em função de `t`, `loaded`, `minDur` e do teto de 88%) vai para o `SoTreinaKit` como função pura testada (`EntryProgress.step`), porque é o único pedaço com regra.

## 5. Strava pela Corrida

### 5.1 Estado vazio

A aba Corrida com `hasStravaAccount == false` mostra uma ilustração ou ícone, "Conecte a Strava para ver suas corridas" e uma linha sobre o que é importado. Embaixo, o botão oficial **Connect with Strava**: o asset de `client/src/assets/strava/` copiado sem alteração, com 48pt e a variante clara ou escura conforme as guidelines.

### 5.2 Fluxo OAuth no app

O app não tem cookie de sessão, então o `GET /strava/connect` da web não serve. Fluxo novo:

1. `POST /strava/connect/start` (Bearer, `AuthGuard` e `AccountThrottlerGuard`) devolve `{ url }`. O `state` é um **JWT assinado** de vida curta (10 min) com `{ sub, tv, purpose: 'strava-connect', client: 'ios', nonce }`. Ele substitui o cookie `oauth_state`, porque a assinatura amarra o callback ao usuário que pediu.
2. O app abre a `url` numa `ASWebAuthenticationSession` com `callbackURLScheme: "sotreina"` e `prefersEphemeralWebBrowserSession = false` (aproveita o login Strava do Safari).
3. `GET /strava/auth/callback`: quando o `state` é um JWT válido com `purpose: 'strava-connect'`, o callback confere o `tv` contra o banco (mesma regra do `authenticate()`), chama `handleCallback(code, sub)` e **dispara o sync da conta** (fire-and-forget, respeitando o lock `isSyncing`). Em seguida redireciona para `sotreina://strava/connected?status=ok|conflict|error`. Sem JWT, segue o caminho atual do cookie, sem mudança para a web.
4. O app lê o `status`. Com `ok`, recarrega o `/auth/me` e a Corrida vira o progresso. Com `conflict`, mostra "Essa conta Strava já está ligada a outro usuário". Cancelar a sheet não mostra nada.

`STRAVA_REDIRECT_URI` não muda. O callback continua passando pela Vercel, e só o destino do redirect final é diferente.

### 5.3 Primeiro sync no app

Porta o essencial do `FirstSyncPage`: polling de `GET /strava/sync/status` a cada 2 s, enquanto a aba está visível, com contador "N de M atividades", `etaSeconds` e a fase `rate_limited` mostrada como espera ("A Strava pediu uma pausa, retomando em mm:ss"). Quando termina, recarrega o `RunStore`. Sair da aba não cancela nada (o sync roda no servidor). Se o sync falhar, a Corrida mostra o que já chegou, e o cron de 6 h completa o resto.

### 5.4 Desconectar

Perfil › Conta (§3.5) chama `DELETE /strava/connect`. Se a resposta trouxer `accountDeleted: true` (não ocorre para conta com senha, mas o contrato permite), o app trata como logout.

## 6. Backend

| Mudança | Detalhe |
|---|---|
| `POST /auth/register-token` | O mesmo que o `register`, mas devolve `{ token, user }` sem cookie, espelhando o `/auth/token`. Hoje o app faz `register` e depois `token`, que são duas chamadas e dois baldes de 5/min. Mesmo throttle |
| Verificação de email | `User.emailVerifiedAt DateTime?`. Tabela `EmailVerificationCode` (`userId`, `codeHash` SHA-256, `expiresAt` +10 min, `attempts`, `consumedAt`), no molde do `PasswordResetToken`. `POST /auth/email/send-code` (Bearer ou cookie, 1 por 60 s e 5 por hora por conta) e `POST /auth/email/verify {code}` (5 tentativas por código, depois o código é invalidado). O `register` envia o primeiro código (best-effort, `EmailService`, template novo `verify-email.template.ts`). `MeResponse` ganha `emailVerified: boolean`. O reset de senha concluído com sucesso **também** marca o email como verificado, porque prova posse do endereço |
| Trocar email | Não existe hoje. Se vier a existir, zera `emailVerifiedAt` |
| `POST /strava/connect/start` + callback | §5.2 |
| `DELETE /users/me {password}` | Confere a senha com argon2 (401 se errada, sujeito ao throttle de 5/min). Antes de apagar: revoga o token Strava (best-effort, mesma rotina do `disconnectAccount`). Depois, numa transaction: `purgeStravaData`, apagar `Food`/`Exercise` com `source` CUSTOM ou USER criados pelo usuário (com `SET NULL` virariam linhas órfãs e invisíveis) e apagar o `User` (o resto cai em cascade). Responde 204. Teste de integração confere que nenhuma linha com aquele `userId` sobra em nenhuma tabela |
| Migration | `add_email_verification`: DDL puro, coluna nullable e tabela nova. Todas as contas existentes ficam `null` (não verificadas), por decisão |

**Web (fatia vertical)**: o cadastro da `LoginPage` ganha a etapa de código (pulável, mesmo texto). O Perfil ganha o aviso "Email não verificado" com "Verificar". A exclusão de conta **não** entra na web nesta spec. Contas só-Strava já são apagadas ao desconectar.

**Pré-requisito de produção**: `RESEND_API_KEY` e `EMAIL_FROM` no Render, pendentes desde 2026-07-28. Sem elas, o código de verificação nunca chega.

## 7. Fase Apple (quando houver Developer Program pago)

Planejada, sem implementação agora. Sign in with Apple **não funciona** com Apple ID grátis, porque a capability exige time pago.

- **Spike primeiro**: confirmar se o xtool aplica o entitlement `com.apple.developer.applesignin` e se o `ASAuthorizationController` funciona no build dele (mesmo cuidado do App Group e das App Intents).
- **Botão**: `SignInWithAppleButton` oficial (`.signIn`, estilo `.white` no escuro e `.black` no claro, altura 54 e raio 14 iguais ao "Entrar"). O texto "Continuar com Apple" do design corresponde ao rótulo localizado `.continue`. Não desenhar o botão à mão.
- **Backend**: `POST /auth/apple { identityToken, authorizationCode, firstName? }`. Valida o JWT pelo JWKS da Apple (`iss`, `aud` = bundle ID, `exp`, nonce). Troca o `authorizationCode` por um refresh token (`client_secret` = JWT assinado com a chave `.p8`), guardado para revogação. Tabela `AppleAccount { sub @unique, userId, email, isPrivateEmail, refreshToken }`. Resolução da conta:
  1. Se o `sub` já for conhecido, faz login.
  2. Se o email for real **e** já pertencer a um `User` com `emailVerifiedAt`, vincula a esse `User`.
  3. Senão, cria um `User` novo, com `emailVerifiedAt` = agora (a Apple verificou). `firstName` vem só no primeiro login, então é gravado nessa hora.
  4. Se o email existe mas não está verificado, cria uma conta separada **sem** email (`email` é único). A mensagem sugere entrar com a senha e verificar o email se a pessoa quiser unificar.
- **"Ocultar meu e-mail"**: registrar `contas@sotreina.com` / `sotreina.com` no Private Email Relay do portal da Apple. Sem isso, o Resend não entrega no endereço `@privaterelay.appleid.com`.
- **Exclusão de conta Apple**: reautenticação com a Apple em vez de senha, e o backend **revoga** o token (`POST https://appleid.apple.com/auth/revoke`), como a Apple exige.
- **Web**: sem Sign in with Apple (decisão: conta Apple é só do app). Uma conta Apple que queira a web fica fora de escopo.
- **Diretriz 4.8**: só se aplica se o app oferecer login de terceiros. O SoTreina oferece só email e Apple, então está coberto.

## 8. Checklist da App Store (fase paga, além da §7)

- [ ] Exclusão de conta no app (§3.5): **feita nesta spec**
- [ ] URL da política de privacidade no App Store Connect e link dentro do app (rodapé e Perfil): o link no app **é feito nesta spec**
- [ ] App Privacy labels: email, nome, dados de saúde e fitness (treino, dieta, corrida), sem rastreamento
- [ ] `PrivacyInfo.xcprivacy` (manifesto de privacidade): `UserDefaults` (motivo `CA92.1`), sem tracking. Conferir se o xtool copia o arquivo para o bundle
- [ ] `ITSAppUsesNonExemptEncryption = false` no Info.plist
- [ ] Conta demo para o revisor (email/senha com dados de exemplo de treino e dieta, sem Strava)
- [ ] Campo de servidor fora do caminho (§3.1): **feito nesta spec**
- [ ] `NSCameraUsageDescription` também em EN (exige `InfoPlist.strings` no bundle principal; ver a limitação no Info.plist atual)
- [ ] Guidelines de marca da Strava respeitadas (já previstas na spec completa)
- [ ] **Pesquisa em aberto**: se o xtool consegue assinar com certificado de distribuição e gerar um `.ipa` para upload (Transporter/`altool`), ou se o envio exige um Mac (Xcode Cloud ou um Mac emprestado só para o upload)

## 9. Fora de escopo

Login Strava no app; Apple na web; "definir senha" no app; troca de email ou senha logado; exclusão de conta pela web; carência antes de excluir; verificação bloqueante; animação na abertura a frio.

## 10. Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| `ASWebAuthenticationSession` não funcionar no build do xtool | Sem conexão Strava no app | Spike no início. É um framework comum, sem macro nem metadado de Xcode, e o risco é baixo |
| Redirect https → `sotreina://` bloqueado pela Vercel ou pelo navegador | O callback não volta ao app | O redirect sai do Render (302 com `Location: sotreina://…`). Testar no iPhone, porque a `ASWebAuthenticationSession` intercepta o scheme |
| Email de código não chega (Resend sem env no Render, ou spam) | Verificação travada | Não é bloqueante, e há "Reenviar". Configurar o Render antes do deploy |
| Mostarda expandindo sobre o claro parecer estranha | Transição feia no tema claro | Conferir no iPhone. Se incomodar, a expansão no claro usa `acc` com fade mais cedo |
| Usuário bloqueado pelo throttle de 5/min ao errar a senha na exclusão | Precisa esperar 1 min | Aceito |

## 11. Ordem de implementação

1. **Backend**: migration de verificação, `register-token`, endpoints de código, `DELETE /users/me`, `connect/start` e o ramo JWT do callback, com testes. Aplicar a migration no Neon antes do deploy do backend (DDL compatível com o código antigo).
2. **Kit**: `EntryProgress` (percurso), modelos novos (`emailVerified`, respostas), `EntryForm` sem confirmação no app, e testes.
3. **App**: Entrar, Criar conta, Verificar, transição, sheet de servidor, Perfil › Conta (email, Strava, excluir), Corrida vazia, OAuth e primeiro sync.
4. **Web**: etapa de código no cadastro e aviso no Perfil.
5. **Validação no iPhone**: claro e escuro, Reduzir movimento, rede lenta (Network Link Conditioner, para ver a bola segurar em 88%), senha errada, 409, conectar a Strava do zero numa conta nova, desconectar e excluir conta.

## 12. Paridade web ↔ app

Atualizar a tabela de paridade da spec completa (§9): conexão Strava, verificação de email e exclusão de conta passam a existir no app. A exclusão existe **só** no app.
