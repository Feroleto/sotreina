# Teste: app abre numa tela via `dvt launch --env`

Type: task
Status: resolved
Blocked by: 07

## Question

O `pymobiledevice3 developer dvt launch com.feroleto.sotreina --env SOTREINA_SCREEN=<tela> --env ...` (pelo mesmo túnel `--userspace` do screenshot) abre o app passando variáveis de ambiente que o app consegue ler? Se sim, um modo de validação só em build de debug (tela, tema, idioma vindos do ambiente) deixa o agente percorrer o checklist sozinho, sem o usuário navegar no iPhone. Depende da navegação existir pra ter telas endereçáveis. Resultado no `ios/README.md`; se passar, a decisão 4 de [Formato da validação visual por fase](12-validacao-visual.md) muda pra "o agente navega".

## Answer

**Passou.** Testado em 2026-10-22 (iPhone 15, iOS 27.0.1, pymobiledevice3 pelo túnel `--userspace`, sem root).

- `pymobiledevice3 developer dvt launch --userspace --env K=V XTL-KBVDP58W3Z.com.feroleto.sotreina` encerra a instância aberta e abre o app em ~5 s, e **as variáveis chegam ao processo**. Pra provar isso sem mexer no código (o [Strings das telas em PT/EN](15-strings-telas.md) está reescrevendo o app em paralelo), usei uma variável que o próprio iOS lê: com `CFNETWORK_DIAGNOSTICS=3`, o log do processo teve ~200 linhas `CFNetwork Diagnostics`. No controle sem a variável, não teve nenhuma do processo novo. O `ProcessInfo.processInfo.environment` lê o mesmo `environ`.
- O bundle ID tem que ser o que o xtool instala (`XTL-<team>.`), não o do `xtool.yml`.
- As variáveis valem só pra esse lançamento. Abrir pela Tela de Início depois disso abre o app sem elas.
- O `deploy.sh` builda em debug por padrão, então um modo atrás de `#if DEBUG` existe no app instalado.
- Feito: `ios/scripts/launch.sh [CHAVE=VALOR ...]` e a seção "Abrir o app com variáveis de ambiente" no `ios/README.md`.

**Consequência para a decisão 4 do [Formato da validação visual por fase](12-validacao-visual.md)**: o agente pode navegar sozinho, mas só depois que o app ler as variáveis. Isso virou o ticket [Modo de validação por variáveis de ambiente](16-modo-validacao-env.md). Até ele fechar, quem navega continua sendo o usuário.

Não testado: lançar com o iPhone bloqueado (o screenshot precisa da tela desbloqueada de qualquer jeito).
