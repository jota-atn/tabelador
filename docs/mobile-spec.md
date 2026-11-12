# Especificação: Tabelador Mobile (Android + Widget)

> Status: **roadmap original completo** (fases 1–10) e um bloco de polimento pós-roadmap já implementado também: itens arquiváveis e vinculáveis a uma única tabela, tela dedicada por tabela, editor do dia repaginado (paleta em lista, toque pra armar, desfazer), grade da semana com swipe entre tabelas/toque longo/linha do agora, navegação/formulários responsivos pra tela larga, exportar/importar backup, dias configuráveis por tabela, e notificação de horário se aproximando. Ver "Depois do roadmap original" pro detalhe de cada um.
>
> Revisão **v2** (2026-08-10): o modelo de dados mudou. O v1 previa cores hardcoded e a grade como matriz de strings cruas. Agora cada célula referencia uma **entidade cadastrada** (disciplina/atividade), com cor própria, e a edição é por arrastar.

## Versões do app

(Não confundir com a "Revisão v2" acima, que é revisão do modelo na spec.)

**Convenção** (`version:` no `mobile/pubspec.yaml`, `X.Y.Z+N`):
- **Major (v2, v3…)**: muda o jeito de usar o app ou o modelo de dados —
  tela principal diferente, migração de dados.
- **Minor (v1.1, v1.2…)**: funcionalidade nova que não mexe no que existe.
- **Patch (v1.0.1…)**: só correção e ajuste pequeno de interface.
- **`+N` (versionCode)** sobe a **cada APK instalado** em algum aparelho,
  mesmo sem mudar a versão — senão o Android recusa a atualização e só
  desinstalando (perde os dados). Com `--split-per-abi` o arm64 vira
  2000 + N.
- **Tag no git** `vX.Y.Z` em cada versão lançada; APK distribuído com a
  versão no nome (`tabelador-v1.1.0-arm64.apk`).

**Branches e PRs** (desde v1.2):
- `master` só recebe o que foi testado no aparelho; a tag sai dela.
- Uma branch por versão minor/major (`v1.2-aba-eventos`, `v1.3-feriados`,
  `v2.0-juncao-tabelas`); patch em `fix/<assunto>`. Sai de `master`.
- Desenvolve e testa na branch → **Pull Request no GitHub** (registro da
  versão: resumo + diff) → merge (merge commit, não squash) → tag em
  `master` → apaga a branch.
- Spec/ideias sem código podem ir direto em `master`.

**Plano**:

| Versão | Conteúdo |
|---|---|
| **v1.0.0** ✅ (tag em `ac25e8b`, 2026-11-11) | grade, widget, notificações, backup, eventos, Google Agenda (ler e gravar), onboarding, card de detalhes |
| **v1.1** ✅ (2026-11-11) | 9 tipos de evento (cor e ícone próprios) + Tarefa (feito, data opcional, aviso de manhã) + página de Tarefas |
| **v1.2** | Aba Eventos (cards por tipo), tipo padrão por agenda do Google |
| **v1.3** | Feriados embutidos (folga/comemorativa, esmaecer aulas, ponto facultativo por tabela) |
| **v1.x** | Particularidades por tipo, uma de cada vez (nota em Prova, Uber/99, link de Reunião, Viagem de vários dias, idade/presente, prioridade de Tarefa) |
| **v2.0** | Junção das tabelas na tela inicial (régua de horas, conflito, vigência, edição pela junção) |
| **v2.1** | Itens tipados — Disciplina primeiro (Histórico, "Cursar de novo") |
| **v2.2** | Classroom nível 1 |
| **v2.x** | Demais itens tipados, integração com o Wellio |
| **v3?** | Reservado pra próxima virada grande (Alexa, se exigir skill com servidor) |

## Ideia

Portar a ideia do `tabelador.py` (script CLI que gera e colore tabelas de horário no terminal) pra um app Android **moderno e limpo**, com um widget de tela inicial pra ver o horário do dia sem abrir o app.

Diferença de postura em relação ao script: no Python, cada célula é uma string digitada e a cor sai de um `dict` fixo. No app, você **cadastra** suas disciplinas e atividades uma vez (nome, sigla, tipo, cor) e depois **arrasta** elas pra dentro da grade.

## Decisões confirmadas

### Plataforma e visual
- **Só Android** por enquanto (sem Mac disponível pra iOS).
- **Material 3** com **cores dinâmicas (Monet)** — via pacote `dynamic_color`, com `ColorScheme.fromSeed` como fallback em aparelhos que não expõem o Monet.
- **Tema claro e escuro** seguindo o do sistema.
- O widget segue as regras de widget do **Android 12+**: cantos arredondados do sistema, fundo adaptativo, redimensionamento responsivo. Alvo de teste: Poco M5 Pro 5G.

### Princípio visual: neutro e minimalista

**Chroma só onde identifica uma disciplina. Todo o resto é neutro.** Essa é a regra que decide qualquer dúvida de UI daqui pra frente.

- **Chrome neutro**: app bar, fundos, cards, navegação e botões usam só a rampa neutra do M3 (`surface`, `surfaceContainer`, `onSurface`, `onSurfaceVariant`). Sem app bar colorida, sem superfície tingida.
- **Material You restrito a acentos interativos** — seleção, FAB, aba ativa, indicador de arraste. A cor dinâmica do sistema não pinta superfícies grandes.
- **Hierarquia por tipografia e espaço**, não por cor: dois pesos, três tamanhos. Onde daria vontade de destacar com cor, destaca-se com peso ou respiro.
- **Poucas linhas**: o `fancy_grid` do script é 100% borda; aqui, espaçamento resolve a separação e fios de `outlineVariant` aparecem só onde a leitura exige — hoje é só o fio entre as colunas dos dias na grade, pra separar cores parecidas coladas sem virar borda em tudo.
- **Estados vazios sem enfeite**: slot livre é espaço em branco com um rótulo discreto, não um card cinza cheio de ícone.

### Dados
- **Múltiplas tabelas nomeadas** (ex: "2026.1", "2026.2"), uma marcada como **ativa**.
- **Biblioteca de itens compartilhada** entre tabelas — "Cálculo II" cadastrado uma vez serve pra qualquer semestre. Um item pode opcionalmente ser **vinculado a uma única tabela** (`tabelaId`) pro caso já sabido, na hora de cadastrar, de algo que não vai reaproveitar — some da paleta de qualquer outra tabela e é apagado junto se a tabela dele for apagada. Também pode ser **arquivado** sem apagar: some da paleta de arrastar mas continua resolvendo nome/cor em qualquer tabela antiga que ainda o referencia. Ver "Depois do roadmap original".
- **Grade**: dias configuráveis por tabela — qualquer subconjunto de domingo a sábado (`Tabela.dias`), segunda-sexta só como padrão de tabela nova; hora inicial, intervalo e quantidade de horários também configuráveis **por tabela** (igual ao script). Ver "Depois do roadmap original".
- **Cor mora na entidade**, não em regra de texto. ALMOÇO e LIVRE viram itens cadastrados como qualquer outro — o `dict cores` hardcoded do Python deixa de existir.

### Cores: paleta curada, não seletor livre

Cada item guarda uma **chave de cor**, não um RGB solto. A chave define uma semente em HCT (hue + chroma) e o app gera a rampa tonal com `material_color_utilities` — que já vem junto do Flutter, não é dependência nova.

Motivo: cor arbitrária de color picker fica ilegível no tema escuro ou briga com a paleta dinâmica do sistema. Hardcodar hex por tema seria 4 valores × 12 cores pra manter em sincronia. Com semente, ajustar um tom é mexer num número, e o widget resolve os mesmos tons na hora de montar o snapshot.

| chave | nome | hue HCT | chroma | uso típico |
|---|---|---|---|---|
| `tomate` | vermelho | 25 | 50 | monitoria, prova |
| `tangerina` | laranja | 58 | 50 | |
| `ambar` | amarelo | 92 | 50 | almoço, pausa |
| `oliva` | verde-oliva | 122 | 50 | |
| `salvia` | verde acinzentado | 145 | **30** | livre |
| `esmeralda` | verde | 174 | 50 | |
| `turquesa` | ciano | 204 | 50 | |
| `oceano` | azul | 240 | 50 | |
| `indigo` | azul-violeta | 272 | 50 | |
| `ametista` | roxo | 312 | 50 | |
| `framboesa` | rosa | 345 | 50 | |
| `grafite` | neutro | 250 | 6 | slot sem importância |

Chroma 50 nas cromáticas, pra parecerem uma família só em vez de um saco de cores avulsas — com **uma exceção deliberada**: `salvia` usa chroma 30.

Motivo da exceção: no aparelho, `oliva` e `salvia` ficaram próximas demais pra separar de relance. Entre amarelo e ciano o olho separa matizes mal, e afastar só o matiz espremeria `oliva` contra `ambar`. Dessaturar dá uma segunda pista além do matiz, e ainda acerta o nome — sálvia é uma erva de verde acinzentado.

Os espaçamentos são irregulares porque grau de matiz em HCT não é distância percebida. Os valores saíram de medir a distância entre todos os 66 pares nos tons 40 e 80 e afastar os piores. O teste `nenhum par de cores fica próximo demais` segura isso contra regressão, com piso de 25 — que é piso de alarme, não meta.

Par ainda apertado, a validar no aparelho: **`esmeralda` × `turquesa` no tema claro** (26,1). No tom 40 verde, ciano e azul saturados convergem pro escuro, e a métrica euclidiana em RGB subestima essa faixa.

### Aplicação da cor: três densidades, à escolha do usuário

Quanta cor cada item carrega é **preferência do usuário**, não decisão fechada da spec. Três opções, todas usando a mesma chave de cor do item — muda só quais tons da rampa entram em jogo.

| nome no app | chave | fundo da célula | texto | filete |
|---|---|---|---|---|
| **Discreto** | `discreto` | `surfaceContainer` | `onSurface` | tom 40 / 80 · 3dp |
| **Suave** *(padrão)* | `suave` | tom 95 / 20 | `onSurface` | tom 40 / 80 · 4dp |
| **Sólido** | `solido` | tom 90 / 30 | tom 10 / 90 | — |

Formato "claro / escuro" nos tons. Em todos os casos o contraste é garantido pelo sistema: são os mesmos pares que o M3 usa pra container e acento, então nenhuma combinação escolhível é ilegível.

