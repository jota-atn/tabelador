import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/main.dart';
import 'package:tabelador/model/item.dart';
import 'package:tabelador/model/tabela.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/theme/item_palette.dart';

/// Põe dado no disco antes do app subir, evitando montar o cenário clicando.
void semear({
  List<Item> itens = const [],
  List<Tabela> tabelas = const [],
  String? ativa,
}) {
  SharedPreferences.setMockInitialValues({
    'items_json': jsonEncode([for (final i in itens) i.toJson()]),
    'tables_json': jsonEncode([for (final t in tabelas) t.toJson()]),
    'active_table_id': ?ativa,
  });
}

Future<AppState> lerDoDisco() async {
  final state = AppState();
  await state.carregar();
  return state;
}

Future<void> abrirAba(WidgetTester tester, String nome) async {
  await tester.tap(find.text(nome));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('biblioteca de itens', () {
    testWidgets('cadastra um item e ele aparece na lista', (tester) async {
      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      await abrirAba(tester, 'Itens');
      expect(find.text('Nenhum item ainda'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome'),
        'Banco de Dados',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Banco de Dados'), findsOneWidget);

      final salvo = (await lerDoDisco()).itens.single;
      expect(salvo.nome, 'Banco de Dados');
    });

    testWidgets('a sigla é sugerida a partir do nome', (tester) async {
      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      await abrirAba(tester, 'Itens');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome'),
        'Programação Orientada a Objetos',
      );
      await tester.pumpAndSettle();

      // Palavras de até dois caracteres ("a") não entram na sigla.
      expect(find.text('POO'), findsWidgets);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect((await lerDoDisco()).itens.single.sigla, 'POO');
    });

    testWidgets('nome vazio não salva', (tester) async {
      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      await abrirAba(tester, 'Itens');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Obrigatório'), findsWidgets);
      expect((await lerDoDisco()).itens, isEmpty);
    });

    testWidgets('apagar avisa em quantos horários o item está', (tester) async {
      final item = Item.novo(
        nome: 'Monitoria',
        sigla: 'MONIT',
        cor: ItemColor.tomate,
      );
      var tabela = Tabela.nova(nome: '2026.1');
      tabela = tabela.comCelula('SEGUNDA', 0, item.id);
      tabela = tabela.comCelula('QUARTA', 2, item.id);

      semear(itens: [item], tabelas: [tabela], ativa: tabela.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();
      await abrirAba(tester, 'Itens');

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(
        find.text('Ele está em 2 horários, que vão ficar vazios.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();

      final depois = await lerDoDisco();
      expect(depois.itens, isEmpty);
      // As células ficaram vazias, não órfãs.
      expect(depois.tabelas.single.usosDe(item.id), 0);
    });

    testWidgets('cancelar a exclusão não apaga nada', (tester) async {
      final item = Item.novo(nome: 'Física I', sigla: 'FÍS I');
      semear(itens: [item]);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();
      await abrirAba(tester, 'Itens');

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect((await lerDoDisco()).itens.length, 1);
    });
  });

  group('tabelas', () {
    testWidgets('cria uma tabela e ela vira a ativa', (tester) async {
      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      await abrirAba(tester, 'Tabelas');
      expect(find.text('Nenhuma tabela ainda'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Nome'), '2026.1');
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      expect(find.text('2026.1'), findsOneWidget);
      expect(find.text('ATIVA'), findsOneWidget);

      final salvo = await lerDoDisco();
      expect(salvo.tabelas.single.nome, '2026.1');
      expect(salvo.tabelaAtiva?.nome, '2026.1');
    });

    testWidgets('tocar numa tabela troca a ativa', (tester) async {
      final a = Tabela.nova(nome: 'Primeira');
      final b = Tabela.nova(nome: 'Segunda');
      semear(tabelas: [a, b], ativa: a.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();
      await abrirAba(tester, 'Tabelas');

      await tester.tap(find.text('Segunda'));
      await tester.pumpAndSettle();

      expect((await lerDoDisco()).tabelaAtiva?.nome, 'Segunda');
    });

    testWidgets('encolher a tabela avisa quantos horários somem',
        (tester) async {
      var tabela = Tabela.nova(nome: '2026.1', qtdHorarios: 6);
      tabela = tabela.comCelula('SEGUNDA', 5, 'item-a');
      tabela = tabela.comCelula('TERÇA', 5, 'item-b');
      semear(tabelas: [tabela], ativa: tabela.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();
      await abrirAba(tester, 'Tabelas');

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Horários'));
      await tester.pumpAndSettle();

      // Sem mexer em nada, nenhum aviso.
      expect(find.textContaining('serão apagados'), findsNothing);

      // Um passo pra baixo derruba os dois horários da última faixa.
      await tester.tap(find.byIcon(Icons.remove).last);
      await tester.pumpAndSettle();

      expect(find.text('2 horários preenchidos serão apagados.'), findsOneWidget);
    });

    testWidgets('duplicar copia a grade sem ligar as duas', (tester) async {
      var tabela = Tabela.nova(nome: '2026.1');
      tabela = tabela.comCelula('QUINTA', 1, 'item-x');
      semear(tabelas: [tabela], ativa: tabela.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();
      await abrirAba(tester, 'Tabelas');

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicar'));
      await tester.pumpAndSettle();

      final depois = await lerDoDisco();
      expect(depois.tabelas.length, 2);
      final copia = depois.tabelas.last;
      expect(copia.nome, '2026.1 (cópia)');
      expect(copia.celula('QUINTA', 1), 'item-x');
      // A original continua sendo a ativa.
      expect(depois.tabelaAtiva?.id, tabela.id);
    });
  });
}
