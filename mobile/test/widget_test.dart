import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabelador/main.dart';

void main() {
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
