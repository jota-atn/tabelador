# Especificação: Tabelador Mobile (Android + Widget)

> Status: **planejamento** — ainda não implementado. Este documento descreve a ideia e as decisões já tomadas, pra quando a implementação começar de fato.

## Ideia

Portar a ideia do `tabelador.py` (script CLI que gera e colore tabelas de horário no terminal) pra um app Android simples, com um widget de tela inicial pra visualizar o horário do dia sem precisar abrir o app.

## Decisões já confirmadas

- **Plataforma**: só Android por enquanto (sem Mac disponível pra iOS).
- **Múltiplas tabelas salvas**: o usuário pode ter várias tabelas nomeadas (ex: "2026.1", "2026.2"), com uma marcada como "ativa".
- **Widget**: mostra só o horário de **hoje** da tabela ativa (não a semana inteira).
- **Estrutura da grade**: igual ao script original — dias fixos Segunda a Sexta; hora inicial, intervalo entre horários e quantidade de horários são configuráveis por tabela.
- **Cores por palavra-chave**: fixas (hardcoded) no v1, espelhando o dict `cores` do Python — MONITORIA=vermelho, ALMOÇO/ALMOCO=amarelo, LIVRE=verde, cabeçalho=azul, padrão=branco. Não editável pelo usuário nessa versão.

## Stack planejada

- **Flutter** (Dart), projeto isolado em `mobile/` na raiz do repo (não mistura com o script Python).
- **Estado**: `provider` (ChangeNotifier simples).
- **Persistência local**: `shared_preferences` + JSON (uma chave com a lista de tabelas, outra com o id da tabela ativa). Motivo: escala real é pequena (poucas tabelas, ~30 strings curtas cada), não justifica Hive/sqflite.
- **Widget nativo**: pacote `home_widget`, que faz a ponte Flutter → `AppWidgetProvider` Android via um `SharedPreferences` nativo separado.

## Modelo de dados (rascunho)

```dart
class ScheduleTable {
  final String id;
  String name;
  int startHour;      // default 8
  int interval;        // default 2
  int slotCount;        // default 6
  Map<String, List<String>> grid; // 'SEGUNDA'..'SEXTA' -> lista de tamanho slotCount
  DateTime createdAt;
  DateTime updatedAt;
}
```

Snapshot enviado pro widget nativo (JSON, uma chave `today_schedule_json`):
```json
{
  "tableName": "2026.1",
  "dayLabel": "TERÇA",
  "hasClassesToday": true,
  "slots": [{"time": "8:00-10:00", "activity": "MONITORIA", "colorKey": "red"}]
}
```

## Telas planejadas

1. **Lista de tabelas** — criar, renomear, duplicar, apagar, marcar como ativa.
2. **Editor de tabela** — grade editável (dia x horário) + configuração de hora inicial/intervalo/quantidade.

## Refresh do widget (decisão de design)

O Android não garante refresh exato de widgets em background — `updatePeriodMillis` tem mínimo de 30 min e é tratado como sugestão pelo SO (pode atrasar mais em Doze mode). Decisão: aceitar esse atraso natural (ninguém olha o widget às 00:00:01) e complementar com refresh forçado sempre que o app é aberto ou uma tabela é salva/ativada. Agendamento exato via `android_alarm_manager_plus` foi descartado por exigir permissão especial (`SCHEDULE_EXACT_ALARM`, Android 12+) desproporcional ao ganho.

## Roadmap de implementação (quando retomar)

1. Scaffold do app Flutter + modelo + persistência + telas CRUD (sem widget ainda).
2. Scaffolding nativo do widget Android (XML, `AppWidgetProvider` Kotlin, manifest) + fluxo de dados manual.
3. Estratégia de refresh (foreground + tick natural do SO).
4. Polimento: estados vazios, paridade de cores com o script original, ícone, preview do widget.

Plano detalhado (arquivos concretos, ordem de setup, testes por fase) fica salvo separadamente em `/home/jota/.claude/plans/pure-honking-dahl.md` até a implementação começar.
