# Especificação: Tabelador Mobile (Android + Widget)

> Status: **roadmap original completo** (fases 1–10) e um bloco de polimento pós-roadmap já implementado também: itens arquiváveis e vinculáveis a uma única tabela, tela dedicada por tabela, editor do dia repaginado (paleta em lista, toque pra armar, desfazer), grade da semana com swipe entre tabelas/toque longo/linha do agora, navegação/formulários responsivos pra tela larga, exportar/importar backup, dias configuráveis por tabela, e notificação de horário se aproximando. Ver "Depois do roadmap original" pro detalhe de cada um.
>
> Revisão **v2** (2026-08-10): o modelo de dados mudou. O v1 previa cores hardcoded e a grade como matriz de strings cruas. Agora cada célula referencia uma **entidade cadastrada** (disciplina/atividade), com cor própria, e a edição é por arrastar.

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
calendário mensal) e fase 2 (ler do Google Agenda) implementadas. Fase 3
(gravar no Google) ainda não começou.

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

### Limitações conhecidas

- Grade mostra só a semana atual (sem navegar pra próxima); pra frente, usar
  o calendário.
- Evento que começou num dia anterior e ainda está acontecendo não aparece
  em "Próximos" nem na grade (só olham o dia de início).
- Editar só uma ocorrência de recorrente: não existe.
- Evento do Google não é editável no app, nem vinculável a item ainda.
- Calendário além da janela de leitura (2 meses atrás, ~13 meses à frente)
  mostra só os eventos do app.
- Aviso às 8h vale pra todo evento de dia inteiro, feriado incluído.

### Próximos passos

1. ~~Eventos locais~~ (feito).
2. ~~Ler do Google~~ (feito). Pendente dessa fase: sugerir vínculo de
   evento do Google com item pela sigla no título.
3. Gravar no Google (agenda de destino, "salvar no Google Agenda" no
   formulário, padrão ligado se houver agenda configurada).
4. ~~Eventos no widget, notificação de evento~~ (feito).

## Onboarding (planejado, não implementado)

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

Fica pra depois da gravação no Google, pra o passo 3 já sair completo.

## Pontos em aberto

- **`tipo` como texto livre com autocomplete** vs. entidade cadastrável com CRUD próprio. Texto livre foi escolhido por simplicidade; se `tipo` acabar precisando de ícone ou comportamento próprio, vira entidade.
- **Duplicar tabela com item exclusivo**: `duplicarTabela` copia a grade inteira, célula por célula. Se uma célula copiada referenciava um item exclusivo da tabela ORIGINAL, a célula da cópia continua mostrando ele certinho (resolve por id, sem filtro), mas ele não aparece na paleta da cópia pra reusar em outro horário dela — o item continua vinculado só à original. Não chegou a incomodar no uso real; se incomodar, a saída é re-vincular (ou clonar) os itens exclusivos junto com a duplicação.
- **Plugin `home_widget` e Kotlin Gradle Plugin**: o build avisa que uma versão futura do Flutter vai parar de compilar plugins que aplicam KGP do jeito antigo (aviso, não erro, desde a Fase 8). Não é urgente, mas vale acompanhar o changelog do pacote antes de um upgrade grande de Flutter.
