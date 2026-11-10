import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/model/item.dart';
import 'package:tabelador/model/tabela.dart';
import 'package:tabelador/native_widget/today_schedule_snapshot.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/theme/color_density.dart';
import 'package:tabelador/theme/item_palette.dart';
import 'package:tabelador/ui/evento_editor.dart';
import 'package:tabelador/util/eventos_na_grade.dart';

// 2026-11-09 é uma segunda. Tabela padrão: 8h, blocos de 2h, 6 horários
// (8-10, 10-12, 12-14, 14-16, 16-18, 18-20), segunda a sexta.
final _segunda = DateTime(2026, 11, 9);

Ocorrencia _oc(Evento e) => e.ocorrenciasEntre(_segunda, _segunda.add(const Duration(days: 7))).single;

void main() {
  group('distribuirEventos', () {
    final tabela = Tabela.nova(nome: 'T').comCelula('TERÇA', 1, 'so');

    EventosDaSemana distribuir(List<Evento> eventos, {Tabela? t}) => distribuirEventos(
          tabela: t ?? tabela,
          segunda: _segunda,
          ocorrencias: eventos.map(_oc),
        );

    test('evento dentro do horário cai na célula certa', () {
      final e = Evento.novo(
        titulo: 'Prova',
        inicio: DateTime(2026, 11, 10, 10),
        fim: DateTime(2026, 11, 10, 12),
      );
      final r = distribuir([e]);
      expect(r.naCelula('TERÇA', 1), hasLength(1));
      expect(r.naCelula('TERÇA', 0), isEmpty);
      expect(r.naCelula('TERÇA', 2), isEmpty);
    });

    test('faixa longa ocupa todos os slots que sobrepõe', () {
      final e = Evento.novo(
        titulo: 'Maratona',
        inicio: DateTime(2026, 11, 11, 9),
        fim: DateTime(2026, 11, 11, 13),
      );
      final r = distribuir([e]);
      expect([for (var s = 0; s < 6; s++) r.naCelula('QUARTA', s).length],
          [1, 1, 1, 0, 0, 0]);
    });

    test('fora do horário e dia todo vão pras faixas', () {
      final tarde = Evento.novo(
        titulo: 'Aniversário de Pedro',
        inicio: DateTime(2026, 11, 12, 21),
      );
      final feriado = Evento.novo(
        titulo: 'Feriado',
        inicio: DateTime(2026, 11, 13),
        diaInteiro: true,
      );
      final r = distribuir([tarde, feriado]);
      expect(r.foraDoHorario('QUINTA').single.evento.titulo, 'Aniversário de Pedro');
      expect(r.diaTodo('SEXTA').single.evento.titulo, 'Feriado');
      expect(r.temForaDoHorario, isTrue);
      expect(r.temDiaTodo, isTrue);
    });

    test('dia que a tabela não tem fica de fora da grade', () {
      final sabado = Evento.novo(titulo: 'Churrasco', inicio: DateTime(2026, 11, 14, 12));
      final r = distribuir([sabado]);
      expect(r.temForaDoHorario, isFalse);
      expect(r.naCelula('SEXTA', 2), isEmpty);
    });

    test('mostrarEventos desligado só deixa passar evento de item da tabela', () {
      final avulso = Evento.novo(titulo: 'Aniversário', inicio: DateTime(2026, 11, 10, 10));
      final daAula = Evento.novo(
        titulo: 'Prova',
        inicio: DateTime(2026, 11, 10, 10),
        itemId: 'so',
      );
      final r = distribuir(
        [avulso, daAula],
        t: tabela.copyWith(mostrarEventos: false),
      );
      expect(r.naCelula('TERÇA', 1).single.evento.titulo, 'Prova');
    });
  });

  test('proximoHorarioDoItem acha o próximo slot e pula o que já começou', () {
    final tabela = Tabela.nova(nome: 'T')
        .comCelula('TERÇA', 1, 'so')
        .comCelula('QUINTA', 0, 'so');

    // Terça 11h: o das 10h já começou, o próximo é quinta 8h.
    final p = proximoHorarioDoItem(tabela, 'so', DateTime(2026, 11, 10, 11));
    expect(p?.inicio, DateTime(2026, 11, 12, 8));
    expect(p?.fim, DateTime(2026, 11, 12, 10));

    expect(proximoHorarioDoItem(tabela, 'outro', DateTime(2026, 11, 10)), isNull);
  });

  test('snapshot do widget leva eventos com data, hora e local do item', () {
    const item = Item(
      id: 'so',
      nome: 'Sistemas Operacionais',
      sigla: 'SO',
      tipo: 'Aula',
      cor: ItemColor.oceano,
      local: 'Bloco C',
    );
    final e = Evento.novo(
      titulo: 'Prova',
      inicio: DateTime(2026, 11, 10, 10),
      fim: DateTime(2026, 11, 10, 12),
      itemId: 'so',
    );
    final json = jsonDecode(construirSnapshotJson(
      tabelaAtiva: Tabela.nova(nome: 'T'),
      itemPorId: (id) => id == 'so' ? item : null,
      densidade: ColorDensity.suave,
      claro: ColorScheme.fromSeed(seedColor: Colors.blue),
      escuro: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ocorrencias: [_oc(e)],
    ));
    final ev = (json['events'] as List).single as Map<String, dynamic>;
    expect(ev['date'], '2026-11-10');
    expect(ev['startMin'], 600);
    expect(ev['time'], '10:00–12:00');
    expect(ev['sigla'], 'SO');
    expect(ev['local'], 'Bloco C');
  });

  group('formulário de evento', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('vincular item traz o local e o título sozinhos', (tester) async {
      final state = AppState();
      await state.carregar();
      final item = Item.novo(nome: 'Sistemas Operacionais', sigla: 'SO', local: 'Bloco C');
      await state.adicionarItem(item);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(home: EventoEditor(itemId: item.id)),
        ),
      );
      await tester.pumpAndSettle();

      // Tocar no tipo monta o título; salvar sem digitar nada.
      await tester.tap(find.text('Prova'));
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final salvo = state.eventos.single;
      expect(salvo.titulo, 'Prova · Sistemas Operacionais');
      expect(salvo.local, 'Bloco C');
      expect(salvo.itemId, item.id);
    });
  });
}
