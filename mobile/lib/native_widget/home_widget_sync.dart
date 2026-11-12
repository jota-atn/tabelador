import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../model/evento.dart';
import '../state/app_state.dart';
import 'today_schedule_snapshot.dart';

/// Nome do receiver Android que recebe o broadcast de atualização — precisa
/// bater com o `<receiver>` do AndroidManifest.
const String kTodayScheduleWidgetReceiver = 'TodayScheduleWidgetReceiver';

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
        );
        if (json != _ultimoJson) {
          _ultimoJson = json;
          await HomeWidget.saveWidgetData<String>(kTodayScheduleJsonKey, json);
          await HomeWidget.updateWidget(
            androidName: kTodayScheduleWidgetReceiver,
          );
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
