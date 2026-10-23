# Unidades km/mi e kg/lb (backend + web + Kit)

Type: task
Status: resolved
Blocked by:

## Question

Implementar a preferência de unidades da spec §6.1: `User.distanceUnit` (`KM`/`MI`) e `User.weightUnit` (`KG`/`LB`) no `PATCH /users/me` e no `MeResponse`; o seletor real no Perfil da web e as telas de corrida e academia da web respeitando a preferência; e `UnitConversion` no `SoTreinaKit` com testes (arredondamento de exibição, passos ±2,5 kg / ±5 lb). O banco continua em km e kg, e a comida em gramas.

## Escopo decidido com o usuário (2026-10-22, registrado por outra sessão)

- **Análise da corrida continua em km** (página desligada no menu e fora do app); adaptar quando voltar ao menu. Registrar como pendência na resposta.
- **Editor de voltas**: com `MI`, o tamanho da volta por distância é **digitado em mi** e convertido na borda (o servidor continua recebendo metros); a distância de cada volta é exibida em mi.
- **Rótulos que nomeiam distâncias fixas não mudam**: "Km N" das voltas (splits da Strava são por km) e os nomes dos recordes ("5k", "1 mile", "Half-Marathon"). Só distância e pace medidos convertem.

## Answer

Feito em 2026-10-22, conforme a spec §6.1. O banco continua em km e kg, e a comida em gramas.

- **Backend**: enums `DistanceUnit` (`KM`/`MI`) e `WeightUnit` (`KG`/`LB`), colunas `User.distanceUnit`/`weightUnit` com default `KM`/`KG`; migration `20261022223215_add_unit_preferences` (DDL puro, aplicada no Postgres local; **pendente no Neon**, antes do deploy do backend). O `PATCH /users/me` aceita os dois campos (`parseDistanceUnit`/`parseWeightUnit`, 400 para qualquer outro valor) e o `GET /users/me` e o `MeResponse` (`/auth/me`, login, token) os devolvem. Testes de DTO e de service.
- **Web**:
  - `lib/units.ts` guarda a preferência em estado de módulo, alimentado pelo `AuthProvider` (mesmo idioma do `currentIntlLocale()`).
  - `formatDistance`/`formatPace`/`formatPaceValue` passaram a converter. Strings i18n levam `{{unit}}`, e um script conferiu que toda chave usada recebe `unit`.
  - Corrida: Hoje, Atividades, Visão geral, detalhe, calendário, recordes, tênis, onboarding e metas semanais (inteiros, que sobrevivem à ida e volta km↔mi).
  - Musculação: entrada de série, sugestões, histórico, detalhe, PR, resumo e volume (`t` ou `k lb`).
  - Perfil: seletores km/mi e kg/lb, cada um só com a área ligada (`lib/useUnits.ts`, save otimista).
  - 22 testes novos em `lib/units.test.ts`.
- **Kit**: `UnitConversion.swift` (ida e volta, arredondamento de exibição, passos ±2,5 kg / ±5 lb via `stepped`, volume) e `Me.distanceUnit`/`weightUnit`, que decodificam sem os campos (backend antigo ou cache). 11 testes em `UnitConversionTests`.
- **Conferido**: `tsc`, 584 testes do servidor, build da web e 121 testes, 81 do Kit. Screenshots com MI/LB injetados no `/auth/me` (só leitura) em Hoje, Corrida (mobile e desktop), Treino e Perfil. Uma instância temporária do `dist/` confirmou o `GET` e o 400.

**Pendente / decidido de passagem**:
- **Análise e editor de voltas da web ficam em km** de propósito: passam `'KM'` fixo, porque zonas de pace e tamanho de volta são métricos. Revisitar com a Fase C.
- **App iOS ainda mostra kg** na sessão e no resumo: o Kit está pronto, mas aplicar na UI cabe ao Perfil (lê a preferência) e à Fase T. Até lá, quem escolher lb vê lb na web e kg no app.
- A instância de dev local na porta 3000 rodava código antigo (dois `nest start --watch` disputando a porta) e precisa ser reiniciada.
- Não conferido no iPhone: nada deste ticket muda a UI do app.
