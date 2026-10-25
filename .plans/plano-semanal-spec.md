# Plano semanal — spec

> Entrevista em 2026-10-25. Prioridade: **backend + app iOS**. A web fica pra uma fase posterior e, até lá, **ignora o plano** (decisão do usuário).

## 1. Problema

O Hoje (`TodayView` no iOS, `TodayPage` na web) trata Corrida, Academia e Dieta como pendentes **todo dia**. Ninguém treina as três coisas sete dias por semana, então o status mente na maioria dos dias e as barras dos "últimos 7 dias" nunca fecham. O usuário quer montar a semana dele (ex.: academia seg/qua/sex, corrida ter/qui/sáb) e o Hoje passa a cobrar só o que foi planejado.

## 2. Decisões fechadas

| Tema | Decisão |
|---|---|
| Recorrência | **Padrão semanal fixo + exceções por data** |
| Dieta | **Sempre diária**: fica fora do plano, conta como planejada todo dia |
| Detalhe do dia | Área (Corrida/Academia) + **rotina opcional** na Academia. Corrida é só "corrida" |
| Por dia | Corrida e Academia podem cair no mesmo dia, **no máximo uma de cada** |
| Dia sem plano | A área **some** do status. Se a pessoa faz mesmo assim, aparece como **Extra** |
| Meta semanal de treinos | Com plano ativo, **vem do plano** (dias de academia planejados na semana, já com exceções) e o stepper some no iOS. Meta de km continua independente |
| Dia perdido | Fica **perdido**, não arrasta. Treino feito noutro dia é Extra (a menos que a pessoa adicione aquele dia no plano antes) |
| Exceções | Mover um dia, pular/folga, adicionar, trocar a rotina |
| Retroativo | Nos dias **já passados da semana atual**, só **Pular** (e desfazer um pulo). Mover/adicionar/trocar só de hoje pra frente |
| Janela editável | **Semana atual + próxima** |
| Editar o padrão no meio da semana | **O passado congela.** O padrão novo vale de hoje em diante (hoje incluso). Precisa de histórico completo: padrão versionado por data de vigência |
| Exceções × padrão novo | Exceções **continuam valendo**: são decisões explícitas pra uma data e vencem qualquer padrão |
| Rotina diferente da planejada | **Qualquer treino finalizado cumpre** o dia. A rotina planejada é só sugestão e atalho do Iniciar |
| Próximo treino / Iniciar | **Segue o plano** (ver §6.4) |
| Sem plano (todo mundo hoje) | Comportamento atual + **convite discreto** "Planeje sua semana" |
| Barras do Hoje | Saem os "últimos 7 dias" móveis. Entra a **semana seg–dom** corrente, com **feito × planejado** por dia e o futuro planejado visível |
| "Por área" · Academia | "**2 de 3 planejados**" + barra; extras no detalhe ("+1 extra"), sem entrar no numerador |
| "Por área" · Corrida | Barra segue **km/meta**; o subtítulo vira "2 de 3 corridas planejadas" |
| Extra | Visível no status/faixa e no "+N extra", **não conta** pra meta |
| Desligar o plano | **Grade vazia = sem plano.** As versões antigas ficam guardadas |
| Áreas desligadas | O plano só mostra áreas ligadas. Entradas de área desligada **ficam guardadas mas são ignoradas**. Só-Dieta não tem plano |
| Onde fica a regra | **O servidor resolve** "o que está planejado na data X". O cliente só cruza isso com o que foi feito |
| Editor iOS | **Grade área × dia**. Toque liga/desliga, **toque longo** na bolinha de Academia escolhe a rotina |
| Exceção iOS | **Tocar no dia** da faixa semanal do Hoje abre uma folha do dia |
| Pular | **Por área**, com o atalho "Folga o dia todo" quando há duas áreas planejadas |
| Mover | Destino = hoje ou futuro, na semana atual ou na próxima, **sem colidir** com a mesma área já planejada. A rotina vai junto |
| Lembretes | **Fora desta entrega** |
| Design | **Sem Claude Design**: Monolito direto em cima dos componentes existentes |

### Decisões tomadas por mim (revisar se discordar)

