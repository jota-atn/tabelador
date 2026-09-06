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

  testWidgets('abre na semana, sem tabela ativa', (tester) async {
    await tester.pumpWidget(const TabeladorApp());
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma tabela ativa'), findsOneWidget);
  });

  testWidgets('a densidade escolhida sobrevive a reabrir o app', (tester) async {
    await tester.pumpWidget(const TabeladorApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sólido'));
    await tester.pumpAndSettle();

    // Instância nova, mesmo disco.
    final state = AppState();
    await state.carregar();
    expect(state.densidade, ColorDensity.solido);
  });

  testWidgets('ativar notificações mostra e permite mudar a antecedência',
      (tester) async {
    await tester.pumpWidget(const TabeladorApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Aparência'));
    await tester.pumpAndSettle();

    expect(find.text('Com quanto tempo de antecedência'), findsNothing);

    await tester.tap(find.text('Avisar antes de cada horário'));
    await tester.pumpAndSettle();

    expect(find.text('Com quanto tempo de antecedência'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);

    final salvo = AppState();
    await salvo.carregar();
    expect(salvo.notificacoesAtivas, isTrue);
    expect(salvo.antecedenciaMinutos, 15);

    await tester.tap(find.text('15 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 min').last);
    await tester.pumpAndSettle();

    final recarregado = AppState();
    await recarregado.carregar();
    expect(recarregado.antecedenciaMinutos, 30);
  });

  testWidgets('o botão de tema inverte o brilho', (tester) async {
    await tester.pumpWidget(const TabeladorApp());
    await tester.pumpAndSettle();

    // Ancora num widget único: com o shell, há vários Scaffolds na árvore.
    Brightness brilhoAtual() =>
        Theme.of(tester.element(find.text('Nenhuma tabela ativa'))).brightness;

    final antes = brilhoAtual();

    await tester.tap(find.byTooltip('Alternar tema'));
    await tester.pumpAndSettle();

    expect(brilhoAtual(), isNot(antes));
  });

  group('navegação adaptativa', () {
    testWidgets('tela larga usa barra lateral em vez da barra debaixo',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // A barra lateral navega igual à de baixo.
      await tester.tap(find.text('Itens'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum item ainda'), findsOneWidget);
    });

    testWidgets('tela estreita continua com a barra debaixo', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });
}
