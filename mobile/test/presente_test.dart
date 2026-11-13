import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/model/presente.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/ui/widgets/evento_tile.dart';

Evento _aniversario() => Evento.novo(
      titulo: 'Aniversário da Ana',
      tipo: 'Aniversário',
      inicio: DateTime(2026, 11, 21),
      diaInteiro: true,
      repeticao: Repeticao.anual,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('modelo', () {
    test('JSON inválido vira null', () {
      expect(Presente.fromJson({'i': '  '}), isNull);
      expect(Presente.fromJson('x'), isNull);
      expect(Presente.fromJson({'i': 'Livro', 'c': true}), const Presente('Livro', comprado: true));
    });

    test('um por ano e sobrevive ao JSON', () {
      final e = _aniversario()
          .comPresente(DateTime(2026, 11, 21), const Presente('Livro', comprado: true))
          .comPresente(DateTime(2027, 11, 21), const Presente('Fone'));
      final lido = Evento.fromJson(e.toJson());
      expect(lido, e);
      expect(lido.presenteEm(DateTime(2026, 11, 21)), const Presente('Livro', comprado: true));
      expect(lido.presenteEm(DateTime(2027, 11, 21)), const Presente('Fone'));
      expect(lido.presenteEm(DateTime(2028, 11, 21)), isNull);
    });
  });

  test('guarda, recarrega e o backup leva', () async {
    final state = AppState(feriadosEmbutidos: false);
    await state.carregar();
    final e = _aniversario();
    await state.adicionarEvento(e);
    await state.definirPresente(Ocorrencia(e, e.inicio, e.inicio), const Presente('Livro'));

    final outro = AppState(feriadosEmbutidos: false);
    await outro.carregar();
    expect(outro.eventos.single.presenteEm(e.inicio), const Presente('Livro'));

    final backup = outro.paraBackup();
    SharedPreferences.setMockInitialValues({});
    final restaurado = AppState(feriadosEmbutidos: false);
    await restaurado.carregar();
    await restaurado.restaurarBackup(backup);
    expect(restaurado.eventos.single.presenteEm(e.inicio), const Presente('Livro'));
  });

  testWidgets('card: adicionar, marcar comprado e a lista mostra', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final state = AppState(feriadosEmbutidos: false);
    await state.carregar();
    final e = _aniversario();
    await state.adicionarEvento(e);
    final o = Ocorrencia(e, e.inicio, e.inicio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: Scaffold(body: EventoTile(ocorrencia: o))),
      ),
    );

    await tester.tap(find.byType(EventoTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Presente'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Livro do Tolkien');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Livro do Tolkien'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(state.eventos.single.presenteEm(e.inicio)?.comprado, isTrue);

    // A lista é refeita a partir do estado: a linha mostra o presente.
    Future<void> linha() => tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: state,
            child: MaterialApp(
              home: Scaffold(
                body: EventoTile(ocorrencia: Ocorrencia(state.eventos.single, e.inicio, e.inicio)),
              ),
            ),
          ),
        );
    await linha();
    expect(find.textContaining('presente comprado'), findsOneWidget);
    await state.definirPresente(Ocorrencia(state.eventos.single, e.inicio, e.inicio), const Presente('Livro'));
    await linha();
    expect(find.textContaining('presente: Livro'), findsOneWidget);
  });
}