- **Salvar o plano no iOS também grava `User.weeklyWorkoutsGoal`** = número de dias de academia do padrão (só quando há ≥ 1). Assim a web, que ignora o plano, mostra uma meta coerente no "Por área" sem nenhuma mudança de código. Exceções não mexem nesse valor, e esvaziar o plano mantém o último. Um `PATCH /users/me` vindo da web continua aceito e é sobrescrito no próximo save do plano.
- **Exceções só existem com plano ativo.** Sem padrão vigente, a faixa semanal não abre a folha do dia. Evita um "plano feito só de exceções" sem regra clara pra meta.
- O convite "Planeje sua semana" **não é dispensável** na v1. Se incomodar, depois ganha um ×.

## 3. Vocabulário

- **Padrão**: o modelo semanal (dia da semana × área, com rotina opcional). Tem **versões** com data de vigência.
- **Exceção**: um ajuste numa data específica que substitui o padrão pra uma área.
- **Plano ativo numa data**: a versão vigente nessa data tem ≥ 1 slot.
- **Estado de uma área num dia** (derivado no cliente): `done` (planejado e feito), `pending` (planejado, hoje, não feito), `missed` (planejado, passado, não feito), `upcoming` (planejado, futuro), `skipped` (pulado por exceção), `extra` (feito sem estar planejado, ou num dia pulado), `rest` (nada planejado, nada feito).

## 4. Modelo de dados (Prisma)

Migration `add_week_plan`, **DDL puro** (tabelas novas, nenhuma coluna existente muda), compatível com o código antigo.

```prisma
enum PlanEntryState {
  PLANNED
  SKIPPED
}

model WeekPlanVersion {
  id            String         @id @default(cuid())
  userId        String
  user          User           @relation(fields: [userId], references: [id], onDelete: Cascade)
  /// first local day this version applies to
  effectiveFrom DateTime       @db.Date @map("effective_from")
  createdAt     DateTime       @default(now()) @map("created_at")
  slots         WeekPlanSlot[]

  @@unique([userId, effectiveFrom])
  @@map("week_plan_versions")
}

model WeekPlanSlot {
  id         String           @id @default(cuid())
  versionId  String
  version    WeekPlanVersion  @relation(fields: [versionId], references: [id], onDelete: Cascade)
  /// ISO weekday, 1 = Monday … 7 = Sunday
  weekday    Int
  area       Area             // RUN | GYM only (validated)
  templateId String?
  template   WorkoutTemplate? @relation(fields: [templateId], references: [id], onDelete: SetNull)

  @@unique([versionId, weekday, area])
  @@map("week_plan_slots")
}

model PlanOverride {
  id            String           @id @default(cuid())
  userId        String
  user          User             @relation(fields: [userId], references: [id], onDelete: Cascade)
  date          DateTime         @db.Date
  area          Area             // RUN | GYM only
  state         PlanEntryState
  templateId    String?
  template      WorkoutTemplate? @relation(fields: [templateId], references: [id], onDelete: SetNull)
  /// the two halves of a move point at each other's date
  movedFromDate DateTime?        @db.Date @map("moved_from_date")
  movedToDate   DateTime?        @db.Date @map("moved_to_date")
  createdAt     DateTime         @default(now()) @map("created_at")
  updatedAt     DateTime         @updatedAt @map("updated_at")

  @@unique([userId, date, area])
  @@map("plan_overrides")
}
```

Notas:
- **Datas são dias locais** (`@db.Date`, sem fuso). O "hoje" do usuário sai do `X-Time-Zone`, que o `APIClient` do iOS já manda (`@CurrentTimeZone()` + `common/timezone.ts`). O CLAUDE.md diz que o app não manda, mas está desatualizado: `APIClient.swift:145` manda.
- **Uma versão por dia**: salvar o padrão duas vezes no mesmo dia substitui os slots da versão de hoje (`@@unique([userId, effectiveFrom])`), não cria outra. Salvar um padrão idêntico ao vigente é no-op.
- **Grade vazia** = uma versão com zero slots (desliga dali em diante, o passado continua julgado pelas versões antigas).
- **Rotina apagada**: `SET NULL` nos dois lugares vira "qualquer rotina". Pinar com um teste que lê o `migration.sql` (mesmo padrão do `Workout.templateId`).
- **Exclusão de conta**: cascade por `userId` (e por `versionId` nos slots). A integração `test/users/account-deletion.integration.test.ts` confere toda tabela, então precisa conhecer as três novas.
- Os services seguem o padrão do projeto: `new PrismaClient()` próprio, validação manual em `dto.ts`, posse de `templateId` checada pelo `WorkoutTemplatesService` (injeção, não um `findFirst` duplicado, mesmo raciocínio do `MealsService.assertOwned`).

