import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabelador/agenda/agendas_do_aparelho.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/model/tabela.dart';
import 'package:tabelador/native_widget/today_schedule_snapshot.dart';
import 'package:tabelador/theme/color_density.dart';
import 'package:tabelador/ui/widgets/grade_semana.dart';
import 'package:tabelador/util/eventos_na_grade.dart';
import 'package:tabelador/util/formato_data.dart';

// 2026-11-09 é uma segunda. Viagem de sábado 14 a quarta 18/11.
final _segunda = DateTime(2026, 11, 9);
final _proxima = DateTime(2026, 11, 16);

Evento _viagem({bool mantem = false, Repeticao repeticao = Repeticao.nenhuma}) => Evento(
      id: 'v',
      titulo: 'Viagem a BH',
      inicio: DateTime(2026, 11, 14),
      fim: DateTime(2026, 11, 18),
      diaInteiro: true,
      tipo: 'Viagem',
      comemorativa: mantem,
      repeticao: repeticao,
    );

void main() {
  group('modelo', () {
    test('vários dias: último dia e dias extras', () {
      final v = _viagem();
      expect(v.variosDias, isTrue);
      expect(v.ultimoDia, DateTime(2026, 11, 18));
      expect(v.diasExtras, 4);
      final umDia = Evento(id: 'a', titulo: 'x', inicio: DateTime(2026, 11, 14), diaInteiro: true);
      expect(umDia.variosDias, isFalse);
      expect(umDia.ultimoDia, DateTime(2026, 11, 14));
    });

    test('entra na semana seguinte mesmo tendo começado antes', () {
      final o = _viagem().ocorrenciasEntre(_proxima, _proxima.add(const Duration(days: 7))).single;
      expect(o.inicio, DateTime(2026, 11, 14));
      expect(o.fim, DateTime(2026, 11, 19));
      expect(o.ultimoDia, DateTime(2026, 11, 18));
      expect(o.variosDias, isTrue);
      expect(o.cobre(DateTime(2026, 11, 18, 23)), isTrue);
      expect(o.cobre(DateTime(2026, 11, 19)), isFalse);
      expect(o.cobre(DateTime(2026, 11, 13)), isFalse);
    });

    test('a janela começando no último dia ainda pega; no dia seguinte, não', () {
      final v = _viagem();
      expect(v.ocorrenciasEntre(DateTime(2026, 11, 18, 15), DateTime(2026, 11, 25)), hasLength(1));
      expect(v.ocorrenciasEntre(DateTime(2026, 11, 19), DateTime(2026, 11, 25)), isEmpty);
    });

    test('repetindo todo ano, cada ano uma ocorrência de vários dias', () {
      final v = _viagem(repeticao: Repeticao.anual);
      final os = v.ocorrenciasEntre(DateTime(2027, 11, 16), DateTime(2027, 11, 23));
      expect(os.single.inicio, DateTime(2027, 11, 14));
      expect(os.single.ultimoDia, DateTime(2027, 11, 18));
    });

    test('JSON guarda o último dia', () {
      final v = Evento.fromJson(_viagem().toJson());
      expect(v.ultimoDia, DateTime(2026, 11, 18));
      expect(v, _viagem());
    });
  });

  group('grade', () {
    final tabela = Tabela.nova(nome: 'T');

    test('aparece na faixa de dia todo de cada dia que ocupa', () {
      final ocs = _viagem().ocorrenciasEntre(_proxima, _proxima.add(const Duration(days: 7)));
      final r = distribuirEventos(tabela: tabela, segunda: _proxima, ocorrencias: ocs);
      expect(r.diaTodo('SEGUNDA'), hasLength(1));
      expect(r.diaTodo('TERÇA'), hasLength(1));
      expect(r.diaTodo('QUARTA'), hasLength(1));
      expect(r.diaTodo('QUINTA'), isEmpty);
    });

    test('Sem aula apaga os dias da viagem; Mantém não', () {
      final ocs = _viagem().ocorrenciasEntre(_proxima, _proxima.add(const Duration(days: 7)));
      expect(folgaNoDia(DateTime(2026, 11, 17), tabela, ocs), 'Viagem a BH');
      expect(folgaNoDia(DateTime(2026, 11, 19), tabela, ocs), isNull);
      final mantem = _viagem(mantem: true).ocorrenciasEntre(_proxima, _proxima.add(const Duration(days: 7)));
      expect(folgaNoDia(DateTime(2026, 11, 17), tabela, mantem), isNull);
    });

    test('outro tipo de vários dias não apaga as aulas', () {
      final congresso = Evento(
        id: 'c',
        titulo: 'Congresso',
        inicio: DateTime(2026, 11, 10),
        fim: DateTime(2026, 11, 12),
        diaInteiro: true,
        tipo: 'Compromisso',
      );
      final ocs = congresso.ocorrenciasEntre(_segunda, _proxima);
      expect(folgaNoDia(DateTime(2026, 11, 11), tabela, ocs), isNull);
    });
  });

  group('texto', () {
    final o = _viagem().ocorrenciasEntre(_segunda, _proxima).single;

    test('antes: período', () {
      expect(faixaDeDias(o, DateTime(2026, 11, 12)), 'sáb 14 – qua 18/11');
    });

    test('durante: em viagem, volta …', () {
      expect(faixaDeDias(o, DateTime(2026, 11, 16, 9)), 'Em viagem · volta qua 18/11');
      expect(faixaDeDias(o, DateTime(2026, 11, 18, 9)), 'Em viagem · volta hoje');
    });
  });

  group('Google', () {
    test('dia todo de vários dias: fim exclusivo vira último dia', () {
      final e = eventoDoAparelho({
        'eventoId': '9',
        'agendaId': '1',
        'titulo': 'Recesso',
        'inicio': DateTime.utc(2026, 12, 21).millisecondsSinceEpoch,
        'fim': DateTime.utc(2027, 1, 4).millisecondsSinceEpoch,
        'diaInteiro': true,
      }, const {});
      expect(e.inicio, DateTime(2026, 12, 21));
      expect(e.ultimoDia, DateTime(2027, 1, 3));
    });

    test('um dia só continua sem fim', () {
      final e = eventoDoAparelho({
        'eventoId': '9',
        'agendaId': '1',
        'titulo': 'Natal',
        'inicio': DateTime.utc(2026, 12, 25).millisecondsSinceEpoch,
        'fim': DateTime.utc(2026, 12, 26).millisecondsSinceEpoch,
        'diaInteiro': true,
      }, const {});
      expect(e.fim, isNull);
    });

    test('gravar: fim é o dia depois do último', () {
      final c = camposParaAparelho(_viagem());
      expect(c['inicio'], DateTime.utc(2026, 11, 14).millisecondsSinceEpoch);
      expect(c['fim'], DateTime.utc(2026, 11, 19).millisecondsSinceEpoch);
    });
  });

  test('widget: uma entrada por dia da viagem na janela, e os dias apagados', () {
    final hoje = DateTime(2026, 11, 16);
    final ocs = _viagem().ocorrenciasEntre(hoje, DateTime(2026, 11, 24));
    final json = jsonDecode(construirSnapshotJson(
      tabelaAtiva: Tabela.nova(nome: 'T'),
      itemPorId: (_) => null,
      densidade: ColorDensity.suave,
      claro: ColorScheme.fromSeed(seedColor: Colors.blue),
      escuro: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ocorrencias: ocs,
      hoje: hoje,
    ));
    expect([for (final e in json['events'] as List) e['date']], ['2026-11-16', '2026-11-17', '2026-11-18']);
    // 20/11 é Consciência Negra (embutido); 19/11 já é depois da volta.
    expect((json['folgas'] as Map).keys, ['2026-11-16', '2026-11-17', '2026-11-18', '2026-11-20']);
  });

  testWidgets('grade: a viagem é um bloco só, com o nome uma vez', (tester) async {
    final ocs = _viagem().ocorrenciasEntre(_proxima, _proxima.add(const Duration(days: 7)));
    final tabela = Tabela.nova(nome: 'T');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GradeSemana(
            tabela: tabela,
            densidade: ColorDensity.suave,
            itemPorId: (_) => null,
            eventos: distribuirEventos(tabela: tabela, segunda: _proxima, ocorrencias: ocs),
          ),
        ),
      ),
    ));
    expect(find.text('Viagem a BH'), findsOneWidget);
  });
}