**Nomes plainos na interface.** "Filete", "lavagem" e "container" são vocabulário de implementação e não aparecem pro usuário.

**Escolha por miniatura.** A tela de aparência mostra as três como grades semanais em miniatura, não como lista de rádio com texto. O ponto de ser opção é ver o resultado antes de aplicar.

**Preferência global**, uma chave no `shared_preferences` — é ajuste de exibição, não dado do horário, então não pertence à `Tabela`.

Uma opção de 8dp de filete chegou a ser desenhada e foi **descartada**: numa célula de 55dp, 8dp são ~15% da largura, comendo espaço da sigla sem entregar a presença que o preenchimento suave entrega.

**A cor é reforço, nunca a única informação.** A sigla está sempre visível na célula e no widget, em qualquer densidade. Isso importa porque `tomate` e `esmeralda` são praticamente o mesmo tom pra quem tem deuteranopia (~8% dos homens): com a sigla ali, a cor é codificação redundante, não o único jeito de distinguir uma disciplina da outra.

### Destaque de hoje e do horário atual

A grade trata segunda igual a sexta, mas o uso real é abrir o app no meio da quarta. Resolvido **em neutro**, pra funcionar nas três densidades sem competir com a cor dos itens:

- coluna do dia atual sobre superfície levemente elevada (`surfaceContainerHigh`);
- rótulo do dia atual em peso maior;
- rótulo do horário corrente em peso maior e cor de acento. Um marcador ao
  lado do texto foi descartado: disputa largura com ele e estoura assim que a
  fonte do sistema aumenta.

### Sigla obrigatória
Todo item tem **nome completo** e **sigla curta**. A célula da grade semanal tem ~55dp e o widget é ainda mais apertado — ali entra a sigla; o nome completo aparece no editor do dia, no detalhe e na biblioteca.

## Modelo de dados

```dart
/// O que ocupa uma célula: disciplina, atividade, pausa — tudo é Item.
class Item {
  final String id;
  String nome;         // "Cálculo Diferencial e Integral II"
  String sigla;        // "CÁLC II" — usado na grade e no widget
  String tipo;         // "Aula", "Monitoria", "Pausa", "Livre"... texto livre
                       // com autocomplete dos tipos já usados (não é enum fechado)
  String corKey;       // chave da paleta curada: "tomato", "sage", ...
  String? local;       // "Bloco C, sala 204" (opcional)
  String? notas;       // opcional — "professor" não existe mais como campo
                       // dedicado (empurrava o app pro vocabulário de aula);
                       // quem quiser anotar isso usa notas, que é livre
  bool arquivado;      // some da paleta de arrastar, mantém histórico
  String? tabelaId;    // null = compartilhado; senão, exclusivo dessa tabela
}

class Tabela {
  final String id;
  String nome;          // "2026.1"
  int horaInicial;      // default 8
  int intervalo;        // default 2
  int qtdHorarios;      // default 6
  /// 'SEGUNDA'..'SEXTA' -> lista de tamanho qtdHorarios.
  /// Cada posição guarda o id de um Item, ou null se o slot está vazio.
  Map<String, List<String?>> celulas;
  DateTime criadaEm;
  DateTime atualizadaEm;
}
```

**Integridade referencial**: apagar um Item que está em uso não é silencioso — o app avisa em quantas tabelas/células ele aparece e, se confirmado, esvazia essas células.

**Mudar `qtdHorarios`** de uma tabela existente: aumentar preenche com `null`; diminuir avisa quantas células serão perdidas antes de truncar.

### Persistência
`shared_preferences` + JSON, três chaves: `items_json`, `tables_json`, `active_table_id`.

Motivo: escala real é pequena — algumas dezenas de itens e poucas tabelas de ~30 slots. Hive/sqflite seria peso morto. Se um dia entrar histórico ou sincronização, aí se reavalia.

### Snapshot enviado ao widget
Uma chave `today_schedule_json` no `SharedPreferences` nativo (via `home_widget`). O widget é burro de propósito: recebe tudo pronto, sem resolver referência nem calcular cor.

```json
{
  "tableName": "2026.1",
  "week": {
    "SEGUNDA": [
      {
        "time": "8:00-10:00",
        "sigla": "CÁLC II",
        "tipo": "Aula",
        "local": "Bloco C, sala 204",
        "bgLight": "#FFECF0",   "bgDark": "#6A002F",
        "fgLight": "#1A1C1E",   "fgDark": "#E3E2E5",
        "barLight": "#AB365C",  "barDark": "#FFB1C8",
        "barWidthDp": 4
      }
    ],
    "TERÇA": []
  },
  "events": [
    {
      "date": "2026-11-10", "allDay": false,
      "startMin": 600, "endMin": 720, "time": "10:00–12:00",
      "title": "Prova · Sistemas Operacionais", "sigla": "SO", "local": "Bloco C",
      "barLight": "#3A5BA0", "barDark": "#B0C6FF"
    }
  ]
}
```

Cores já resolvidas em hex, porque `RemoteViews` não tem como consultar a paleta do Flutter em runtime.

**Semana inteira, não "hoje"**: o snapshot leva todos os dias da tabela ativa
em `week`, e o lado nativo escolhe o dia de hoje a cada redesenho. Se o
snapshot carregasse só o dia já resolvido, o widget ficaria preso nele até o
Flutter rodar de novo — e o Android redesenha sozinho (`updatePeriodMillis`)
sem acionar o Flutter.

**Eventos** vão em `events` com data absoluta, de hoje até 7 dias à frente; o
nativo filtra os de hoje e intercala com os horários por hora de início (dia
todo primeiro; empate põe o horário antes do evento). Evento aparece como
linha de fundo neutro com barra fina na cor do item vinculado, ou neutra —
RemoteViews não desenha borda tracejada, então o "fantasma" da grade vira
isso. Respeita o mesmo filtro da grade (`Tabela.mostrarEventos`).

O widget **segue a densidade escolhida no app** — se a grade está em Sólido e o widget continua em Discreto, parece defeito. Por isso o snapshot carrega fundo, texto e filete já resolvidos por slot, com `barWidthDp: 0` significando "sem filete". O widget segue burro: pinta o que recebe, sem conhecer densidade nem paleta.

## Telas

1. **Visão semana** (tela inicial) — a grade 5×6 completa em chrome neutro, cada célula ocupada renderizada na densidade escolhida, só leitura no sentido de não arrastar. É a cara do projeto: o `tablefmt='fancy_grid'` do script virando UI. Hoje aparece destacado, e uma linha fina marca a hora atual (proporcional ao expediente da tabela, só em dia útil). Toque num dia abre o editor daquele dia; toque longo numa célula edita só ela, sem entrar no dia inteiro. Com duas ou mais tabelas, arrastar a grade na horizontal troca qual está ativa (mesmo swipe que o editor do dia usa entre dias) — além do seletor no topo.
2. **Tela dedicada de uma tabela** — aberta a partir de um card em Tabelas (ou ao criar uma nova). Mesma grade e mesmo editor de dia da visão semana, mas amarrada à tabela que você tocou, com título fixo em vez de seletor — resolve o card em Tabelas só "ativar" e não levar a lugar nenhum.
3. **Editor do dia** — os horários daquele dia como linhas largas (alvo de toque confortável), paleta de itens logo abaixo, numa lista só que cresce pra baixo (não mais bandeja horizontal com scroll). Preencher um horário tem dois caminhos que convivem: arrastar o item da paleta, ou tocar nele pra "armar" (contorno visível) e depois tocar no horário — mais confiável que arrastar em tela pequena ou dedo grande, e fica armado entre horários/dias pra encaixar o mesmo item várias vezes seguidas. Limpar um horário (arrastando pra fora, ou "Deixar vazio") mostra um snackbar com "Desfazer". Um atalho na própria paleta cria item exclusivo desta tabela sem sair da tela. Navegação entre dias por swipe ou setas.
4. **Biblioteca de itens** — CRUD dos itens: nome, sigla, tipo, cor, local, notas, e o vínculo com uma tabela (compartilhado ou exclusivo de uma). Menu por item com Arquivar/Desarquivar além de Apagar; arquivados ficam numa seção recolhida no fim da lista.
5. **Lista de tabelas** — criar, renomear, duplicar, apagar, marcar como ativa; configurar hora inicial/intervalo/quantidade **e dias** (sete chips, domingo a sábado, pelo menos um sempre marcado). Tocar num card ativa e já abre a tela dedicada dela (item 2). Menu por tabela ganha "Arquivar itens exclusivos": revisão em lote dos itens que só aparecem ali, pré-marcados mas editável (item recorrente tipo Almoço pode ser desmarcado) antes de confirmar. Apagar uma tabela avisa também quantos itens exclusivos dela somem junto; encolher horários ou tirar um dia com célula preenchida soma no mesmo aviso.
6. **Aparência** — escolha da densidade de cor, apresentada como três grades semanais em miniatura; notificações (ver "Notificações" abaixo); exportar/importar backup (ver "Backup" abaixo). Preferência de densidade é global, aplicada na hora e propagada pro widget.

### Notificações
Interruptor "Avisar antes de cada horário" mais um seletor de antecedência (presets de 5 a 60 min, padrão 15) — os dois em Aparência, junto das outras preferências globais. Ligar pede a permissão de notificação do Android 13+ **na hora**, não no início do app sem contexto do porquê; negada, o interruptor não liga e avisa por quê.

Um agendamento recorrente semanal por célula preenchida da **tabela ativa**, no horário do slot menos a antecedência — `NotificationScheduler` (`lib/notifications/`) segue o mesmo desenho do `HomeWidgetSync`: ouve um listener só do `AppState` (dispara em toda mutação, então trocar de tabela ativa ou editar a sigla de um item também conta) e recalcula uma assinatura do que deveria estar agendado, só mexendo no plugin nativo (cancelar tudo, reagendar tudo) se ela mudou de verdade.

**Decisões**: alarme inexato (`AndroidScheduleMode.inexactAllowWhileIdle`), não exato — evita pedir a permissão de "Alarmes e lembretes" (`SCHEDULE_EXACT_ALARM`), mesma lógica que já descartou alarme exato pro refresh do widget. Pode atrasar alguns minutos em segundo plano; aceitável pra um aviso de "está chegando", não pra um compromisso ao segundo. Sem `RECEIVE_BOOT_COMPLETED`: reiniciar o aparelho derruba os agendamentos (comportamento padrão do AlarmManager), e abrir o app de novo reagenda — o resume do app já sincroniza o widget, o mesmo hook agora sincroniza notificação também.

