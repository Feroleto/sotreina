# Mapa: Plano da semana (backend + iOS)

## Destination

As fases 1–3 de `.plans/plano-semanal-spec.md` **em produção e conferidas no iPhone com uso real**:

- o backend do Plano da semana (Padrão versionado, Ajustes, resolução por data) no Render e com a migration aplicada no Neon;
- o Hoje do app respeitando o plano: status do dia, faixa seg–dom, "Por área" e próximo Treino;
- o editor do Padrão e a folha do dia (Ajustes) no app.

## Notes

- **Este mapa carrega a execução** (decidido com o usuário em 2026-10-25, mesmo modelo dos mapas `app-ios-completo` e `login-app-ios`). Os tickets `task` constroem. Um ticket se resolve com o código pronto, compilando, testado (Kit/servidor) e conferido no iPhone quando tem tela. O `## Answer` diz o que foi feito e o que ficou pendente.
- **Fonte das decisões**: `.plans/plano-semanal-spec.md`. O que está lá foi decidido na entrevista de 2026-10-25, incluindo as quatro "decisões tomadas por mim", que o usuário confirmou. Não se reabre sem o usuário.
- **O vocabulário vem do `GLOSSARY.md`**, não da spec: Plano da semana, Padrão, Ajuste, Dia livre, Folga, Extra e Perdido. A área é **Treino** ("Academia" é só rótulo de tela). A spec ainda diz "exceção", "override", "Descanso hoje" e "Academia". No código e nas strings novas vale o glossário: a UI diz "Dia livre" e "Folga", nunca "Descanso". Nomes de tabela/rota da spec (`PlanOverride`, `/plan/...`) podem ficar, ou passar a `PlanAdjustment`, a critério de quem fizer o backend, desde que seja consistente.
- **Direto no `main`**, sem worktree. O tracker é este `.scratch/plano-semanal/`.
- **Regras de sempre**:
  - O iPhone é de uma sessão por vez: antes de instalar, conferir `ps aux | grep "xtool dev run"`.
  - O usuário commita, e o agente não faz commit.
  - A migration vai pro Neon antes do deploy do backend.
  - Tudo que não desenha tela vai para o `SoTreinaKit`.
  - Ao fechar cada ticket, atualizar `docs/claude/backend.md` / `docs/claude/ios.md`.
- **Skills**:
  - `tdd` para o resolver e as validações do servidor e para o `WeekPlan` do Kit.
  - `grilling` + `domain-modeling` se surgir decisão nova.
  - `run-sotreina` não se aplica: a web fica fora.
- **Tracker**: markdown local. Os tickets ficam em `issues/NN-<slug>.md`, com `Type:`, `Status:` (`open`/`claimed`/`resolved`) e `Blocked by:`.

## Decisions so far

<!-- uma linha por ticket resolvido -->
- [Backend do Plano da semana](issues/01-backend.md): `plans/` com resolver e regras puros, rotas da spec §5, `PlanAdjustment` e `source: ADJUSTMENT` (glossário), desfazer move volta ao Padrão, fixtures reais no Kit; migration só local
- [Produção: migration no Neon e backend no Render](issues/02-producao-backend.md): `add_week_plan` no Neon, commit `9e0062e` no Render, rotas conferidas com conta descartável; `POST /plan/moves` responde 201
- [Kit: WeekPlan e as regras do Plano da semana](issues/03-kit-weekplan.md): modelos + `PlanDate` + `PlanStatus` (estados, faixa, progresso, próximo Treino, destinos de move) + `PatternDraft` + `RoutineAbbreviation` no Kit; sem plano ativo tudo conta como planejado (o Hoje antigo); 403 testes
- [Hoje com o Plano da semana no app](issues/04-hoje-com-plano.md): `PlanStore` no shell, status/faixa seg–dom/"Por área" seguindo o plano, próximo Treino pelo plano; área em posição fixa na faixa, linha "Dia livre" também sob a Dieta; conferência da aba Treino passou pro editor
- [Editor do Padrão no app](issues/05-editor-padrao.md): `WeekPlanEditorView` (grade, toque longo escolhe Rotina, um `PUT`, grade vazia confirma), entradas no Hoje e em Perfil › Metas; meta de Treino sai dos steppers com plano; conferido com o plano real do usuário
- [Folha do dia: Ajustes no app](issues/06-folha-do-dia.md): `PlanDaySheet` + `PlanChange` no Kit (ações só as que o servidor aceita, palpite otimista), `PlanDaySheetView` pela faixa do Hoje e pelo "Esta semana / Próxima" do editor, fila otimista no `PlanStore`; conferido pelo usuário no iPhone

## Not yet specified

- **Ajustes visuais da faixa seg–dom e da grade do editor** depois do uso real: se o contorno do "planejado futuro" e o pontinho do Extra se leem bem nos dois temas, e se a abreviação da Rotina na bolinha se lê bem (colisões já se resolvem: "Peito" → "Pi", "Pernas" → "Pr", `RoutineAbbreviation`). Hoje vale a spec §6.3/§6.6. Só vira ticket se o [Uso real do Plano da semana](issues/07-uso-real.md) mostrar um incômodo concreto.
- **Toque longo pouco descobrível** no editor: a alternativa (lista de Rotinas abaixo da grade) só entra se o uso real mostrar que o usuário não acha o gesto.

## Out of scope

- **Web** (fase 4 da spec): leitura do plano no `TodayPage`, faixa seg–dom, folha do dia e editor. Até lá a web ignora o plano, e a divergência foi aceita pelo usuário. Volta como esforço novo.
- Lembretes, aderência histórica, alvos de corrida, Dieta planejável, várias sessões por Área no mesmo dia, arrastar entre dias e semanas além da próxima (spec §9).
