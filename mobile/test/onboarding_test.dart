import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/main.dart';
import 'package:tabelador/model/tabela.dart';
import 'package:tabelador/state/app_state.dart';

void main() {
  testWidgets('instalação nova: onboarding, cria a tabela e entra no app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TabeladorApp());
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo ao Tabelador'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Sua primeira tabela'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Faculdade');
    await tester.ensureVisible(find.text('Criar tabela'));
    await tester.tap(find.text('Criar tabela'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"Faculdade" criada'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Conectar Google Agenda'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Avisar antes de cada horário'), findsOneWidget);
    expect(find.text('Pular'), findsNothing); // última página
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo ao Tabelador'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen'), isTrue);
  });

  testWidgets('"Pular" vai direto pro app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const TabeladorApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo ao Tabelador'), findsNothing);
  });

  test('quem já usava não vê o onboarding, ganha o cartão do Google', () async {
    final tabela = Tabela.nova(nome: 'T');
    final state = AppState();
    SharedPreferences.setMockInitialValues({});
    await state.carregar();
    await state.adicionarTabela(tabela);

    final depois = AppState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_seen');
    await depois.carregar();
    expect(depois.onboardingVisto, isTrue);
    expect(depois.mostrarCartaoGoogle, isTrue);

    await depois.fecharCartaoGoogle();
    final terceira = AppState();
    await terceira.carregar();
    expect(terceira.mostrarCartaoGoogle, isFalse);
  });

  test('apagar todas as tabelas não traz o onboarding de volta', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.carregar();
    expect(state.onboardingVisto, isFalse);
    await state.concluirOnboarding();

    final depois = AppState();
    await depois.carregar();
    expect(depois.tabelas, isEmpty);
    expect(depois.onboardingVisto, isTrue);
  });
}
