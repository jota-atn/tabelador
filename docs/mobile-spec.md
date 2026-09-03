# Especificação: Tabelador Mobile (Android + Widget)

> Status: **roadmap original completo** (fases 1–10) e um bloco de polimento pós-roadmap já implementado também: itens arquiváveis e vinculáveis a uma única tabela, tela dedicada por tabela, editor do dia repaginado (paleta em lista, toque pra armar, desfazer), grade da semana com swipe entre tabelas/toque longo/linha do agora, e navegação/formulários responsivos pra tela larga. Ver "Depois do roadmap original" pro detalhe de cada um.
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
- **Grade**: dias fixos Segunda a Sexta; hora inicial, intervalo e quantidade de horários configuráveis **por tabela** (igual ao script).
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
  "dayLabel": "TERÇA",
  "hasClassesToday": true,
  "slots": [
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
  ]
}
```

Cores já resolvidas em hex, porque `RemoteViews` não tem como consultar a paleta do Flutter em runtime.

O widget **segue a densidade escolhida no app** — se a grade está em Sólido e o widget continua em Discreto, parece defeito. Por isso o snapshot carrega fundo, texto e filete já resolvidos por slot, com `barWidthDp: 0` significando "sem filete". O widget segue burro: pinta o que recebe, sem conhecer densidade nem paleta.

## Telas

1. **Visão semana** (tela inicial) — a grade 5×6 completa em chrome neutro, cada célula ocupada renderizada na densidade escolhida, só leitura no sentido de não arrastar. É a cara do projeto: o `tablefmt='fancy_grid'` do script virando UI. Hoje aparece destacado, e uma linha fina marca a hora atual (proporcional ao expediente da tabela, só em dia útil). Toque num dia abre o editor daquele dia; toque longo numa célula edita só ela, sem entrar no dia inteiro. Com duas ou mais tabelas, arrastar a grade na horizontal troca qual está ativa (mesmo swipe que o editor do dia usa entre dias) — além do seletor no topo.
2. **Tela dedicada de uma tabela** — aberta a partir de um card em Tabelas (ou ao criar uma nova). Mesma grade e mesmo editor de dia da visão semana, mas amarrada à tabela que você tocou, com título fixo em vez de seletor — resolve o card em Tabelas só "ativar" e não levar a lugar nenhum.
3. **Editor do dia** — os horários daquele dia como linhas largas (alvo de toque confortável), paleta de itens logo abaixo, numa lista só que cresce pra baixo (não mais bandeja horizontal com scroll). Preencher um horário tem dois caminhos que convivem: arrastar o item da paleta, ou tocar nele pra "armar" (contorno visível) e depois tocar no horário — mais confiável que arrastar em tela pequena ou dedo grande, e fica armado entre horários/dias pra encaixar o mesmo item várias vezes seguidas. Limpar um horário (arrastando pra fora, ou "Deixar vazio") mostra um snackbar com "Desfazer". Um atalho na própria paleta cria item exclusivo desta tabela sem sair da tela. Navegação entre dias por swipe ou setas.
4. **Biblioteca de itens** — CRUD dos itens: nome, sigla, tipo, cor, local, notas, e o vínculo com uma tabela (compartilhado ou exclusivo de uma). Menu por item com Arquivar/Desarquivar além de Apagar; arquivados ficam numa seção recolhida no fim da lista.
5. **Lista de tabelas** — criar, renomear, duplicar, apagar, marcar como ativa; configurar hora inicial/intervalo/quantidade. Tocar num card ativa e já abre a tela dedicada dela (item 2). Menu por tabela ganha "Arquivar itens exclusivos": revisão em lote dos itens que só aparecem ali, pré-marcados mas editável (item recorrente tipo Almoço pode ser desmarcado) antes de confirmar. Apagar uma tabela avisa também quantos itens exclusivos dela somem junto.
6. **Aparência** — escolha da densidade de cor, apresentada como três grades semanais em miniatura. Preferência global, aplicada na hora e propagada pro widget.

### Interação de arrastar
- `Draggable` / `DragTarget` do Flutter. Long-press pra pegar (300ms), com feedback háptico e um leve aumento de escala no item durante o arrasto.
- Slot ocupado destaca no hover e substitui o conteúdo ao soltar.
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
- Redimensionável, com `targetCellWidth`/`targetCellHeight` (Android 12+): em tamanho pequeno mostra os próximos 2–3 horários, em tamanho grande o dia inteiro.
- Toque no widget abre o app na visão semana.

### Refresh
O Android não garante refresh exato de widget em background — `updatePeriodMillis` tem mínimo de 30 min e é tratado como sugestão (pode atrasar mais em Doze mode). **Decisão**: aceitar esse atraso natural (ninguém olha o widget às 00:00:01) e complementar com refresh forçado sempre que o app abre ou uma tabela é salva/ativada.

Agendamento exato via `android_alarm_manager_plus` foi descartado: exige `SCHEDULE_EXACT_ALARM` (Android 12+), permissão desproporcional ao ganho.

## Stack

- **Flutter** (Dart), projeto isolado em `mobile/` — não mistura com o script Python. Fixado no fvm stable via `.fvmrc`.
- **Estado**: `provider` (ChangeNotifier).
- **Persistência**: `shared_preferences` + JSON.
- **Widget nativo**: pacote `home_widget` (ponte Flutter → `AppWidgetProvider` Android).
- **Tema**: `dynamic_color`.

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

## Pontos em aberto

- **`tipo` como texto livre com autocomplete** vs. entidade cadastrável com CRUD próprio. Texto livre foi escolhido por simplicidade; se `tipo` acabar precisando de ícone ou comportamento próprio, vira entidade.
- **Sábado**: a grade é Seg–Sex, herdado do script. Nada impede tornar os dias configuráveis depois, mas não está no escopo.
- **Duplicar tabela com item exclusivo**: `duplicarTabela` copia a grade inteira, célula por célula. Se uma célula copiada referenciava um item exclusivo da tabela ORIGINAL, a célula da cópia continua mostrando ele certinho (resolve por id, sem filtro), mas ele não aparece na paleta da cópia pra reusar em outro horário dela — o item continua vinculado só à original. Não chegou a incomodar no uso real; se incomodar, a saída é re-vincular (ou clonar) os itens exclusivos junto com a duplicação.
- **Plugin `home_widget` e Kotlin Gradle Plugin**: o build avisa que uma versão futura do Flutter vai parar de compilar plugins que aplicam KGP do jeito antigo (aviso, não erro, desde a Fase 8). Não é urgente, mas vale acompanhar o changelog do pacote antes de um upgrade grande de Flutter.