## 5. Backend (`server/src/plans/`)

`PlansModule`: `PlansController`, `PlansService`, `plan-resolver.ts` (função pura, testada sem banco), `dto.ts`. Tudo atrás de `AuthGuard`. Recurso de outro usuário responde 404.

### 5.1 Resolução (`plan-resolver.ts`)

Pra cada data `d` e área `a ∈ {RUN, GYM}`:
1. Existe `PlanOverride(d, a)` → o estado dela (`PLANNED` com `templateId`, ou `SKIPPED`), `source: OVERRIDE`.
2. Senão, a versão vigente = a de maior `effectiveFrom ≤ d`. Se tem slot `(isoWeekday(d), a)` → `PLANNED` com o `templateId` do slot, `source: PATTERN`.
3. Senão, nada (a entrada é omitida).

`active(d)` = a versão vigente em `d` existe e tem ≥ 1 slot. Com `active = false`, overrides daquela data são ignorados na resposta (não deveria haver, ver §2).

O servidor devolve **todas as áreas**. Quem filtra pelas `enabledAreas` é o cliente, pra que desligar e religar uma área traga o plano de volta intacto.

### 5.2 Rotas

**`GET /plan`** → padrão vigente hoje:
```json
{ "effectiveFrom": "2026-10-20",
  "slots": [{ "weekday": 1, "area": "GYM", "templateId": "c…", "templateName": "Peito" }] }
```
Sem versão nenhuma: `{ "effectiveFrom": null, "slots": [] }`. `templateName` passa pelo `localizedName`? Não: rotina é texto do usuário, vai como está.

**`PUT /plan/pattern`** `{ slots: [{ weekday, area, templateId|null }] }` → mesmo corpo do `GET /plan`.
- `weekday` 1–7, `area` RUN|GYM, sem par `(weekday, area)` repetido, `templateId` só em GYM e do próprio usuário. Violação = 400 (rotina alheia = 404).
- Grava/substitui a versão `effectiveFrom = hoje (fuso do usuário)`. Igual à vigente = no-op.
- Na mesma transaction, se há ≥ 1 slot GYM, `User.weeklyWorkoutsGoal = count(GYM)` (ver "decisões tomadas por mim").
- **Não toca nos overrides.**

**`GET /plan/days?from=YYYY-MM-DD&to=YYYY-MM-DD`** (intervalo ≤ 62 dias, `from ≤ to`, senão 400):
```json
[{ "date": "2026-10-27", "active": true,
   "entries": [{ "area": "GYM", "state": "PLANNED", "source": "PATTERN",
                 "templateId": "c…", "templateName": "Peito",
                 "movedFrom": null, "movedTo": null }] }]
```
Um item por dia do intervalo, mesmo sem entradas (zero-fill, mesmo espírito do `getHistory`). Os 62 dias deixam a porta aberta pra aderência mensal depois, sem endpoint novo.

**`PUT /plan/days/:date`** `{ entries: { RUN?: Entry|null, GYM?: Entry|null } }`, com `Entry = { state: 'PLANNED'|'SKIPPED', templateId?: string|null }`. Chave ausente = não mexe. `null` = desfaz (apaga o override e volta ao padrão). Cobre pular uma área, folga o dia todo, adicionar, trocar rotina e desfazer numa chamada só.

**`POST /plan/moves`** `{ area, from, to }`: numa transaction, `from` vira `SKIPPED` com `movedToDate = to` e `to` vira `PLANNED` com `movedFromDate = from` e a rotina resolvida de `from`.

**Toda mutação devolve a janela resolvida** (`GET /plan/days` da segunda da semana atual até o domingo da próxima, 14 dias), pro cliente substituir o estado sem refetch (mesma convenção do `WorkoutDetail`/`GET /meals`). O `PUT /plan/pattern` é a exceção: devolve o padrão, e o cliente recarrega a janela.

### 5.3 Validações das exceções