### Backup
Motivo: tudo mora em `SharedPreferences`, e reinstalar o app (inclusive por cima de uma atualização, dependendo de como foi instalada) apaga esses dados sem aviso — não tinha caminho de recuperação.

- **Exportar**: junta itens, tabelas, tabela ativa e densidade num JSON (mesmo formato de `Item.toJson`/`Tabela.toJson`, então é o mesmo parser que já existe) e abre o diálogo nativo "salvar como" (`FilePicker.saveFile`, baseado em SAF) — o usuário escolhe onde salvar. Sem isso, precisaria de permissão de armazenamento; quem grava o arquivo de fato é o sistema, o app só entrega os bytes.
- **Importar**: abre o seletor de arquivo (`FilePicker.pickFile`, filtro `.json`), decodifica e pede confirmação antes de **substituir tudo** — não mescla com o que já existe. Formato inválido (JSON quebrado, ou sem as chaves esperadas) mostra aviso em vez de estourar; segue a mesma regra tolerante do carregamento normal pra tabela ativa que não bate com nenhuma tabela do arquivo (cai na primeira).
- **Dependência**: só `file_picker` — cobre os dois sentidos (`pickFile` e `saveFile`), sem precisar de `share_plus` nem `path_provider`. `share_plus` chegou a ser adicionado e removido na mesma sessão: a versão que resolve junto com `file_picker` recente (≥13.0.0) já migrou pro modelo de Kotlin embutido do Flutter, e o `home_widget` ainda aplica Kotlin Gradle Plugin do jeito clássico — misturar os dois quebra o build (`Unresolved reference` em classes do próprio `share_plus`, não erro de configuração nossa). Ver "Pontos em aberto".

### Interação de arrastar
- `Draggable` / `DragTarget` do Flutter. Long-press pra pegar (300ms), com feedback háptico e um leve aumento de escala no item durante o arrasto.
- Slot ocupado destaca no hover. Soltar ali **troca os dois** — o que estava no destino vai pra origem, em vez de sumir sob o item que chegou. Só quando a origem é outro slot: soltar algo vindo da paleta num slot ocupado apenas substitui (não tem origem pra devolver o antigo).
- **Dois caminhos alternativos, não só um**: tocar num slot vazio/preenchido abre um bottom sheet com a lista de itens (também serve pra limpar); tocar num item da paleta o "arma" pra encaixar num toque de horário, sem abrir sheet nenhuma. Arrastar é o gesto mais direto, mas nunca o único — acessibilidade, dedo grande e telas onde o long-press for menos confiável agradecem.
- Esvaziar um slot: arrastar pra fora, swipe na linha, ou "Deixar vazio" no seletor — os três mostram "Desfazer" depois. Mover (arrastar de um slot ocupado pra outro) não mostra desfazer: a origem não foi apagada, só mudou de lugar.
- Arrastar de um slot pra outro **move** o item dentro do dia.

### Navegação e layout responsivo
A partir de 600dp de largura (a fronteira compacta/média do Material 3, onde um celular deitado cai naturalmente) a barra de navegação debaixo vira barra lateral (`NavigationRail`) — mesmos destinos, só a posição muda. Formulários (cadastro de item, configurar tabela, Aparência) ganham largura máxima de 560dp e centralizam, em vez de esticar campo de texto até a borda numa tela larga. Grade da semana e editor do dia ficam de fora desse limite de propósito: se beneficiam do espaço extra em vez de sofrer com ele.

## Widget de tela inicial

- Mostra **só o dia de hoje** da tabela ativa.
- Fim de semana / dia sem nada: estado vazio explícito, não widget em branco.
- Cantos arredondados via `system_app_widget_background_radius`; chrome do widget (fundo, cabeçalho, horários) nas cores **neutras** do sistema (`@android:color/system_neutral1_*` no Android 12+). O chroma fica restrito às linhas dos itens, na densidade escolhida no app.
- **Marca o horário corrente**, do mesmo jeito neutro que a visão semana.
- Redimensionável, com `targetCellWidth`/`targetCellHeight` (Android 12+): em tamanho pequeno mostra os próximos 2–3 horários, em tamanho grande o dia inteiro. A altura decide quantas linhas cabem; a **largura** decide se cada linha ganha uma terceira faixa com tipo/local (≥220dp) — alargar o widget sem crescer a altura deixou de só esticar espaço vazio.
- Toque no widget abre o app na visão semana.
- **Prévia no seletor de widgets**: `previewLayout` (Android 12+) e `previewImage` (universal) juntos — várias skins de launcher (HyperOS incluída) não inflam `previewLayout` e caem no ícone do app sem aviso se essa segunda linha não existir.

### Refresh
O Android não garante refresh exato de widget em background — `updatePeriodMillis` tem mínimo de 30 min e é tratado como sugestão (pode atrasar mais em Doze mode). **Decisão**: aceitar esse atraso natural (ninguém olha o widget às 00:00:01) e complementar com refresh forçado sempre que o app abre ou uma tabela é salva/ativada.

Agendamento exato via `android_alarm_manager_plus` foi descartado: exige `SCHEDULE_EXACT_ALARM` (Android 12+), permissão desproporcional ao ganho.

## Stack

- **Flutter** (Dart), projeto isolado em `mobile/` — não mistura com o script Python. Fixado no fvm stable via `.fvmrc`.
- **Estado**: `provider` (ChangeNotifier).
- **Persistência**: `shared_preferences` + JSON.
- **Widget nativo**: pacote `home_widget` (ponte Flutter → `AppWidgetProvider` Android).
- **Tema**: `dynamic_color`.
- **Backup**: `file_picker` (salvar/abrir arquivo via SAF).
- **Notificações**: `flutter_local_notifications` + `timezone` + `flutter_timezone` (fuso do aparelho).

## Roadmap

1. ~~Scaffold do app Flutter~~ ✅
2. ~~Tema M3 + cores dinâmicas + paleta curada + as três densidades como função pura `(chave, densidade, tema) → (fundo, texto, filete)`~~ ✅
3. ~~Modelo (`Item`, `Tabela`) + persistência + provider~~ ✅
4. ~~Biblioteca de itens (CRUD) e lista de tabelas~~ ✅
5. ~~Visão semana (só leitura), com destaque de hoje e do horário corrente~~ ✅
6. ~~Editor do dia com arrastar~~ ✅
7. ~~Tela de aparência (escolha da densidade por miniatura)~~ ✅
8. ~~Widget nativo Android (Glance, manifest) + snapshot na densidade escolhida~~ ✅
9. ~~Estratégia de refresh (foreground em toda mutação + no resume do app, tick natural do SO via `updatePeriodMillis`)~~ ✅
10. ~~Polimento: ícone do app (`assets/icon/`, ver `flutter_launcher_icons` no `pubspec.yaml`), preview real do widget no seletor (`today_schedule_widget_preview.xml`), estados vazios~~ ✅

O app fecha o ciclo de uso: cadastrar item, criar tabela, montar o horário,
ver a semana e acompanhar o dia pelo widget na tela inicial.

A função de resolução da fase 2 é o ponto de reuso do projeto: a grade, o editor, as miniaturas da tela de aparência e o snapshot do widget consomem todos ela. Errar ali propaga pra tudo; acertar ali resolve tudo de uma vez.

## Depois do roadmap original

Uso real do app trouxe fricção que o roadmap de 10 fases não previa. Registro
do que foi implementado em cima dele, fora da numeração — não são fases
planejadas de antemão, são ajustes que só apareceram usando de verdade.

- **Navegação Tabelas → grade**: tocar num card em Tabelas só ativava a
  tabela, sem levar a lugar nenhum — quem tocava ficava sem saber que "ativar"
  e "montar o horário" eram coisas diferentes em abas separadas. Resolvido com
  a tela dedicada de uma tabela (Telas, item 2): tocar (ou criar) já leva pra
  lá. A aba Semana continua existindo como atalho pra "a tabela ativa, seja
  lá qual for".
- **Item exclusivo de uma tabela e arquivamento**: a biblioteca compartilhada
  acumula item de semestre antigo. Duas soluções que se complementam: `tabelaId`
  evita a poluição desde a criação (pro caso já sabido de algo que não vai
  reaproveitar); `arquivado` resolve depois, por decisão manual ou revisão em
  lote a partir de uma tabela (candidatos = usado só ali, mas a decisão final
  é sempre do usuário — Almoço/Academia usados só numa tabela hoje não deixam
  de fazer sentido numa tabela futura só por isso).
- **Campo `professor` removido do Item**: deixava o app implicitamente
  focado em aula. Quem quiser anotar isso usa `notas`, que é texto livre.
- **Editor do dia repaginado**: a bandeja horizontal com scroll virou uma
  paleta em lista que cresce pra baixo; "toque pra armar" apareceu como
  segundo caminho pra preencher um horário, tão direto quanto arrastar mas
  sem depender de acertar o tempo de segurar; limpar um horário ganhou
  desfazer.
- **Grade da semana com mais interação**: swipe pra trocar de tabela, toque
  longo numa célula pra editar só ela, linha do horário atual, fio discreto
  entre as colunas dos dias.
- **Responsivo**: barra lateral em tela larga, formulários com largura
  máxima. Ver "Navegação e layout responsivo" acima.
- **Backup**: exportar/importar tudo como um arquivo JSON, pela tela
  Aparência. Motivado direto por perda de dado real — reinstalar o app apaga
  o que está em `SharedPreferences`, sem aviso e sem recuperação. Ver
  "Backup" acima.
- **Troca ao arrastar pra slot ocupado**: antes sobrescrevia e o item que
  estava lá sumia da tabela; agora troca de lugar com o que chegou. Só se
  aplica a slot-pra-slot, ver "Interação de arrastar" acima.
- **Prévia do widget e responsividade à largura**: a prévia no seletor não
  aparecia em launchers que não suportam `previewLayout` (HyperOS incluído);
  e alargar o widget não fazia nada além de esticar espaço vazio, porque
  tipo/local do item já vinham no snapshot mas nunca eram desenhados. Ver
  "Widget de tela inicial" acima.
