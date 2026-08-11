# Especificação: Tabelador Mobile (Android + Widget)

> Status: **planejamento / scaffold criado** — o projeto Flutter existe em `mobile/`, mas ainda é o app padrão. Nenhuma tela do Tabelador foi implementada.
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
- **Poucas linhas**: o `fancy_grid` do script é 100% borda; aqui, espaçamento resolve a separação e fios de `outlineVariant` aparecem só onde a leitura exige.
- **Estados vazios sem enfeite**: slot livre é espaço em branco com um rótulo discreto, não um card cinza cheio de ícone.

### Dados
- **Múltiplas tabelas nomeadas** (ex: "2026.1", "2026.2"), uma marcada como **ativa**.
- **Biblioteca de itens compartilhada** entre tabelas — "Cálculo II" cadastrado uma vez serve pra qualquer semestre.
- **Grade**: dias fixos Segunda a Sexta; hora inicial, intervalo e quantidade de horários configuráveis **por tabela** (igual ao script).
- **Cor mora na entidade**, não em regra de texto. ALMOÇO e LIVRE viram itens cadastrados como qualquer outro — o `dict cores` hardcoded do Python deixa de existir.

### Cores: paleta curada, não seletor livre

Cada item guarda uma **chave de cor**, não um RGB solto. A chave define uma semente em HCT (hue + chroma) e o app gera a rampa tonal com `material_color_utilities` — que já vem junto do Flutter, não é dependência nova.

Motivo: cor arbitrária de color picker fica ilegível no tema escuro ou briga com a paleta dinâmica do sistema. Hardcodar hex por tema seria 4 valores × 12 cores pra manter em sincronia. Com semente, ajustar um tom é mexer num número, e o widget resolve os mesmos tons na hora de montar o snapshot.

| chave | nome | hue HCT | uso típico |
|---|---|---|---|
| `tomate` | vermelho | 25 | monitoria, prova |
| `tangerina` | laranja | 55 | |
| `ambar` | amarelo | 85 | almoço, pausa |
| `oliva` | verde-oliva | 110 | |
| `salvia` | verde suave | 135 | livre |
| `esmeralda` | verde | 165 | |
| `turquesa` | ciano | 195 | |
| `oceano` | azul | 235 | |
| `indigo` | azul-violeta | 275 | |
| `ametista` | roxo | 305 | |
| `framboesa` | rosa | 345 | |
| `grafite` | neutro | chroma ~6 | slot sem importância |

Chroma ~50 nas cromáticas, pra todas parecerem da mesma família em vez de um saco de cores avulsas.

Os gaps de hue variam de 25° a 40° em vez de 30° cravado: verde ocupa uma faixa enorme do espectro e amarelo-laranja é apertado, então espaçar uniformemente daria três verdes quase iguais e nenhum laranja decente. `oliva` (110) e `salvia` (135) são o par mais arriscado — validar na tela de prévia e afastar se preciso.

### Aplicação da cor: barra de acento

Preenchimento de célula foi **descartado**. Numa grade 5×6 são até 30 blocos coloridos simultâneos — vira colcha de retalhos e contradiz o princípio minimalista.

A célula ocupada é **fundo neutro + texto neutro + filete colorido de 3dp na lateral**. A cor ocupa ~5% dos pixels da célula: identifica de relance sem dominar a tela. Como a área é minúscula, o filete usa chroma cheio.

| | filete | fundo da célula | texto |
|---|---|---|---|
| tema claro | tom 40 | `surfaceContainer` | `onSurface` |
| tema escuro | tom 80 | `surfaceContainer` | `onSurface` |

Tons 40/80 são os mesmos que o M3 usa pra cor de acento sobre superfície neutra, então o contraste vem garantido pelo sistema — o usuário nunca escolhe uma combinação ilegível, porque não escolhe combinação nenhuma, só a chave.

**A cor é reforço, nunca a única informação.** A sigla está sempre visível na célula e no widget. Isso importa porque `tomate` e `esmeralda` são praticamente o mesmo tom pra quem tem deuteranopia (~8% dos homens): com a sigla ali, a cor é codificação redundante, não o único jeito de distinguir uma disciplina da outra.

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
  String? professor;   // opcional
  String? notas;       // opcional
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
      "accentLight": "#8C4A5E",
      "accentDark": "#FFB1C6"
    }
  ]
}
```

Cores já resolvidas em hex, porque `RemoteViews` não tem como consultar a paleta do Flutter em runtime. Como a cor virou só o filete, cada slot carrega **um** acento por tema em vez de par fundo/texto — o fundo e o texto do widget saem das cores neutras do sistema.

## Telas

1. **Visão semana** (tela inicial) — a grade 5×6 completa em fundo neutro, cada célula ocupada com seu filete de acento, só leitura. É a cara do projeto: o `tablefmt='fancy_grid'` do script virando UI. Toque num dia abre o editor daquele dia. Seletor de tabela ativa no topo.
2. **Editor do dia** — os horários daquele dia como linhas largas (alvo de toque confortável), paleta de itens fixa embaixo. Arrasta o item da paleta pra linha do horário. Navegação entre dias por swipe ou setas.
3. **Biblioteca de itens** — CRUD dos itens: nome, sigla, tipo, cor, local, professor, notas.
4. **Lista de tabelas** — criar, renomear, duplicar, apagar, marcar como ativa; configurar hora inicial/intervalo/quantidade.

### Interação de arrastar
- `Draggable` / `DragTarget` do Flutter. Long-press pra pegar, com feedback háptico.
- Slot ocupado destaca no hover e substitui o conteúdo ao soltar.
- **Tap-to-assign como caminho alternativo**: tocar num slot vazio abre um bottom sheet com a lista de itens. Arrastar é o gesto principal, mas nunca o único — acessibilidade e dedo grande agradecem.
- Esvaziar um slot: arrastar pra fora, ou swipe na linha.
- Arrastar de um slot pra outro **move** o item dentro do dia.

## Widget de tela inicial

- Mostra **só o dia de hoje** da tabela ativa.
- Fim de semana / dia sem nada: estado vazio explícito, não widget em branco.
- Cantos arredondados via `system_app_widget_background_radius`; fundo e texto usando as cores **neutras** do sistema (`@android:color/system_neutral1_*` no Android 12+), com o filete colorido de cada linha como único ponto de chroma. Assim ele convive com os outros widgets da tela inicial em vez de gritar.
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

1. ~~Scaffold do app Flutter~~ ✅ feito — `mobile/`, org `com.jota`, só Android.
2. Tema M3 + cores dinâmicas + paleta curada de cores de item.
3. Modelo (`Item`, `Tabela`) + persistência + provider.
4. Biblioteca de itens (CRUD) e lista de tabelas.
5. Visão semana (só leitura).
6. Editor do dia com arrastar.
7. Widget nativo Android (XML, `AppWidgetProvider` Kotlin, manifest) + snapshot.
8. Estratégia de refresh (foreground + tick natural do SO).
9. Polimento: estados vazios, ícone, preview do widget.

## Pontos em aberto

- **`tipo` como texto livre com autocomplete** vs. entidade cadastrável com CRUD próprio. Texto livre foi escolhido por simplicidade; se `tipo` acabar precisando de ícone ou comportamento próprio, vira entidade.
- **Itens compartilhados entre tabelas** pode incomodar se a biblioteca crescer com disciplinas de semestres antigos. Solução prevista se doer: marcar item como arquivado, escondendo-o da paleta sem apagar.
- **Sábado**: a grade é Seg–Sex, herdado do script. Nada impede tornar os dias configuráveis depois, mas não está no escopo.