Com `hoje` e `semana` no fuso do usuário:
- `date` precisa estar em `[segunda da semana atual, domingo da próxima]` e com plano ativo. Senão 400.
- **`date < hoje`**: só é aceito `SKIPPED` numa área que resolve `PLANNED` pelo padrão, ou `null` desfazendo um `SKIPPED` que **não** faz parte de um move. Qualquer outra coisa é 400. Metades de move no passado são imutáveis.
- `PLANNED` numa data que já tem a área planejada pelo padrão e com a mesma rotina = no-op (não grava override redundante).
- **Desfazer uma metade de move apaga as duas** (e se a outra metade já está no passado, recusa com 400).
- **Move**: `from` precisa resolver `PLANNED` e ser ≥ hoje. `to` precisa ser ≥ hoje, estar na janela, ser ≠ `from` e **não** ter a mesma área planejada. A área precisa ser RUN|GYM.

### 5.4 Throttle e custo

Rotas baratas, só banco, sem chamada à Strava: o throttle global por IP basta, sem `AccountThrottlerGuard`. A resolução cabe em três queries por chamada (versões ≤ `to`, slots dessas versões, overrides no intervalo).

## 6. App iOS

### 6.1 Kit (`SoTreinaKit/WeekPlan.swift`, lógica pura, `swift test`)

- Modelos `Codable`: `WeekPattern`, `PatternSlot`, `PlanDay`, `PlanEntry`, `PlanEntryState`, `PlanSource`. Fixtures reais da API local em `Tests/…/Fixtures/`.
- `PlanStatus.state(area:day:done:today:)` → os sete estados de §3. A Dieta é planejada em todo dia que já começou e `upcoming` no futuro.
- `PlanStatus.week(…)`: as sete colunas da faixa (§6.3) a partir de `[PlanDay]` + o que foi feito. As entradas são as mesmas que o `TodayStatus.buildDays` já usa (atividades, treinos, histórico de dieta).
- `PlanStatus.gymProgress` → `{ planned, doneOnPlanned, extra }` da semana, e o equivalente da Corrida pro subtítulo.
- `PlanStatus.nextGym(days:templates:today:)` (regra de §6.4), em volta do `RoutineFormat.nextRoutine` existente.
- `PatternDraft`: estado do editor (toggle, rotina por slot, `isDirty` contra o vigente, corpo do `PUT`), no mesmo espírito do `RoutineEditor`.
- `MoveTargets`: os dias de destino válidos de um move (ou desabilitados, e por quê).
- Testes espelham os do servidor nos casos de borda: fronteira de versão no meio da semana, override vencendo o padrão novo, move entre semanas, domingo → segunda, DST.

### 6.2 `PlanStore` (app)

Store no shell, como as outras. Carrega `GET /plan/days` da janela (semana atual + próxima) junto do resto do Hoje e recarrega ao voltar pro primeiro plano e na virada do dia. O `GET /plan` só é buscado ao abrir o editor. As mutações **rodam em fila** (mesmo `enqueue` do `WorkoutStore`) e são otimistas, com rollback e um aviso discreto se falharem. O resultado do servidor substitui a janela. Entra no `ResponseCache` como as outras leituras do Hoje.

### 6.3 Hoje (`TodayView`)

**Sem plano ativo**: tudo como hoje, mais uma linha fina abaixo do status: "Planeje sua semana ›" (só com RUN ou GYM ligada). Ela empilha o editor.

**Com plano ativo**:

- **Status do dia (células do topo)**: mostra só as áreas ligadas com `PLANNED` hoje, a Dieta (se ligada) e qualquer `extra` já feito (selo "Extra"). Área `skipped` ou `rest` não aparece. Se não sobra nenhuma célula, uma linha "Descanso hoje · próximo: Qua · Academia" ocupa o lugar da grade.
- **Faixa da semana** (substitui o `LastDays`): título "Esta semana", colunas Seg…Dom, inicial de hoje destacada. Cada coluna empilha um segmento por área relevante naquele dia, na mesma geometria de hoje (20 pt, raio 3):
  - `done` → `fg` cheio (`acc` em hoje)
  - `pending`/`missed` → `border` cheio (o "não fiz" já é o vazio de hoje)
  - `upcoming` → só contorno `border` (o futuro planejado)
  - `extra` → `fg` cheio com um pontinho `acc` em cima da coluna
  - `skipped`/`rest` → um traço neutro curto na base
  - Legenda: "feito · planejado". Com plano ativo, a coluna é **tocável** e abre a folha do dia. Sem plano, a faixa existe (seg–dom com o feito) mas não é tocável.
  - VoiceOver: "Quarta, Academia feita, Corrida planejada, Dieta pendente".
  - O título ganha um botão de calendário à direita que empilha o editor.