- **Placeholders neutros**: exemplos de nome ("2026.1") e de item ("Cálculo
  II") remetiam só a semestre acadêmico; trocados por exemplos que misturam
  contexto (academia, trabalho, rotina).
- **Dias configuráveis por tabela**: `kDias` global (segunda-sexta fixo)
  virou `Tabela.dias`, um subconjunto qualquer de `kTodosDias` escolhido na
  configuração da tabela. Resolve os dois pedidos que motivaram — destravar
  sábado/domingo, e tabela com só alguns dias da semana (ex: terça/quinta pra
  academia) — com a mesma solução, já que o segundo caso cobre o primeiro.
  Ver "Dados" e "Telas" acima.
- **Notificações de horário se aproximando**: interruptor + antecedência
  configurável em Aparência, alarme inexato (sem pedir permissão de alarme
  exato), sem persistir a reboot de propósito. Ver "Notificações" acima.
- **Widget resolve o dia sozinho e rola**: snapshot com a semana inteira (o
  nativo escolhe hoje a cada redesenho), `SizeMode.Exact` pra redimensionar
  valer de verdade, `LazyColumn` pra dia cheio rolar em vez de cortar.
- **Eventos**: ver a seção própria abaixo.

## Eventos e Google Agenda

**Status (2026-11-11)**: fase 1 (eventos locais, grade, widget, notificação,
calendário mensal) fase 2 (ler do Google Agenda) e fase 3 (gravar no Google) implementadas.

Pedido: puxar compromissos do Google Agenda pra dentro das tabelas e criar
eventos no app que vão pro Google Agenda. "Evento" é o nome do conceito novo:
um momento com data (único ou recorrente), que pode ou não estar vinculado a
um item — uma prova vinculada a SO, um "Aniversário de Pedro" solto.

**A tensão central**: a tabela é um molde semanal sem data ("SEGUNDA, slot
0" vale pra toda segunda), em blocos largos (`intervalo`, 2h por padrão), e
cobre só alguns dias e algumas horas. Evento tem data e hora exatas. Todas as
decisões abaixo saem daí.

### Decisões confirmadas

- **Sync via agenda do próprio Android (`CalendarContract`)**, não Google
  Sign-In + Calendar API. O Android já sincroniza as agendas da conta Google
  do aparelho; o app só lê/grava no provider local. Sem projeto no Google
  Cloud, sem OAuth/token expirando (app em modo teste perde autorização a cada
  7 dias), funciona offline, e "puxar semanalmente" deixa de ser necessário —
  o app lê na hora de desenhar. Consequência: não existe "conta logada no
  app"; em configuração o usuário escolhe *em qual agenda* (de qual conta)
  eventos novos são salvos e *quais agendas* aparecem no app. Permissões
  `READ_CALENDAR`/`WRITE_CALENDAR`. Plugin (`device_calendar` ou similar) vs.
  platform channel próprio em Kotlin fica pra decidir na implementação —
  testar build do plugin isolado primeiro (ver gotcha do `share_plus`).
- **Conflito com item (evento no horário de um item)**: o item continua na
  célula, o evento vira um **selo no canto**. Descartados: evento sobrescrever
  o item (esconde a aula) e célula dividida (não cabe em ~55dp).
- **Abaixo da grade: lista "Próximos"** (14 dias), não calendário mensal
  embutido. O mês inteiro ficou numa tela própria (ver "Calendário" abaixo).
- **Criar evento tem que ser rápido.** Pedido explícito: nada de formulário
  "difícil". Tudo que dá pra deduzir do contexto chega preenchido.

### Modelo

```
Evento { id, titulo, tipo, inicio, fim?, diaInteiro,
         repeticao (nenhuma|semanal|mensal|anual), itemId?, local?, notas? }
Tabela  { …, mostrarEventos (padrão true) }
```

`lib/model/evento.dart`. `ocorrenciasEntre(de, ate)` expande a recorrência:
mensal no dia 31 pula mês sem dia 31, anual em 29/02 só cai em ano bissexto
(igual ao Google Agenda, em vez de escorregar pro dia seguinte); soma dias
pelo calendário, não por 24h, pra horário de verão não deslocar a hora.
Persistido em `events_json`, incluído no backup (backup antigo sem a chave
abre com lista vazia). Apagar um item **solta** os eventos dele (viram
avulsos) em vez de apagá-los. Editar recorrente altera a série inteira.

Ainda não no modelo (entra com o Google): `origem (app|google)`, `googleId`,
e o mapa local `googleId → itemId` — `ExtendedProperties` do
`CalendarContract` só é gravável por sync adapter, então o vínculo de evento
importado tem que morar no app. Sugestão de vínculo por sigla no título
("Prova de SO" → SO?), sempre pedindo confirmação.

### Grade da tela inicial

Representa a **semana atual**: cabeçalho de coluna ganha a data ("SEG" em
cima, "9" embaixo). Onde cada evento cai (`lib/util/eventos_na_grade.dart`,
função pura, testada sem UI):

1. Dentro do horário, célula vazia → **fantasma**: contorno tracejado com o
   título (e "+N" se houver mais de um).
2. Dentro do horário, célula com item → **selo** no canto: "!" se o evento é
   vinculado àquele item (a prova de SO no horário de SO), ponto se não. Cor
   do selo = cor do texto da célula, então funciona nas três densidades.
3. Dia todo → faixa fina **"dia todo"** em cima; fora do horário da tabela
   (antes ou depois) → faixa **"outros"** embaixo. Só renderizadas na semana
   que tem evento assim.
4. Dia que a tabela não tem → só na lista "Próximos" e no calendário.

Evento com faixa ocupa todo slot que `[inicio, fim)` sobrepõe; pontual (sem
término) marca o slot que contém o início. Tocar numa célula/faixa com
evento abre uma folha com o item daquele horário e os eventos; sem evento, o
toque continua abrindo o dia inteiro.

`Tabela.mostrarEventos` (interruptor "Mostrar eventos avulsos" na
configuração da tabela): desligado, só passa evento vinculado a item que a
tabela usa.

A tela de montar uma tabela (`TabelaEditorScreen`) continua sem datas nem
eventos — ali a grade é molde.

### Criação, do mais contextual ao mais genérico

- **Toque longo numa célula da tela inicial** → primeira opção do menu é
  "Novo evento para SO" (ou "Novo evento neste horário" se vazia): chega
  vinculado, com início e fim do **horário inteiro**, na data desta semana —
  ou da próxima, se nesta já passou.
- **"+ Evento" na tela do item** → vinculado, data no próximo horário do item.
- **Calendário**: "+" ou segurar um dia → evento naquele dia.
- **Botão de evento na tela inicial** → formulário limpo, próxima hora cheia.

Formulário (`lib/ui/evento_editor.dart`):
- **Escolher o item preenche sozinho**: o **local do item** (com o aviso "Do
  item vinculado"), e a data/hora do **próximo horário do item** (procura na
  tabela ativa, depois nas outras). Cada campo só acompanha o item enquanto o
  usuário não mexer nele.
- **Título automático**: tocar num tipo monta "Prova · Sistemas
  Operacionais" enquanto o título não for digitado à mão.
- **Tipos** com sugestão fixa (Prova, Entrega, Compromisso) + os já usados.
- **Atalhos de data**: "Próximo de SO · qui 10:00", "Hoje", "Amanhã".
- Mudar o início leva o término junto, mantendo a duração.
- Caso mais comum — prova na próxima aula — sai em 4 toques: segurar a
  célula, "Novo evento para SO", "Prova", "Salvar".

App passou a usar `flutter_localizations` em pt-BR (seletores de data/hora,
OK/Cancelar).

### Onde eventos aparecem

- **Lista "Próximos"** abaixo da grade: 14 dias, some o que já terminou.
  Link "Ver mês" pro calendário.
- **Tela do item**: seção "Eventos" — próximos em destaque, passados
  recolhidos ("3 passados"), "+ Evento".
- **Calendário** (`lib/ui/calendario_screen.dart`, ícone na barra da tela
  inicial ou "Ver mês"): grade do mês sempre com 6 semanas (altura não pula
  entre meses), segunda primeiro. Cada dia mostra até 3 barrinhas na cor do
  item vinculado (neutras pra avulso) + "+N" — dá pra bater o olho e ver
  "semana de provas de SO" sem ler nada. Tocar num dia lista os eventos dele
  embaixo; tocar num dia do mês vizinho leva pra lá. Troca de mês por swipe
  ou setas; "Hoje" volta. Contador de eventos do mês no cabeçalho. Mostra
  **todos** os eventos, sem filtro de tabela. Criar no dia por toque longo,
  não toque duplo — com `onDoubleTap` o toque simples esperaria ~300ms pra
  confirmar, e selecionar dia ficaria lento.
- **Widget**: ver "Snapshot enviado ao widget".
- **Notificações**: ver abaixo.

### Notificação de evento

Interruptor "Avisar eventos também" em Aparência (só aparece com as
notificações ligadas; padrão ligado). Com hora: mesma antecedência dos
horários. Dia todo: às 8h do dia. Alarme **único** por ocorrência (não
recorrente como o de horário), agendado pros próximos 14 dias — a janela anda
sozinha toda vez que o app abre e o agendador ressincroniza. Canal próprio
("Eventos"), ids a partir de 100000 pra nunca colidir com os de horário.
Avisa de **todos** os eventos, sem o filtro da tabela ativa: o aniversário
escondido da tabela da academia continua merecendo aviso. Inexato, como o
resto.

### Leitura do Google Agenda (fase 2)

Tela **Aparência → Agendas do aparelho** (`lib/ui/agendas_screen.dart`):
pede `READ_CALENDAR`/`WRITE_CALENDAR`, lista as agendas por conta (a
principal, cujo nome é o e-mail, aparece como "Principal") com caixa de
seleção e contagem de eventos. Primeira vez: já marca as do Google que estão
visíveis e sincronizando (as principais + "Feriados no Brasil"); turmas ficam
pro usuário. Escolha persiste em `device_calendars_json` (id → nome, cor),
fora do backup — id de agenda é do aparelho.

**A descoberta que mudou o desenho**: cada turma do Classroom é uma agenda,
mas o Android vem com `SYNC_EVENTS=0` nelas — a agenda existe no aparelho e
fica vazia, e o app de agenda da Xiaomi e o botão de exibição do Google
Agenda não mexem nisso (só no que eles mostram). `SYNC_EVENTS` é gravável
por app comum, então **marcar uma agenda que não sincroniza liga a
sincronização dela**; o adaptador do Google baixa os eventos sozinho em
segundos/minutos (validado no aparelho: Projeto de Software 2026.2 baixou 5
eventos sem nenhuma ação do usuário). Desmarcar não desliga — a
sincronização pode ter sido ligada antes, por outro app.

**Ponte própria em Kotlin** (`AgendaChannel.kt`, canal `tabelador/agenda`):
`listarAgendas` (com `SYNC_EVENTS`, `VISIBLE`, nível de acesso),
`definirSincronizacao`, `lerEventos` (tabela `Instances`, recorrência já
expandida pelo Android, cancelados fora). O plugin `device_calendar` ficou
só pra pedir a permissão em runtime: ele não expõe `SYNC_EVENTS` e converte
evento de dia inteiro com fuso de um jeito difícil de acertar. O app fala só
com `lib/agenda/agendas_do_aparelho.dart`; trocar o mecanismo mexe só ali.

**Evento externo** = `Evento` com `agendaId` (e `corExterna`, a cor da
agenda): só em memória, relido do Android ao abrir o app, ao voltar pro
primeiro plano e ao mudar a seleção; nunca persistido nem no backup. Janela
de leitura: 62 dias pra trás, 400 pra frente. Dia inteiro vem do Android em
meia-noite **UTC** — a data sai dos componentes UTC (ler como hora local
jogaria o Natal pro dia 24 à noite no Brasil). Entra em tudo que usa
`ocorrenciasEntre`: grade, "Próximos", calendário, widget, avisos. Só
leitura: tocar abre uma folha de detalhes com a agenda de origem, não o
formulário. Cor: a da agenda onde item vinculado usaria a do item. Conta
como avulso pro filtro `mostrarEventos` da tabela.

### Gravação no Google (fase 3)

Mesmo caminho da leitura, ao contrário: o app grava na **agenda do
Android**, numa agenda da conta Google, e o próprio Android sobe pro Google
— sem API nem login. Agenda local (sem conta) deixaria o evento só no
aparelho.

- Formulário ganha **"Salvar também em"**: "Só no app" ou uma agenda
  escolhida e gravável (dono/colaborador — feriados e turmas não aparecem).
  Novo evento começa na **última usada** (`device_calendar_target`); escolher
  "Só no app" explicitamente também vira o padrão.
- `Evento.idNoAparelho` + `agendaDestinoId` (persistidos): o espelho do
  evento lá. Editar na mesma agenda atualiza a linha; trocar de agenda apaga
  lá e cria cá; "Só no app" apaga a cópia; apagar no app apaga lá. Cópia
  apagada pelo Google desde a última gravação é recriada em vez de perder a
  edição em silêncio.
- **Sem duplicar**: o evento gravado volta na leitura como externo; em
  `ocorrenciasEntre` o externo cujo `idNoAparelho` bate com o de um evento do
  app é descartado — fica a versão do app, que tem vínculo com item.
- Dia inteiro em meia-noite UTC com fuso UTC; recorrente com `RRULE`
  (`FREQ=WEEKLY|MONTHLY|YEARLY`, mesma semântica de pular data inválida) +
  `DURATION` em vez de `DTEND`, como o provider exige.
- **Sem lembrete** no evento gravado: quem avisa é o tabelador; lembrete do
  Google em cima daria aviso duplicado.
- Falha ao gravar: salva no app mesmo assim e avisa ("não deu pra gravar no
  Google Agenda").
- "Gravável" das agendas escolhidas é atualizado do aparelho a cada
  releitura — quem escolheu agendas numa versão anterior não precisa abrir a
  tela de novo.
- Lista marca "· Google" no evento do app que tem cópia lá.

Validado no aparelho: evento criado no app apareceu no Google Agenda.

### Criação de evento em chips (redesenho, 2026-11-11)

Motivo: o formulário de tela inteira tinha 11 campos de mesmo peso — "muita
coisa pra clicar pra criar um simples evento". Princípio: **chips pra tudo;
texto só onde nenhuma escolha representa** (título, local, notas).

Descartado: reconhecimento de texto livre ("prova SO quinta 10h"). Não por
segurança (texto local, sem rede nem execução), mas por **ambiguidade** —
"sexta" num título, sigla que é palavra comum — o app adivinharia errado e
o usuário teria que conferir, o oposto de prático.

**Folha que sobe de baixo** (não tela inteira), por cima da grade/
calendário, com animação mais lenta que a padrão (420 ms subindo) pra o
olho acompanhar. Mesma folha pra criar e editar. Cabeçalho com ícone,
"Novo evento" e ✕; **Salvar** grande preso no rodapé. Ordem:

1. **Título** — opcional: vazio vira "Prova · Sistemas Operacionais" (tipo +
   item), mostrado como dica no campo. Só é obrigatório sem tipo útil e sem
   item.
2. **Tipo** — lista fixa com ícone, cada um define padrões (o ganho real
   não é a categoria, é o que ela preenche):

   | Tipo | Padrão |
   |---|---|
   | Prova | duração do horário do item (2h sem item) |
   | Entrega | prazo (um horário, sem duração) |
   | Lembrete | prazo |
   | Compromisso, Consulta, Reunião, Outro | 1h |
   | Viagem | dia todo (um dia só — vários dias fica pra depois) |
   | Aniversário | dia todo, repete todo ano |

   Sem tipo personalizado por enquanto. Evento antigo com tipo em texto
   livre que não bate com a lista é tratado como "Outro" (o texto antigo
   continua salvo).
3. **Item** — chips **coloridos** (cor do item) dos itens da **tabela da
   célula** (toque longo) ou da **tabela ativa** (resto); último chip
   "Outro…" abre lista com busca de todos. Tocar de novo desmarca. Escolher
   item preenche local, título e próximo horário (cada um só enquanto o
   usuário não mexeu).
4. **Quando** — [Próximo de SO · qui 10:00] [Hoje] [Amanhã] [📅 Outra data].
   - **Horário**: chips com o início de cada horário da tabela (08:00,
     10:00…) e [Outro…] (relógio). Com item vinculado, o horário que ele
     ocupa no dia escolhido vira "10:00 · SO" — só o do item vinculado.
     Some em dia todo.
   - **Duração** em vez de término — [Dia todo] [Prazo] [SO · 2h] [30 min]
     [1h] [2h] [Outra…] ("Outra…" pergunta até que horas). "Dia todo" como
     duração elimina o interruptor separado.
5. **Detalhes** — chips [📍 Local] [↻ Não repete] [☁ Salvar em], cada um
   **mostrando o valor atual** (preenchido é cheio). Tocar abre um **menu
   flutuante acima do chip** (abaixo, se não couber; nunca passa da borda);
   tocar fora fecha. **Segurar e arrastar pra cima** pelo menu escolhe
   direto, com vibração ao trocar; soltar sem destacar nada deixa o menu
   aberto. Arrasto só começa depois do toque longo ganhar o gesto, então
   não briga com rolar/fechar a folha.
   - Local: o do item, os dos outros itens da tabela, "Digitar…", "Sem
     local". Sem sugestão, tocar já abre a caixinha de texto.
   - Salvar em: "Só no app" e cada agenda gravável com a **conta** embaixo
     (a principal de cada conta tem o e-mail como nome — antes aparecia
     "Principal" repetido). No chip, só a parte antes do @.
6. **Notas** — campo opcional no fim (não chip).

Cada seção (Tipo, Item, Quando, Detalhes) é um **cartão** com ícone
colorido, título forte e, à direita, o valor escolhido ("Prova",
"qui 12/11 · 10:00–12:00") — dá pra conferir o evento lendo só os
cabeçalhos.

**Alinhamento**: todos os chips são o mesmo componente (`GradeDeChips`),
mesma altura, em linhas **justificadas** — cada linha estica os chips
proporcionalmente ao tamanho natural até ocupar a largura toda, e as linhas
são equilibradas (mesmo número de linhas do empacotamento cheio, larguras
parecidas) pra não sobrar chip sozinho esticado.

**Teclado**: só um padding fino acompanha `viewInsets`; o corpo da folha não
é refeito a cada quadro da animação do teclado (antes era, e engasgava).

**Repetição ganha "Diária"** (Não repete, Todo dia, Toda semana, Todo mês,
Todo ano; `FREQ=DAILY` no Google).

Caso típico: prova de SO na próxima aula = Prova, SO, Salvar — três toques,
nenhum teclado. Do toque longo na célula: Prova, Salvar.

### "Esta semana" no lugar de "Próximos 14 dias"

14 dias acumulava demais, e a grade já mostra a semana. Agora **"Esta
semana"** (de agora até domingo, só o que ainda não terminou; dia todo vale
até o fim do dia), com a quantidade num selo e o botão **Mês** (calendário)
no cabeçalho — o cabeçalho não abre nem fecha nada. Fechada, mostra só o
**próximo evento** como linha normal da lista e, se houver mais, o botão
"Ver mais N eventos da semana"; aberta, tudo **agrupado por dia** (Hoje,
Amanhã, qui 13/11) e "Mostrar só o próximo". Estado lembrado. No fim de
semana, link "Próxima semana · N" pro calendário.

### Card de detalhes antes do editor (2026-11-10)

Tocar num evento (Esta semana, Próximos, eventos do item, folha da célula,
calendário) abre um **card só de leitura**, não mais a folha de edição:
quase sempre o toque é pra conferir, não pra mudar.

- Cabeçalho tingido com a cor do evento (item vinculado → cor do item;
  Google sem item → cor da agenda; senão, a do tema), ícone do tipo,
  "Tipo · Amanhã/Em 5 dias", título grande.
- Linhas com ícone: data por extenso ("Quarta-feira, 11 de novembro", ano
  só se não for o atual), horário + duração, repetição, local, item (com a
  amostra da sigla), notas.
- Rodapé: onde o evento vive — "Só neste aparelho", "Também no Google
  Agenda · agenda" ou, em evento externo, "Do Google Agenda — editar por lá".
- **Lápis** (só evento do app) fecha o card e abre a folha de edição; apagar
  continua dentro da folha. Evento do Google usa o mesmo card, sem lápis
  (substituiu a folha de leitura que ele tinha antes).
- Código: `lib/ui/detalhes_evento.dart`; `EventoTile` chama
  `abrirDetalhesDoEvento`.

### Limitações conhecidas

- Grade mostra só a semana atual (sem navegar pra próxima); pra frente, usar
  o calendário.
- Evento que começou num dia anterior e ainda está acontecendo não aparece
  em "Próximos" nem na grade (só olham o dia de início).
- Editar só uma ocorrência de recorrente: não existe.
- Evento do Google não é editável no app, nem vinculável a item ainda.
- Edição feita no Google Agenda num evento criado no app é sobrescrita na
  próxima edição pelo app (a versão do app é a fonte de verdade).
- Calendário além da janela de leitura (2 meses atrás, ~13 meses à frente)
  mostra só os eventos do app.
- Aviso às 8h vale pra todo evento de dia inteiro, feriado incluído.

### Próximos passos

1. ~~Eventos locais~~ (feito).
2. ~~Ler do Google~~ (feito). Pendente dessa fase: sugerir vínculo de
   evento do Google com item pela sigla no título.
3. ~~Gravar no Google~~ (feito).
4. ~~Eventos no widget, notificação de evento~~ (feito).

## Onboarding (implementado, 2026-11-10)

Hoje o app abre direto em "Nenhuma tabela ativa", sem explicar nada. O que
mais pede explicação é o Google Agenda — principalmente que turma do
Classroom só aparece se for marcada (ver "Leitura do Google Agenda"), coisa
que ninguém descobriria sozinho.

**Fluxo de primeira abertura**, uma vez só, com "Pular" sempre visível e
cada passo opcional:

1. **Boas-vindas** — uma frase: monte sua semana em tabelas, e seus
   compromissos aparecem junto.
2. **Primeira tabela** — nome, dias, horários; o mesmo formulário de
   `_ConfigTabela`, embutido. Pulável.
3. **Google Agenda** — o app lê (e grava) nas agendas que o celular já
   sincroniza; botão "Conectar" pede a permissão e abre a escolha de
   agendas. Destaque: *"Usa o Classroom? Marque suas turmas e as atividades
   aparecem aqui."* Escolher onde salvar eventos novos.
4. **Widget e avisos** — como pôr o widget na tela inicial (instrução, o
   Android não deixa o app adicionar sozinho em todo launcher) e ligar os
   avisos ali mesmo.

**Quem já usa o app** (já tem tabela) não vê o fluxo inteiro: um cartão
discreto na tela inicial, uma vez — "Novo: conecte o Google Agenda" —
fechável, e não volta depois de fechado ou de conectar.

Flag persistida (`onboarding_visto`), não inferida de "não tem tabela" —
quem apagou todas as tabelas não deveria ver as boas-vindas de novo.

Como ficou: `OnboardingScreen` (4 páginas num `PageView`, pontinhos de
progresso, "Voltar"/"Continuar", "Pular" no topo menos na última, que tem
"Começar"). Passo 2 embute o mesmo `ConfigTabela` da aba Tabelas (com
`aoCriar`, sem título nem "Cancelar") e vira "✓ criada" depois. Passo 3 abre
a `AgendasScreen` e, conectado, deixa escolher onde eventos novos são salvos.
Passo 4 tem "Adicionar widget" (`requestPinWidget`, só se o launcher
suporta) e os interruptores de aviso. Migração: chave `onboarding_seen`
ausente + já tem tabela = usuário antigo → marca visto e liga o cartão do
Google (`google_card_pending`) se ainda não configurou agendas.

## Tarefas e aba "Eventos" (em discussão, 2026-11-11)

### v1.1 implementado (2026-11-11)

O que entrou e as decisões tomadas na implementação:

- **Tipos**: `TipoEvento` = Tarefa, Prova, Compromisso, Consulta, Reunião,
  Viagem, Aniversário, Feriado, Outro. Cor e ícone em
  `lib/theme/tipo_evento_visual.dart` (estetoscópio vem do pacote
  `material_symbols_icons`). O card de detalhes e a linha da lista usam a
  cor do tipo quando o evento não tem item.
- **Modelo** (`Evento`): `semData`, `feito` (evento que não repete),
  `feitas` (dias concluídos de recorrente), `avisoMin` (hora do aviso de
  dia todo). Tarefa sem data guarda a data de criação em `inicio`, que é
  ignorada: não gera ocorrência, não vai pra grade, calendário, aviso nem
  Google.
- **Migração**: evento salvo com tipo "Entrega" vira Tarefa ao carregar (e
  ao restaurar backup); a que já passou entra como **concluída**, pra não
  chegar tudo como atrasado. "Lembrete" cai em Outro (não havia nenhum).
- **Folha**: com Tarefa aparecem "Sem data" (no Quando) e "Sem hora" (no
  Horário); hora escolhida = prazo, sem duração. Linha **Aviso** (07:00,
  08:00, 12:00, 18:00, Outro…) pra **qualquer** evento de dia todo, não só
  tarefa. Padrão do aviso de dia todo passou de 8h pra **7h** em todos os
  tipos.
- **Atrasada** = tarefa que não repete, não concluída, com prazo passado
  (sem hora: o dia acabou). Ocorrência antiga de tarefa recorrente **não**
  conta como atrasada (senão "todo dia" acumula).
- **Concluída**: some do widget, do "Esta semana" e dos avisos; continua
  na grade e no calendário.
- **"Esta semana"**: tarefa com caixinha (conclui com Desfazer); atrasadas
  sempre no topo, mesmo fechada; botão **Tarefas** no cabeçalho.
- **Página de Tarefas** (`tarefas_screen.dart`): seções Atrasadas, Hoje,
  Esta semana, Mais tarde, Sem data, Concluídas (escondidas, com "Mostrar
  N concluídas"). Recorrente aparece uma vez, na próxima ocorrência
  pendente. Gestos como decidido (caixinha, → conclui, ← apaga, segurar =
  seleção, riscada 2s, Desfazer). Opções de listagem: período, item,
  mostrar concluídas; lupa. Filtro por origem fica pro Classroom (v1.2).
  **Tem botão "Nova tarefa"** (a regra "sem ＋" era da aba Eventos, não
  desta página).
- Fica pra depois: prioridade de Tarefa, "feito" de tarefa do Classroom,
  widget só de tarefas.

Nada construído. Decidido até agora:

- **Tarefa é um tipo de Evento**, não uma entidade à parte — reusa
  modelo, notificação, widget, backup. Mas sem tratar Tarefa com
  exclusividade: a ideia é repaginar Eventos como um todo.
- Tarefa tem **"feito"** e **data opcional** (sem data = só lembrar que
  precisa ser feita). Com data e sem hora → aviso **de manhã cedo** no dia.
- **Saem os tipos Lembrete e Entrega**: Entrega é uma tarefa; Lembrete
  deixa de ser tipo próprio (avisar é algo que qualquer evento faz).
- **Quarta aba "Eventos"** (nome provisório) com um card por tipo
  (Provas, Consultas, Tarefas…); tocar num card abre a lista daquele tipo.
  A tela Semana continua com um resumo dos próximos (a discutir).

- **Compromisso, Consulta e Reunião continuam separados** — cada um tem
  teor e comportamento próprios (as particularidades de cada tipo serão
  discutidas depois que a lista fechar).
- **Tipos fixos** (cadastráveis fica pra um futuro distante).
- **Classroom → Tarefa** (cada atividade tem data de entrega). Ideia de
  um tipo **Feriado / Data comemorativa** pra agenda de feriados do Google.
- Aba Eventos = **cards coloridos e vivos**, um por tipo (ícone e cor
  próprios: Consulta azul com estetoscópio etc.), minimamente
  informativos (quantidade); tocar abre uma página com todos os eventos
  daquele tipo.
- Lembretes existentes: não há nenhum salvo, pode apagar o tipo sem
  migração.
- Horário do aviso de Tarefa com data e sem hora: **configurável na
  própria tarefa** (padrão de manhã cedo).

- Tipos (9): **Tarefa, Prova, Compromisso, Consulta, Reunião, Viagem,
  Aniversário, Feriado, Outro**. Feriado cobre também data comemorativa.
- **Evento do Google: tipo padrão por agenda** (escolhido na tela
  Agendas). Classroom → Tarefa e agenda de feriados → Feriado,
  reconhecidas sozinhas; agenda comum → Outro. "Feito" de tarefa do
  Classroom fica guardado localmente (o "entregue" não vem pela agenda).
- Layout da aba: **card de Tarefas largo no topo** com as 3 próximas
  pendentes marcáveis; demais em grade de 2 colunas, ordem fixa, tipo
  vazio aparece apagado. **Sem botão ＋ na aba** — criar evento continua
  pelo botão da tela Semana, como hoje.
- **Calendário do mês** ganha atalho na aba Eventos e **mantém** o botão
  na tela Semana.
- Card **Feriados**: mostra se hoje é feriado e quantos faltam até o fim
  do ano. Card **Aniversários**: os do mês atual.
- Tarefas: trabalhar bem a usabilidade de concluir (gestos: arrastar pra
  um lado conclui, pro outro apaga; segurar etc.).

- **Paleta aprovada** (harmonizada com Material You, tons próprios no
  escuro): Tarefa verde `#2E7D32` (check), Prova vermelho `#D84343`,
  Compromisso laranja `#EF6C00` (aperto de mão), Consulta azul `#1E88E5`
  (estetoscópio), Reunião roxo `#5E35B1` (grupo), Viagem verde-azulado
  `#00897B` (avião), Aniversário rosa `#D81B60` (bolo), Feriado dourado
  `#F9A825` (celebração), Outro cinza-azulado `#607D8B` (calendário).
  Adicionar o pacote Material Symbols (estetoscópio etc.) — aprovado.
- **Gestos de Tarefa**: caixinha conclui; arrastar → direita conclui,
  ← esquerda apaga (Classroom: **oculta** do app); tocar no corpo abre o
  card de detalhes; **segurar = modo de seleção** (concluir/apagar
  várias). Concluir deixa riscada ~2s antes de descer pra "Concluídas",
  com Desfazer; apagar também com Desfazer. Recorrente: concluir marca só
  a ocorrência atual.
- Página de Tarefas com **botão de opções de listagem** (só desta semana,
  pesquisar etc.).
- **Widget separado só de tarefas** (futuro) — melhor que enfiar gesto
  no widget de horários.
- Aniversários: **mês atual inteiro, passados esmaecidos**; nos últimos
  dias do mês adianta o primeiro do mês seguinte.
- **Feriados nacionais embutidos** (calculados no app, incl. móveis via
  Páscoa); agenda de feriados do Google opcional.

- **Correção de regra (a fazer)**: evento vinculado a item aparece só nas
  tabelas que usam o item, sempre; "Mostrar eventos" passa a valer só pra
  evento sem item. Hoje (`eventoVisivelNaTabela`) "Mostrar eventos" ligado
  mostra tudo — "Monitoria de SO" (2026.1) vazaria na tabela 2025.2.
- **Tarefas no "Esta semana"**: as que vencem na semana + **atrasadas no
  topo** em destaque; sem data não entram.
- **Filtros da página de Tarefas**: período (Todas/Hoje/Esta
  semana/Atrasadas/Sem data), item, origem (app/Classroom), mostrar
  concluídas; lupa pra pesquisar título.
- Ideia pra discussão por tipo: **feriado esmaece as aulas do dia** na
  grade e suprime o aviso delas.

- **"Esta semana": linha de tarefa só com caixinha** (toque conclui, com
  Desfazer); arraste e seleção só na página de Tarefas.
- **Feriados: embutidos mandam, Google complementa.** Embutidos = lei
  federal (fixos 1/1, 21/4, 1/5, 7/9, 12/10, 2/11, 15/11, 20/11, 25/12) +
  móveis pela Páscoa (Sexta-feira Santa; Carnaval e Corpus Christi como
  **ponto facultativo**), com testes contra datas conhecidas. Só embutidos
  e feriados criados à mão esmaecem aulas; evento da agenda de feriados do
  Google aparece mas não esmaece (ela mistura Dia dos Namorados etc.), e
  some quando cai na mesma data de um embutido (comparação por data, não
  nome). **Ponto facultativo esmaece ou não: escolha por tabela.**
- **Feriado: um tipo só, cada data marcada como folga ou comemorativa.**
  Só folga esmaece aulas e conta em "N feriados até o fim do ano".
  Embutidos incluem as datas comemorativas principais (Mães e Pais —
  2º domingo de maio/agosto —, Namorados, Crianças, Ano Novo, Natal…).
- **Botão "É folga"** no card de detalhes de feriado do Google (guardado
  localmente por id do evento). **A fazer com o celular conectado**: ler
  a agenda de feriados do Google no aparelho e ver se a descrição separa
  feriado público de observância — se sim, classificar sozinho.
- **Enfeites de data**: **sem emoji** — animação leve e simples + um tom
  de cor diferente no card de sempre (corações subindo no Dia dos
  Namorados, neve no Natal, fogos no Ano Novo, confete em Aniversário).
  Aparecem **sempre** no card de detalhes e no card do tipo na aba
  Eventos; no **"Esta semana" só no próprio dia**; faixa festiva no topo
  da tela inicial no dia, **desativável** em Aparência.

### Verificado no aparelho (2026-11-11)

- **Agenda de feriados do Google** (`ownerAccount` termina em
  `#holiday@group.v.calendar.google.com`, ex. `pt-br.brazilian#holiday…`):
  a **descrição começa com "Feriado" ou "Data comemorativa"** —
  classificação automática confiável (texto em pt-BR; ler só a primeira
  linha). Ressalva: o Google chama de "Feriado" também ponto facultativo
  e meio-expediente (Carnaval seg/ter, Cinzas até 14h, vésperas de Natal e
  Ano Novo após 14h, Corpo de Deus, Dia do Servidor Público) — os
  embutidos continuam decidindo o que esmaece. O aparelho tem **várias
  agendas "Feriados no Brasil"** (uma por conta, ids `pt-br.` e `pt.`):
  deduplicar por data + título.
- **Classroom**: `ownerAccount` = `classroom…@group.calendar.google.com`
  ou `c_classroom…@group.calendar.google.com` → reconhecível. Os nomes
  trazem o período ("2025.1 Teoria da Computação", "Projeto de Software
  2026.2") — dá pra sugerir em qual tabela/período importar.
- **99** (`com.taxis99`): só esquemas internos da DiDi (`taxis99://`,
  `oia.99app.com`), **sem parâmetro de destino documentado** e não trata
  `geo:`. Botão 99 = abrir o app + copiar o endereço pra área de
  transferência. **Uber** (`com.ubercab`) trata `geo:` e tem o link
  oficial com destino.

### Particularidades por tipo (rodada 1)

- **Aviso é do evento, não do tipo** — o tipo só sugere o padrão.
- **Tarefa**: tem aviso; recorrente é concluída por ocorrência.
- **Prova**: aviso com antecedência maior, configurável. **Nota depois**
  da prova — e talvez uma visão organizada das notas (por item, com
  gráfico), pra ajudar o estudante.
- **Compromisso**: saídas, encontros marcados. Sem particularidade por
  enquanto.
- **Consulta**: local sempre importante. Ideia: **botão pra chamar
  Uber/99** já com o endereço de destino.
- **Reunião**: costuma repetir (padrão semanal) e tem **link de
  videochamada**.
- **Viagem**: **vários dias** (sem ida/volta).
- **Aniversário**: **idade opcional** (ano de nascimento); campo
  **Presente**.
- **Feriado**: como decidido acima.
- **Outro**: em questão se precisa existir.

### Rodada 2

- **Tarefa ganha prioridade** (formato a definir).
- **Nota** em Prova e em Tarefa vinculada a item (trabalho avaliado);
  visão de notas por item puxa a ideia de **tipar Itens** (abaixo).
- **Consulta: local escolhido no mapa / validado** — busca automática do
  endereço, avisando se não achar. **Uber**: link oficial com destino.
  **99**: sem link público documentado (pesquisa 2026-11-11) — conferir
  no celular conectado o que o app 99 aceita (intent filters).
- **Reunião**: padrão semanal; campo link + botão "Entrar"; reconhecer o
  link de videochamada sozinho em evento do Google.
- **Viagem**: vários dias; **esmaece aulas** (como feriado).
- **Aniversário**: ano de nascimento opcional (idade); **Presente** (ideia
  + "comprado") e aviso dias antes se não comprado.
- **Outro**: existe pra receber a agenda comum do Google; coisas como
  corte de cabelo são Compromisso ou Tarefa.

### Itens tipados — rodada 1 (2026-11-11)

- **Tipos fixos.** Hoje `Item.tipo` é texto livre; migração converte os
  textos conhecidos ("Aula" → Disciplina, "Treino" → Treino…) e o resto
  vai pro tipo genérico.
- Uso real: horários de disciplina, academia, intervalos pra estudo,
  monitorias, almoço.
- **Estudo é tipo próprio**, com relação com Disciplina; dá pra criar
  item de estudo a partir de uma disciplina.
- **Trabalho**: sem particularidade clara (talvez ligação com Reuniões).
- **Alimentação** (almoço etc.): horário com comidas pré-definidas, marcar
  que comeu e **enviar pro Wellio** — calorias e detalhes ficam lá.
- **Treino**: mesmo esquema (marcar que fez, enviar pro Wellio). Pode haver
  vários treinos no mesmo horário (treino combinado).
- O Tabelador é **organizacional**; o Wellio, **informacional** (calorias,
  nutrientes, gasto do treino não entram aqui).

### Itens tipados — rodada 2 (2026-11-11)

- **Treino = um item com ficha dentro** (opção C): o item "Academia" ocupa
  a grade como hoje; dentro, os treinos (Costas, Bíceps…) com exercícios e
  qual combinação cai em cada dia da semana. Treino combinado = dois
  treinos no mesmo dia. Marcar feito → enviar pro Wellio.
- **Alimentação no mesmo molde** ("Almoço" com cardápio). Ambos devem
  casar bem com o modelo do Wellio — ver "Integração com o Wellio".
- **Estudo**: vínculo opcional a uma Disciplina (e criar estudo a partir
  dela); anotar o que estudar conforme avança, **desativável** e sem gerar
  pressão (o app organiza, não cobra); "estudei" alimenta horas por
  disciplina; **pomodoro opcional**, não padrão. Estudo gerando Tarefas:
  a discutir.
- **Sem tipo Deslocamento**: o aviso de sair e o botão de transporte já
  vêm do evento (Consulta, Compromisso).
- **Pausa/intervalo = Rotina** (tipo genérico, sem particularidade).
- **Trabalho**: Reuniões vinculadas a ele aparecem na página dele.
- **Monitoria**: *assistir* é um evento avulso vinculado à disciplina
  (não recorrente); *dar* monitoria é recorrente, parecido com Trabalho
  mas não igual (dá pra ter os dois).
- **Classroom ↔ Disciplina, nível 1 (pela agenda) — decidido**: campo
  "Turma do Classroom" na Disciplina, escolhido entre as agendas de turma
  (sugere a de nome parecido); toda atividade da turma vira Tarefa
  vinculada à disciplina. Botão "Importar disciplinas do Classroom" no
  começo do semestre (nome + cor). **Nível 2 (API oficial: notas do
  professor, materiais, entregue)** fica como futuro — exige login Google,
  projeto no Cloud, escopos sensíveis, e conta institucional pode
  bloquear apps de terceiros.
- **Monitoria (dar)** = tipo próprio, pra marcar o horário que você dá
  monitoria; vínculo à disciplina; atividades da monitoria = tarefas,
  reuniões e eventos vinculados; anotações simples. **Ir** à monitoria =
  uma tarefa/evento criado a partir do Estudo.
- **Wellio: Tabelador planeja, Wellio registra** — o planejamento semanal
  sai do Wellio (§13.2 dele); link nos dois sentidos.
- Proposta: "o que estudar" = **Tarefas vinculadas** (sem data não
  atrasa); princípio **registra, não cobra**.
- **Tópico de estudo pertence à Disciplina** (opção A): aparece na página
  da disciplina e em todo Estudo vinculado a ela. Atividades do Classroom
  na lista do Estudo ficam num **acordeão recolhível** pra não poluir.
- **Disciplina**: professor, local, notas com **cálculo de média editável**
  (cada disciplina tem a sua aritmética: várias provas, minitestes, pontos
  extras), faltas, links, materiais.
- Estudo: lista do que estudar = Tarefas vinculadas; **registra, não
  cobra** — confirmado.
- **Média por grupos** (nome, peso, regra interna: média simples / soma /
  descarta a menor), pontos extras com teto opcional, escala 0–10 ou
  0–100, notas puxadas das Provas/Tarefas vinculadas + lançamento avulso,
  média parcial ignora o que não tem nota. **"Quanto preciso tirar"**
  entra (desligado por padrão).
- **Faltas**: "Faltei hoje" no toque longo da célula **e** contador direto
  na página da disciplina; dá pra **remover** falta lançada errado.
- **Aba Itens = lista agrupada por tipo** (cor/ícone do tipo, linha com
  resumo próprio). Problema levantado: disciplina de período antigo não
  deve poluir a lista (nota de SO de 3 períodos atrás).
- Criar a partir de um item = mesma folha, já vinculada (vínculo único:
  Estudo → disciplina; Monitoria → a própria monitoria).
- Cada grupo da média diz **quantas avaliações terá** (o que falta = sem
  nota) → "quanto preciso tirar" = nota uniforme nas que faltam; casos
  "já garantido" / "não dá mais" sem drama. Prova final/recuperação: depois.
- **Faltas por aula**: dois horários seguidos = 2 faltas.

### Ideia do usuário: tela inicial = junção das tabelas ativas (em discussão)

Em vez de uma tabela ativa por vez, **várias tabelas ativas sobrepostas**
na tela inicial: "2025.2" (disciplinas), "Trabalho", "Monitoria"… A tela
inicial mostra a junção, **avisa conflito de horário**, mostra eventos;
deslizar/escolher continua permitindo ver uma tabela só. Arquivar a tabela
do período tira ela da junção (responde o "encerrar período"). Pontos da
crítica: tabelas têm horários (slots) e dias diferentes → a junção precisa
de eixo de tempo real, não de células; onde edita; vigência opcional.

Decidido:
- **"Ignorar esse conflito"** pra sobreposição proposital (almoço dentro
  do trabalho).
- **Vigência opcional** (início/fim) na tabela: entra e sai da junção
  sozinha; sem vigência, fica ativa até arquivar.
- **Disciplina sempre exclusiva da tabela do período** (notas/faltas
  ficam separadas por período); arquivar a tabela leva as disciplinas pro
  Histórico com a média final; **"Cursar de novo"** cria um item novo no
  período novo (copia nome, cor, professor, regra de média; zera notas e
  faltas). Academia, Almoço, Trabalho etc. continuam compartilhados.

- **Junção desenhada pelo relógio** (régua de horas, blocos com altura
  pela duração, sobreposição lado a lado com ⚠) — decidido. A grade de
  células continua dentro de cada tabela.
- **Chips** (quais tabelas entram na junção) **e deslizar** (ver uma
  tabela sozinha) — decidido.
- **Junção também edita** (usuário recusou "só pra ver": segurar/tocar na
  tela inicial é central na usabilidade):
  - **Segurar bloco** → menu de hoje com cabeçalho "SO · ter 09–11 · em
    2025.2": Novo evento para SO, Faltei hoje (Disciplina), Trocar item,
    Limpar horário, e "Outras tabelas neste horário" (avisa conflito).
  - **Segurar vazio** → "Novo evento às HH:MM" + "Pôr item", listando só
    as tabelas com horário naquele momento (só uma → direto; última usada
    primeiro). **A UI deixa explícito que o item entra numa tabela**:
    rótulo "Pôr item em Trabalho · 14–18" mesmo quando é a única opção, e
    confirmação "SO adicionado em 2025.2 · ter 09–11".
  - Nenhuma tabela com horário ali → **"Criar horário aqui em…"** (nova
    linha na tabela escolhida).
  - **Tocar num bloco** → editor do dia da tabela daquele bloco.

### Itens tipados — ideia original

Mesma repaginação de Eventos aplicada a Itens: tipos fixos com campos
próprios — **Disciplina** (notas/média, links úteis, materiais, faltas?),
**Treino** (exercícios customizáveis), **Trabalho** etc. — e a aba Itens
organizada por tipo (cards como Eventos, ou outro formato). Hoje
`Item.tipo` é texto livre com autocomplete.

- **Prioridade: três níveis** (alta, normal, baixa).
- **Local da Consulta: busca automática** pelo geocodificador do Android
  (grátis, sem chave; canal Kotlin próprio) com sugestões e aviso "não
  encontrei esse endereço"; guarda coordenadas; botão **"Ver no mapa"**
  abre o Maps pra conferir. Sem mapa embutido (exigiria chave de API).
- **Itens tipados = próxima rodada de discussão**, depois de fechar
  Eventos.

- **Sem chip "Outro" na folha de criação**: evento sem tipo (ou da agenda
  comum do Google) cai no card Outros.
- **Quantidade nos cards**: regra geral = próximos 30 dias + linha com o
  próximo. Provas: + "N notas pra lançar" se prova passou sem nota.
  Reuniões e Outros: **esta semana**. Viagens: "Em viagem · volta …"
  durante. (Tarefas, Aniversários, Feriados como acima.)
- **Enfeite só automático** (lista embutida, casa pela data; todo
  Aniversário ganha confete) — sem campo na folha.

**Eventos fechado na spec (2026-11-11).** Próximo: Itens tipados.

## Ideias futuras (anotadas em 2026-11-10)

Nada decidido nem desenhado ainda — só o que ficou na mesa ao fim do dia.

- **"Esta semana" fechada mostrar todos os eventos de hoje**, não só o
  próximo; o botão "Ver mais" ficaria pros dias seguintes. Em dia de prova
  + consulta, os dois aparecem sem abrir nada.
- **Vincular evento do Google a item pela sigla** no título ("Prova SO" →
  SO): sugerir, não vincular sozinho (sigla pode ser palavra comum).
- **Viagem de vários dias**: hoje "Viagem" é dia todo de um dia só.
- **Navegar entre semanas na grade** (hoje só a atual; pra frente, só pelo
  calendário).
- **Editar uma ocorrência só** de evento recorrente.
- **Chave de assinatura própria** pra release, antes de distribuir pra
  mais gente. Hoje a release assina com a chave de debug deste computador:
  atualização gerada em outra máquina é recusada pelo Android, e a pessoa
  teria que desinstalar e perder os dados.

- **Adicionar tarefa pela Alexa** (2026-11-11, prioridade alta pro
  usuário, mas só depois das tarefas locais existirem). As listas nativas
  da Alexa fecharam pra terceiros em 01/07/2024 (List Management API
  descontinuada; Todoist/AnyList perderam a integração), então "Alexa,
  adiciona X na minha lista" não chega no app. Caminho viável: **skill
  própria** em pt-BR, modo desenvolvimento (sem certificação; parceira
  entra como beta tester) — "Alexa, pede pro Tabelador adicionar X". A
  skill grava numa fila na internet (Alexa-hosted ou servidor pequeno na
  VPS Hetzner), protegida por um token de pareamento que o app mostra uma
  vez; o app puxa a fila ao abrir/voltar (mesmo gancho do widget) e talvez
  em segundo plano. Primeira peça do app que depende de servidor/internet.
  Descartado: API privada da Amazon com login (frágil, expõe credencial).

- **Integração com o Wellio** (outro projeto do usuário, `~/Projetos/wellio`:
  app Android Kotlin/Compose + Room, offline, de água, alimentação e
  exercício). Futuro — especificação de intenção, o "como" se decide ao
  implementar. Ver seção "Integração com o Wellio" abaixo.

## Integração com o Wellio (futuro, especificado em 2026-11-11)

**Divisão de papéis**: Tabelador = **organizacional** (quando, o quê,
fez ou não); Wellio = **informacional** (kcal, macros, METs, metas,
histórico). Nada de caloria entra no Tabelador.

**O que já existe no Wellio e casa com o Tabelador** (SPEC dele, §4.1):
- `exercise_type` (base do Compendium, 67 atividades com níveis Leve /
  Moderada / Intensa) e `workout_template` + `workout_template_item`
  (exercício + minutos) — equivale a "um treino" da ficha do Tabelador.
- `food_item` (TACO + extras + próprios) com `food_portion` (medidas
  caseiras) e `food_entry.meal` (café da manhã, almoço, lanche, jantar,
  ceia) — equivale ao cardápio de um item Alimentação.
- O Wellio já prevê "registrar com ajuste antes de confirmar" (modelos de
  treino, repetir refeição) — o envio do Tabelador deve cair nesse mesmo
  fluxo, não gravar direto.

**Princípios pra ficar coerente**:
1. **Vocabulário do Wellio**: exercícios e alimentos da ficha/cardápio
   são escolhidos da base do Wellio (quando instalado), não digitados
   livres — senão "Supino" de um lado não casa com nada do outro.
   Treino da ficha pode simplesmente **apontar pra um modelo de treino
   do Wellio**; refeição, pra uma lista de alimentos + medida.
2. **Funciona sem o Wellio**: sem ele instalado (ex.: parceira), a ficha
   e o cardápio são texto simples locais e não aparece "Enviar".
3. **Envio = Intent explícito** pro Wellio (mesmo aparelho, sem servidor)
   abrindo a confirmação dele já preenchida (data, horário, refeição,
   itens, minutos). Leitura do catálogo do Wellio por um
   `ContentProvider` exportado.
4. **Só os dois apps conversam**: permissão com `protectionLevel=
   "signature"` — exige os dois assinados com a **mesma chave** (hoje
   ambos usam a de debug desta máquina; ver "chave de assinatura
   própria").
5. Treino de força detalhado (séries/reps/carga) é "para depois" no
   Wellio (§13.3.2); no Tabelador pode existir antes, como organização.

**Sobreposição a resolver**: o Wellio planeja (§13.2, M8) um
"Planejamento da semana" com treinos e refeições por dia/horário
(`plan_item`). Isso é o que a grade do Tabelador já faz. Decidir quem
planeja: provavelmente o Tabelador planeja e o Wellio registra, e o
§13.2 do Wellio passa a ler o plano do Tabelador em vez de ter o seu.
## Pontos em aberto

- **`tipo` como texto livre com autocomplete** vs. entidade cadastrável com CRUD próprio. Texto livre foi escolhido por simplicidade; se `tipo` acabar precisando de ícone ou comportamento próprio, vira entidade.
- **Duplicar tabela com item exclusivo**: `duplicarTabela` copia a grade inteira, célula por célula. Se uma célula copiada referenciava um item exclusivo da tabela ORIGINAL, a célula da cópia continua mostrando ele certinho (resolve por id, sem filtro), mas ele não aparece na paleta da cópia pra reusar em outro horário dela — o item continua vinculado só à original. Não chegou a incomodar no uso real; se incomodar, a saída é re-vincular (ou clonar) os itens exclusivos junto com a duplicação.
- **Plugin `home_widget` e Kotlin Gradle Plugin**: o build avisa que uma versão futura do Flutter vai parar de compilar plugins que aplicam KGP do jeito antigo (aviso, não erro, desde a Fase 8). Não é urgente, mas vale acompanhar o changelog do pacote antes de um upgrade grande de Flutter.
