import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../model/evento.dart';
import '../state/app_state.dart';
import '../util/tarefas.dart';
import 'today_schedule_snapshot.dart';

/// Nome do receiver Android que recebe o broadcast de atualização — precisa
/// bater com o `<receiver>` do AndroidManifest.
const String kTodayScheduleWidgetReceiver = 'TodayScheduleWidgetReceiver';

/// Widget "Próximo" (2×2): lê o mesmo snapshot.
const String kNextUpWidgetReceiver = 'NextUpWidgetReceiver';

/// Widget de Tarefas: lê o mesmo snapshot (`tasks`).
const String kTasksWidgetReceiver = 'TasksWidgetReceiver';

/// Chaves (JSON, lista de `LinhaTarefa.chave`) que o widget de Tarefas
/// grava ao marcar: riscadas (os ~2 s antes de sumir) e feitas. O app
/// conclui de verdade na próxima sincronização e limpa as duas.
const String kTarefasRiscadasKey = 'tarefas_riscadas_widget';
const String kTarefasFeitasKey = 'tarefas_feitas_widget';

const String kTodayScheduleJsonKey = 'today_schedule_json';

/// Mantém o widget nativo sincronizado com o [AppState].
///
/// Ouve um único listener de [AppState] (que já chama `notifyListeners()` em
/// toda mutação) em vez de listar manualmente quais mutators "importam" —
/// editar só a sigla ou a cor de um item, sem tocar em nenhuma célula, também
/// muda o que o widget mostra, e listar mutators um a um é fácil de esquecer
/// no próximo que alguém adicionar.
class HomeWidgetSync {
  HomeWidgetSync(this._appState) {
    _appState.addListener(_agendar);
  }

  final AppState _appState;

  ColorScheme? _claro;
  ColorScheme? _escuro;
  String? _ultimoJson;
  bool _sincronizando = false;
  bool _pendente = false;

  /// Chamado a cada build do `DynamicColorBuilder`, em `main.dart` — é como o
  /// snapshot enxerga o Monet real do sistema em vez de reinventar um
  /// fallback só de semente.
  void atualizarEsquemas(ColorScheme claro, ColorScheme escuro) {
    _claro = claro;
    _escuro = escuro;
    _agendar();
  }

  void _agendar() => unawaited(sincronizarAgora());

  /// Reconstrói o snapshot e manda pro nativo só se algo mudou.
  ///
  /// Chamada em toda mutação de [AppState] e também explicitamente quando o
  /// app volta pro primeiro plano — o Android não garante refresh de widget
  /// em background, então esse é o reforço combinado com o tick natural do
  /// SO (`updatePeriodMillis`).
  Future<void> sincronizarAgora() async {
    if (!_appState.carregado) return;
    final claro = _claro;
    final escuro = _escuro;
    if (claro == null || escuro == null) return;

    // Já tem uma sincronização em voo: marca que precisa rodar de novo assim
    // que ela terminar, em vez de empilhar chamadas concorrentes.
    if (_sincronizando) {
      _pendente = true;
      return;
    }

    _sincronizando = true;
    try {
      await _aplicarFeitasNoWidget();
      var repetir = true;
      while (repetir) {
        repetir = false;
        final json = construirSnapshotJson(
          tabelaAtiva: _appState.tabelaAtiva,
          itemPorId: _appState.itemPorId,
          densidade: _appState.densidade,
          claro: claro,
          escuro: escuro,
          ocorrencias: _ocorrenciasDaJanela(),
          dias: _diasAFrente + 1,
          tarefas: organizarTarefas(_appState.tarefas, DateTime.now(), _appState.primeiroDiaDaSemana),
          primeiroDia: _appState.primeiroDiaDaSemana,
        );
        if (json != _ultimoJson) {
          _ultimoJson = json;
          await HomeWidget.saveWidgetData<String>(kTodayScheduleJsonKey, json);
          for (final receiver in [kTodayScheduleWidgetReceiver, kNextUpWidgetReceiver, kTasksWidgetReceiver]) {
            await HomeWidget.updateWidget(androidName: receiver);
          }
        }
        if (_pendente) {
          _pendente = false;
          repetir = true;
        }
      }
    } finally {
      _sincronizando = false;
    }
  }

  /// Conclui o que foi marcado no widget de Tarefas enquanto o app estava
  /// fechado. Riscadas contam: o widget só não terminou os ~2 s.
  Future<void> _aplicarFeitasNoWidget() async {
    final chaves = <String>{};
    for (final k in [kTarefasRiscadasKey, kTarefasFeitasKey]) {
      final bruto = await HomeWidget.getWidgetData<String>(k);
      if (bruto == null || bruto.isEmpty) continue;
      try {
        chaves.addAll((jsonDecode(bruto) as List).cast<String>());
      } on FormatException {
        // Lixo: só descarta.
      }
    }
    if (chaves.isEmpty) return;
    await _appState.concluirPeloWidget(chaves);
    await HomeWidget.saveWidgetData<String>(kTarefasRiscadasKey, null);
    await HomeWidget.saveWidgetData<String>(kTarefasFeitasKey, null);
  }

  /// Hoje e os próximos [_diasAFrente] dias. A janela começa na meia-noite
  /// de hoje, então o JSON muda uma vez por dia — o suficiente pra
  /// [sincronizarAgora] mandar de novo ao abrir o app no dia seguinte.
  static const _diasAFrente = 7;

  List<Ocorrencia> _ocorrenciasDaJanela() {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    // Tarefa concluída sai do widget: ele mostra o que ainda falta.
    return _appState
        .ocorrenciasEntre(
          hoje,
          DateTime(hoje.year, hoje.month, hoje.day + _diasAFrente + 1),
        )
        .where((o) => !o.feita)
        .toList();
  }

  void dispose() {
    _appState.removeListener(_agendar);
  }
}