- **Por área**:
  - Academia: valor "2 de 3", barra `doneOnPlanned / planned`, detalhe "Planejados esta semana · +1 extra". Com `planned = 0` na semana (tudo pulado), a linha mostra "Sem treinos planejados".
  - Corrida: barra e valor seguem km/meta como hoje, e o detalhe vira "2 de 3 corridas planejadas".
  - Dieta: não muda.
  - O lápis segue abrindo as metas semanais, que passam a ter só a de km com plano ativo (§6.6).
- **Uma área só** (`TodaySingleArea`, ou a mesma tela filtrada que o iOS mostra hoje): respeita o plano. Num dia livre, o status diz "Descanso hoje · próximo: …".
- **Feed**: não muda.

### 6.4 Próximo treino e Iniciar

Com plano ativo, valendo pra célula de Academia do Hoje, o "Próximo treino" do `GymOverviewView` e o selo "Próxima" do `RoutinesView`:
1. Hoje tem GYM `PLANNED` com rotina → essa rotina. "Iniciar" abre ela.
2. Hoje tem GYM `PLANNED` sem rotina → regra atual (`RoutineFormat.nextRoutine`).
3. Hoje não tem GYM (ou já fez) → o próximo dia da janela com GYM planejado: "Qua · Costas" (ou "Qua · Academia" sem rotina). O botão Iniciar continua disponível (treino fora do plano = Extra) e usa a rotina desse próximo dia, ou a regra atual.

Treino aberto ("Continuar") continua tendo prioridade sobre tudo, como hoje.

### 6.5 Folha do dia

Um `.sheet` (detents médio/grande) aberto pelo toque na coluna. Título "Quarta, 29 de out". Uma linha por área ligada (RUN, GYM):

- **Planejada (padrão ou exceção)**: "Academia · Costas" e as ações **Trocar rotina** (só GYM, abre a lista de rotinas + "Qualquer rotina"), **Mover pra…** e **Pular**. Quando a origem é uma exceção, um rótulo pequeno: "ajuste desta semana".
- **Pulada**: "Academia · pulada" + **Desfazer**.
- **Metade de move**: "Movida pra qui" / "Movida de qua" + **Desfazer** (desfaz as duas).
- **Não planejada**: **Adicionar academia** / **Adicionar corrida**.
- Com as duas áreas planejadas, aparece também **Folga o dia todo**.
- **Mover pra…**: chips dos dias de hoje até o domingo da próxima semana. Os inválidos ficam desabilitados ("já tem academia"). A rotina vai junto.
- **Dia passado**: só Pular e Desfazer pulo, e uma nota "Dias passados só podem ser marcados como folga".
- Rodapé: "Editar padrão semanal ›" empilha o editor.
- Dia da semana que vem: navegação ‹ › no topo da faixa? **Não**: a faixa do Hoje mostra só a semana atual. A semana que vem é alcançada pela folha (os chips de mover) e pelo editor, que ganha um seletor "Esta semana / Próxima" pra abrir a folha de um dia da próxima. Mantém o Hoje sobre hoje.

### 6.6 Editor do padrão (`WeekPlanEditorView`)

Empilhado no `NavigationStack` da aba (botão da faixa, convite, rodapé da folha e **Perfil › Metas › "Plano da semana"**). Usa `.hidesFloatingTabBar()` (tem Salvar no rodapé).

```
          S  T  Q  Q  S  S  D
Corrida   ·  ●  ·  ●  ·  ●  ·
Academia  P  ·  C  ·  Pe ·  ·

Seg · Peito   Qua · Costas   Sex · Pernas
Segure um dia de academia pra escolher a rotina
3 treinos por semana

[ Esta semana ]  [ Próxima ]   → dias tocáveis abrem a folha do dia

Mudanças valem a partir de hoje. Ajustes de datas continuam valendo.
                                   [ Salvar ]
```

