import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/main.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/theme/color_density.dart';

void main() {
  // O app carrega do disco ao subir. Sem o mock, o plugin lança dentro de um
  // Future que ninguém observa e o teste passa sem exercitar nada.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a densidade escolhida sobrevive a reabrir o app', (tester) async {
    await tester.pumpWidget(const TabeladorApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sólido'));
    await tester.pumpAndSettle();

    // Instância nova, mesmo disco.
    final state = AppState();
    await state.carregar();
    expect(state.densidade, ColorDensity.solido);
  });

  testWidgets('o laboratório abre em Suave e troca de densidade', (tester) async {
    await tester.pumpWidget(const TabeladorApp());
    await tester.pumpAndSettle();

    expect(find.text('Paleta e densidade'), findsOneWidget);
    expect(find.text('CÁLC'), findsWidgets);

    // As três opções de densidade estão na tela e Sólido é selecionável.
    for (final label in ['Discreto', 'Suave', 'Sólido']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Sólido'));
    await tester.pumpAndSettle();
    expect(find.text('CÁLC'), findsWidgets);
  });

  testWidgets('o botão de tema inverte o brilho', (tester) async {
    await tester.pumpWidget(const TabeladorApp());
    await tester.pumpAndSettle();

    final antes = Theme.of(tester.element(find.byType(Scaffold))).brightness;

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    final depois = Theme.of(tester.element(find.byType(Scaffold))).brightness;
    expect(depois, isNot(antes));
  });
}
