import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/model/nota.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/ui/widgets/evento_tile.dart';

void main() {
  group('Nota', () {
    test('formata com vírgula e sem ",0"', () {
      expect(const Nota(7.5, 10).texto, '7,5 de 10');
      expect(const Nota(18, 20).curto, '18/20');
      expect(const Nota(8.25, 10).texto, '8,25 de 10');
      expect(const Nota(9, 10).fracao, 0.9);
    });

    test('lê vírgula ou ponto', () {
      expect(lerNumero('7,5'), 7.5);
      expect(lerNumero(' 7.5 '), 7.5);
      expect(lerNumero('abc'), isNull);
    });

    test('JSON inválido vira null', () {
      expect(Nota.fromJson({'v': 7, 'm': 0}), isNull);
      expect(Nota.fromJson({'v': 7}), isNull);
      expect(Nota.fromJson('x'), isNull);
      expect(Nota.fromJson({'v': 7, 'm': 10}), const Nota(7, 10));
    });
  });

  group('Evento com nota', () {
    test('quem é avaliável', () {
      Evento ev(String tipo, {String? item, String? agenda}) => Evento(
            id: 'x',
            titulo: 't',
            inicio: DateTime(2026, 11, 10),
            tipo: tipo,
            itemId: item,
            agendaId: agenda,
          );
      expect(ev('Prova').avaliavel, isTrue);
      expect(ev('Tarefa', item: 'so').avaliavel, isTrue);
      expect(ev('Tarefa').avaliavel, isFalse); // renovar RG
      expect(ev('Tarefa', agenda: 'turma').avaliavel, isTrue); // Classroom
      expect(ev('Consulta', item: 'so').avaliavel, isFalse);
    });

    test('uma nota por ocorrência e sobrevive ao JSON', () {
      final lista = Evento.novo(
        titulo: 'Lista semanal',
        tipo: 'Tarefa',
        itemId: 'so',
        inicio: DateTime(2026, 11, 3),
        diaInteiro: true,
        repeticao: Repeticao.semanal,
      )
          .comNota(DateTime(2026, 11, 3), const Nota(8, 10))
          .comNota(DateTime(2026, 11, 10, 14), const Nota(9.5, 10));

      expect(lista.notaEm(DateTime(2026, 11, 3)), const Nota(8, 10));
      expect(lista.notaEm(DateTime(2026, 11, 10)), const Nota(9.5, 10));
      expect(lista.notaEm(DateTime(2026, 11, 17)), isNull);

      final volta = Evento.fromJson(lista.toJson());
      expect(volta, lista);
      expect(volta.comNota(DateTime(2026, 11, 3), null).notasLancadas, hasLength(1));
    });
  });

  group('AppState', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('lança, lembra o máximo e o backup leva tudo', () async {
      final state = AppState();
      await state.carregar();
      final prova = Evento.novo(titulo: 'Prova de SO', tipo: 'Prova', inicio: DateTime(2026, 11, 10, 10));
      await state.adicionarEvento(prova);
      final o = Ocorrencia(prova, prova.inicio, prova.inicio);

      await state.lancarNota(o, const Nota(15, 20));
      expect(state.eventos.single.notaEm(prova.inicio), const Nota(15, 20));
      expect(state.ultimoMaximo, 20);

      final outro = AppState();
      await outro.carregar();
      expect(outro.ultimoMaximo, 20);
      expect(outro.eventos.single.notaEm(prova.inicio), const Nota(15, 20));

      final backup = outro.paraBackup();
      expect(backup['externos'], isA<Map<String, dynamic>>());
      SharedPreferences.setMockInitialValues({});
      final restaurado = AppState();
      await restaurado.carregar();
      await restaurado.restaurarBackup(backup);
      expect(restaurado.eventos.single.notaEm(prova.inicio), const Nota(15, 20));
    });
  });

  group('card de detalhes', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('prova passada: lançar, ver e remover a nota', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final state = AppState();
      await state.carregar();
      final ontem = DateTime.now().subtract(const Duration(days: 1));
      final prova = Evento.novo(
        titulo: 'Prova de SO',
        tipo: 'Prova',
        inicio: DateTime(ontem.year, ontem.month, ontem.day, 10),
      );
      await state.adicionarEvento(prova);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(body: EventoTile(ocorrencia: Ocorrencia(prova, prova.inicio, prova.inicio))),
          ),
        ),
      );

      await tester.tap(find.byType(EventoTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lançar nota'));
      await tester.pumpAndSettle();

      // Máximo já vem com 10; só a nota.
      await tester.enterText(find.widgetWithText(TextField, 'Nota'), '7,5');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Nota: 7,5 de 10'), findsOneWidget);
      expect(find.text('Lançar nota'), findsNothing);

      await tester.tap(find.text('Nota: 7,5 de 10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();
      expect(find.text('Lançar nota'), findsOneWidget);
      expect(state.eventos.single.notasLancadas, isEmpty);
    });

    testWidgets('nota maior que o máximo não salva', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final state = AppState();
      await state.carregar();
      final prova = Evento.novo(titulo: 'P1', tipo: 'Prova', inicio: DateTime(2026, 1, 5, 10));
      await state.adicionarEvento(prova);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(body: EventoTile(ocorrencia: Ocorrencia(prova, prova.inicio, prova.inicio))),
          ),
        ),
      );
      await tester.tap(find.byType(EventoTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lançar nota'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nota'), '75');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('A nota vai de 0 até 10.'), findsOneWidget);
      expect(state.eventos.single.notasLancadas, isEmpty);
    });
  });
}
