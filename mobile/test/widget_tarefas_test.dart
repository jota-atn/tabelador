import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/native_widget/today_schedule_snapshot.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/theme/color_density.dart';
import 'package:tabelador/util/tarefas.dart';

Evento _tarefa(String id, String titulo, {DateTime? inicio, Repeticao repeticao = Repeticao.nenhuma, Prioridade prioridade = Prioridade.normal}) =>
    Evento(
      id: id,
      titulo: titulo,
      inicio: inicio ?? DateTime(2026, 11, 25),
      diaInteiro: true,
      semData: inicio == null,
      tipo: 'Tarefa',
      repeticao: repeticao,
      prioridade: prioridade,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final agora = DateTime(2026, 11, 25, 10);

  test('chave da linha volta pra mesma ocorrência, inclusive repetida de outro dia', () {
    final simples = _tarefa('a', 'Pão', inicio: DateTime(2026, 11, 25));
    final solta = _tarefa('b', 'Ler');
    final diaria = _tarefa('c', 'Remédio', inicio: DateTime(2026, 11, 20), repeticao: Repeticao.diaria);
    final tarefas = [simples, solta, diaria];
    for (final l in organizarTarefas(tarefas, agora)) {
      expect(ocorrenciaPelaChave(tarefas, l.chave)?.inicio, l.ocorrencia.inicio);
    }
    // Ocorrência de ontem da diária (snapshot feito ontem).
    final ontem = ocorrenciaPelaChave(tarefas, 'c@${DateTime(2026, 11, 24).toIso8601String()}');
    expect(ontem?.inicio, DateTime(2026, 11, 24));
    expect(ocorrenciaPelaChave(tarefas, 'sumiu@${agora.toIso8601String()}'), isNull);
    expect(ocorrenciaPelaChave(tarefas, 'a@${DateTime(2026, 1, 1).toIso8601String()}'), isNull);
  });

  test('concluir pelo widget marca a ocorrência certa', () async {
    final state = AppState(feriadosEmbutidos: false);
    await state.carregar();
    final diaria = _tarefa('c', 'Remédio', inicio: DateTime(2026, 11, 20), repeticao: Repeticao.diaria);
    await state.adicionarEventos([_tarefa('a', 'Pão'), diaria]);
    await state.concluirPeloWidget([
      'a@${DateTime(2026, 11, 25).toIso8601String()}',
      'c@${DateTime(2026, 11, 24).toIso8601String()}',
      'lixo',
    ]);
    final a = state.tarefas.firstWhere((e) => e.id == 'a');
    expect(ocorrenciaDaTarefa(a, agora)!.feita, isTrue);
    final c = state.tarefas.firstWhere((e) => e.id == 'c');
    final dia24 = c.ocorrenciasEntre(DateTime(2026, 11, 24), DateTime(2026, 11, 25)).single;
    expect(dia24.feita, isTrue);
  });

  test('snapshot leva as tarefas pendentes, com data, hora e prioridade', () {
    final tarefas = [
      _tarefa('a', 'Pão', inicio: DateTime(2026, 11, 25), prioridade: Prioridade.alta),
      _tarefa('b', 'Ler'),
      Evento(id: 'h', titulo: 'Ligar', inicio: DateTime(2026, 11, 26, 14, 30), tipo: 'Tarefa'),
    ];
    final json = construirSnapshotJson(
      tabelaAtiva: null,
      itemPorId: (_) => null,
      densidade: ColorDensity.values.first,
      claro: ColorScheme.fromSeed(seedColor: Colors.blue),
      escuro: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      tarefas: organizarTarefas(tarefas, agora, DateTime.sunday),
      primeiroDia: DateTime.sunday,
    );
    final obj = jsonDecode(json) as Map<String, dynamic>;
    expect(obj['firstDay'], DateTime.sunday);
    final tasks = (obj['tasks'] as List).cast<Map<String, dynamic>>();
    expect(tasks.map((t) => t['title']), ['Pão', 'Ligar', 'Ler']);
    expect(tasks[0]['high'], isTrue);
    expect(tasks[0]['date'], '2026-11-25');
    expect(tasks[0].containsKey('startMin'), isFalse);
    expect(tasks[1]['startMin'], 14 * 60 + 30);
    expect(tasks[2].containsKey('date'), isFalse);
    expect(tasks[0]['key'], 'a@${DateTime(2026, 11, 25).toIso8601String()}');
  });
}
