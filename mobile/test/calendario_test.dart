import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/ui/calendario_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tocar num dia lista os eventos dele; setas trocam de mês',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final state = AppState(feriadosEmbutidos: false);
    await state.carregar();
    final hoje = DateTime.now();
    // Dia 20 do mês atual: sempre existe e sempre está na grade.
    final dia20 = DateTime(hoje.year, hoje.month, 20, 19);
    await state.adicionarEvento(
      Evento.novo(titulo: 'Aniversário de Pedro', inicio: dia20),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: CalendarioScreen()),
      ),
    );

    expect(find.text('1 evento'), findsOneWidget);

    await tester.tap(find.text('20').first);
    await tester.pump();
    expect(find.text('Aniversário de Pedro'), findsOneWidget);

    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pump();
    expect(find.text('Aniversário de Pedro'), findsNothing);
    expect(find.text('Nenhum evento'), findsOneWidget);
  });
}
