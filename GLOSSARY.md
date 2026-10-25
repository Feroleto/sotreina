# SoTreina

Plataforma pessoal que reúne corrida, musculação e dieta de um atleta num lugar só, na web e no iPhone.

## Language

**Área**:
Um dos domínios que o usuário acompanha: Corrida, Treino (musculação) ou Dieta. O usuário escolhe quais estão ativas.
_Avoid_: módulo, esporte, seção, Academia (é só rótulo de tela do Treino)

### Treino (musculação)

**Rotina**:
A estrutura salva de um treino: exercícios em ordem com metas de séries, repetições e descanso, nunca pesos realizados.
_Avoid_: template, plano de treino, ficha

**Treino**:
Uma execução de musculação num dia, criada a partir de uma Rotina ou livre.
_Avoid_: workout, sessão (quando já finalizado)

**Sessão**:
O Treino ainda aberto, sendo executado agora. Existe no máximo uma por usuário.
_Avoid_: treino ativo, treino em andamento

**Treino livre**:
Treino iniciado sem Rotina.
_Avoid_: treino avulso

**Série**:
Um conjunto de repetições de um exercício dentro de um Treino, com peso e repetições realizados.
_Avoid_: set

**Proposta de série**:
Os valores sugeridos para a próxima Série, derivados da última vez que o exercício foi feito ou da Série anterior.
_Avoid_: sugestão, placeholder

**Descanso**:
A pausa cronometrada depois de uma Série; pode ter duração própria por exercício na Rotina.
_Avoid_: intervalo, timer

**Recorde pessoal (PR)**:
A Série de maior peso já feita num exercício (desempate por repetições); a primeira vez num exercício não é PR.
_Avoid_: melhor marca

### Dieta

**Alimento**:
Um item com valores nutricionais por 100 g, vindo da TACO, da Open Food Facts ou cadastrado pelo usuário.
_Avoid_: comida, produto

**Refeição**:
Um horário configurável do dia do usuário (ex.: Café da manhã, Lanche), que vale para todos os dias e pode se repetir.
_Avoid_: slot, tipo de refeição

**Registro**:
Uma quantidade de um Alimento comida numa Refeição num dia.
_Avoid_: log, entrada

**Medida caseira**:
Uma porção nomeada de um Alimento com peso em gramas (ex.: 1 unidade = 50 g).
_Avoid_: porção padrão

**Refeição salva**:
Uma combinação de Alimentos e quantidades guardada para registrar de uma vez.
_Avoid_: prato, receita

### Corrida

**Atividade**:
Uma corrida importada da Strava.
_Avoid_: corrida (como registro), treino de corrida

**Volta**:
Um trecho de uma Atividade com estatísticas próprias, gravado pelo relógio, detectado ou editado pelo usuário.
_Avoid_: lap, split, parcial

### Metas

**Meta diária**:
O alvo de kcal e macros de um dia na Dieta.

**Meta semanal**:
O alvo de km corridos e de Treinos numa semana. Com Plano da semana ativo, o alvo de Treinos é o número de dias de Treino planejados na semana.

### Plano da semana

**Plano da semana**:
Os dias em que o usuário pretende fazer Corrida e Treino; a Dieta fica de fora, porque vale todo dia. Ele se forma do Padrão e dos Ajustes.
_Avoid_: agenda, cronograma, planejamento

**Padrão**:
O modelo de Plano da semana que se repete toda semana: dia da semana × Área, com Rotina opcional no Treino. Mudá-lo vale de hoje em diante; o passado segue julgado pelo Padrão da época.
_Avoid_: template semanal, modelo, recorrência

**Ajuste**:
Uma mudança do Plano da semana só para uma data: adicionar, mover, trocar a Rotina ou dar Folga. Vence o Padrão, inclusive um Padrão mais novo.
_Avoid_: exceção, override

**Dia livre**:
Um dia em que o Padrão não prevê nenhuma Área.
_Avoid_: descanso (é a pausa entre Séries), dia de folga

**Folga**:
Um Ajuste que tira de uma data uma Área que estava planejada.
_Avoid_: pulo, skip, descanso

**Extra**:
Uma Área feita num Dia livre ou numa Folga. Aparece, mas não conta para a Meta semanal.
_Avoid_: bônus, fora do plano

**Perdido**:
Um dia passado com uma Área planejada que não foi feita. Não passa para o dia seguinte.
_Avoid_: atrasado, pendente (pendente é só o planejado de hoje)