- Linhas só das áreas ligadas (RUN, GYM). Toque liga/desliga (vibração `.selection`). **Toque longo** numa bolinha de Academia ligada abre a lista de rotinas + "Qualquer rotina". Uma bolinha com rotina mostra a abreviação (1–2 letras do nome).
- VoiceOver: cada bolinha é um toggle ("Academia, segunda, ligada, Peito") com a ação "Escolher rotina".
- O rascunho vive em memória (`PatternDraft`). **Uma chamada só no Salvar** (`PUT /plan/pattern`), depois o `PlanStore` recarrega a janela. Voltar com alteração pendente pede confirmação (mesmo padrão do editor de rotina).
- Esvaziar a grade e salvar desliga o plano. O Salvar avisa antes: "Sem dias marcados, o Hoje volta a cobrar tudo todo dia."
- **Perfil › Metas semanais**: com plano ativo, o stepper de treinos some e entra a linha "Treinos · definido pelo plano (3/semana) ›", que abre o editor. A meta de km não muda.

### 6.7 Validação no iPhone

Destinos novos no `ValidationLaunch`, com dado fixo e sem rede: `weekPlanEditor`, `todayPlanned` (semana com done/missed/upcoming/extra/skipped/move), `todayRestDay`, `planDaySheet`, `planDaySheetPast`. Não há simulador, então a UI só se confere no aparelho.

## 7. Web

**Fase 1: nada.** A web ignora o plano. A divergência é aceita: a web segue mostrando tudo pendente. A meta de treinos dela fica coerente porque o save do plano grava `weeklyWorkoutsGoal` (§2).

**Fase posterior**: portar o §6 (leitura no `todayStatus.ts`, faixa seg–dom, folha do dia e editor), consumindo as mesmas rotas. O `todayStatus.test.ts` ganha os mesmos casos do Kit.

## 8. Fases e ordem de deploy

1. **Backend**: schema + migration `add_week_plan` (DDL) + `PlansModule` + testes (resolver puro, validações de §5.3, integração opt-in, pino do `SET NULL`/cascade, contagem da exclusão de conta). Ordem: `prisma migrate deploy` no Neon → backend no Render. É seguro porque o código antigo não lê as tabelas novas.
2. **iOS leitura**: Kit (`WeekPlan.swift` + testes), `PlanStore`, Hoje com plano (§6.3), próximo treino (§6.4). Pra testar sem editor, o plano pode ser criado via `curl` na API local.
3. **iOS edição**: editor (§6.6), folha do dia (§6.5), linha no Perfil.
4. **Web** (depois).

Atualizar o CLAUDE.md ao fim de cada fase (Backend, App iOS e o "Problemas conhecidos" com a divergência da web).

## 9. Fora de escopo / próximos passos

- Lembretes (notificação local nos dias planejados e não feitos).
- Aderência histórica (% do plano cumprido por mês, sequência de semanas). O modelo já guarda o necessário e o `GET /plan/days` aceita até 62 dias.
- Alvos de corrida no plano (tipo/distância, ex.: "sáb · longão 18 km").
- Dieta planejável por dia.
- Mais de uma sessão por área no mesmo dia.
- Arrastar entre dias na faixa.
- Editar semanas além da próxima.

## 10. Riscos e pontos de atenção

- **Fuso**: toda decisão de "hoje", "passado" e "semana" no servidor depende do `X-Time-Zone`. Sem ele, o fallback é UTC, e às 22h em São Paulo o servidor já acha que é amanhã. O iOS manda, e a web vai precisar mandar quando entrar (já manda, pelo `apiFetch`).
- **Virada da semana**: no domingo à noite, os overrides da "próxima semana" viram "esta semana" sozinhos. O `PlanStore` recarrega na virada do dia.
- **Treino que atravessa a meia-noite**: conta no dia do `startedAt`, mesma regra do `buildDays` atual.
- **Rotina apagada** depois de planejada: vira "qualquer rotina" sem aviso. É aceitável.
- **Toque longo é pouco descobrível**: mitigado pela abreviação na bolinha, pela legenda e pela dica fixa. Se não funcionar no uso real, a saída é a lista de rotinas abaixo da grade (alternativa considerada na entrevista).
