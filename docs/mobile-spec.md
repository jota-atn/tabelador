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
- **Material 3** com **cores dinâmicas (Monet)** — a paleta do app segue o wallpaper do sistema, via pacote `dynamic_color`, com `ColorScheme.fromSeed` como fallback em aparelhos que não expõem o Monet.
- **Tema claro e escuro** seguindo o do sistema.
- O widget segue as regras de widget do **Android 12+**: cantos arredondados do sistema, fundo adaptativo, redimensionamento responsivo. Alvo de teste: Poco M5 Pro 5G.

### Dados
- **Múltiplas tabelas nomeadas** (ex: "2026.1", "2026.2"), uma marcada como **ativa**.
- **Biblioteca de itens compartilhada** entre tabelas — "Cálculo II" cadastrado uma vez serve pra qualquer semestre.
- **Grade**: dias fixos Segunda a Sexta; hora inicial, intervalo e quantidade de horários configuráveis **por tabela** (igual ao script).
- **Cor mora na entidade**, não em regra de texto. ALMOÇO e LIVRE viram itens cadastrados como qualquer outro — o `dict cores` hardcoded do Python deixa de existir.

### Cores: paleta curada, não seletor livre
Cada item guarda uma **chave de cor** (ex: `tomato`, `sage`, `indigo`), não um RGB solto. O app resolve essa chave pros papéis tonais do M3 (`colorContainer` / `onColorContainer`) em cada tema.

Motivo: cor arbitrária escolhida num color picker fica ilegível no tema escuro, ou briga com a paleta dinâmica do sistema. Com chave + papel tonal, a mesma disciplina fica legível no claro, no escuro e no widget sem o usuário precisar pensar em contraste. Paleta prevista: ~12 tons bem separados no círculo cromático, o suficiente pra uma grade semanal sem repetir.

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
      "colorLight": "#FFD8E4",
      "colorDark": "#4A2532",
      "onColorLight": "#31111D",
      "onColorDark": "#FFD8E4"
    }
  ]
}
```

Cores já resolvidas em hex nos dois temas, porque `RemoteViews` não tem como consultar a paleta do Flutter em runtime.

## Telas

1. **Visão semana** (tela inicial) — a grade 5×6 completa, colorida, só leitura. É a cara do projeto: o `tablefmt='fancy_grid'` do script virando UI. Toque num dia abre o editor daquele dia. Seletor de tabela ativa no topo.
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
- Cantos arredondados via `system_app_widget_background_radius`; fundo usando as cores do sistema (`@android:color/system_accent1_*` no Android 12+) pra combinar com a tela inicial.
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
