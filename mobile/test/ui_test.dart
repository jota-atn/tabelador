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
    'onboarding_seen': true,
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
  setUp(() => SharedPreferences.setMockInitialValues({'onboarding_seen': true}));

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

    testWidgets('vincula um item a uma tabela sem precisar entrar nela',
        (tester) async {
      final tabela = Tabela.nova(nome: '2026.2');
      semear(tabelas: [tabela], ativa: tabela.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      await abrirAba(tester, 'Itens');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome'),
        'Cálculo II',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Só em 2026.2').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final depois = await lerDoDisco();
      final item = depois.itens.single;
      expect(item.tabelaId, tabela.id);
      // Confirma que o vínculo é o que rege a paleta, não só um rótulo salvo.
      expect(depois.itensParaTabela(tabela.id), [item]);
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

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apagar'));
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

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apagar'));
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
      await tester.ensureVisible(find.text('Criar'));
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      // Criar pula direto pra Semana, que é onde a grade se monta — não fica
      // na aba Tabelas mostrando o selo "ATIVA" no card.
      expect(find.text('2026.1'), findsOneWidget);
      expect(find.text('Nenhuma tabela ativa'), findsNothing);

      final salvo = await lerDoDisco();
      expect(salvo.tabelas.single.nome, '2026.1');
      expect(salvo.tabelaAtiva?.nome, '2026.1');
    });

    testWidgets('criar tabela com dias escolhidos', (tester) async {
      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      await abrirAba(tester, 'Tabelas');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Academia',
      );

      // Desmarca segunda e sexta, marca sábado: sobra terça/quarta/quinta/sáb.
      await tester.tap(find.widgetWithText(FilterChip, 'SEG'));
      await tester.tap(find.widgetWithText(FilterChip, 'SEX'));
      await tester.tap(find.widgetWithText(FilterChip, 'SÁB'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Criar'));
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      final salvo = await lerDoDisco();
      expect(
        salvo.tabelas.single.dias,
        ['TERÇA', 'QUARTA', 'QUINTA', 'SÁBADO'],
      );
    });

    testWidgets('não dá pra desmarcar o último dia', (tester) async {
      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      await abrirAba(tester, 'Tabelas');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Só um dia',
      );

      for (final sigla in ['SEG', 'QUA', 'QUI', 'SEX']) {
        await tester.tap(find.widgetWithText(FilterChip, sigla));
      }
      await tester.pumpAndSettle();
      // Terça é o único que sobrou — tentar tirar não deve zerar a lista.
      await tester.tap(find.widgetWithText(FilterChip, 'TER'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Criar'));
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      final salvo = await lerDoDisco();
      expect(salvo.tabelas.single.dias, ['TERÇA']);
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
      // Tocar no card não só ativa: já pousa na grade da semana, que é onde
      // a edição de horário de fato acontece.
      expect(find.text('Toque num dia pra montar o horário'), findsOneWidget);
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

  group('arquivamento de itens', () {
    testWidgets('item arquivado some da paleta mas continua na célula antiga',
        (tester) async {
      final item = Item(
        id: 'calc2',
        nome: 'Cálculo II',
        sigla: 'CALC2',
        tipo: 'Aula',
        cor: ItemColor.oceano,
      );
      var tabela = Tabela.nova(nome: '2026.1');
      tabela = tabela.comCelula('SEGUNDA', 0, item.id);
      semear(itens: [item], tabelas: [tabela], ativa: tabela.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      await abrirAba(tester, 'Itens');
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arquivar'));
      await tester.pumpAndSettle();

      expect((await lerDoDisco()).itens.single.arquivado, isTrue);

      await abrirAba(tester, 'Semana');
      await tester.tap(find.text('SEG'));
      await tester.pumpAndSettle();

      // A célula preenchida antes de arquivar continua mostrando o item.
      expect(find.text('Cálculo II'), findsOneWidget);
      // Mas ele sumiu da bandeja de arrastar.
      expect(find.text('CALC2'), findsNothing);

      // Desarquivar traz ele de volta pra paleta.
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      await abrirAba(tester, 'Itens');
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desarquivar'));
      await tester.pumpAndSettle();

      expect((await lerDoDisco()).itens.single.arquivado, isFalse);
    });

    testWidgets('arquivar itens exclusivos revisa antes de confirmar',
        (tester) async {
      final compartilhado = Item(
        id: 'geo',
        nome: 'Geografia',
        sigla: 'GEO',
        tipo: '',
        cor: ItemColor.tomate,
      );
      final exclusivo = Item(
        id: 'calc2',
        nome: 'Cálculo II',
        sigla: 'CALC2',
        tipo: '',
        cor: ItemColor.oceano,
      );
      final almoco = Item(
        id: 'almoco',
        nome: 'Almoço',
        sigla: 'ALMOÇO',
        tipo: '',
        cor: ItemColor.ambar,
      );

      var t1 = Tabela.nova(nome: '2026.1');
      t1 = t1.comCelula('SEGUNDA', 0, compartilhado.id);

      var t2 = Tabela.nova(nome: '2026.2');
      t2 = t2.comCelula('SEGUNDA', 0, compartilhado.id);
      t2 = t2.comCelula('TERÇA', 0, exclusivo.id);
      t2 = t2.comCelula('QUARTA', 0, almoco.id);

      semear(
        itens: [compartilhado, exclusivo, almoco],
        tabelas: [t1, t2],
        ativa: t2.id,
      );

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();
      await abrirAba(tester, 'Tabelas');

      // O card da 2026.2 é o segundo da lista.
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arquivar itens exclusivos'));
      await tester.pumpAndSettle();

      // Compartilhado com 2026.1 não é candidato.
      expect(find.text('Geografia'), findsNothing);
      expect(find.text('Cálculo II'), findsOneWidget);
      expect(find.text('Almoço'), findsOneWidget);

      // Desmarca o almoço: é recorrente, não deve ser arquivado.
      await tester.tap(find.text('Almoço'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Arquivar'));
      await tester.pumpAndSettle();

      final depois = await lerDoDisco();
      Item item(String id) => depois.itens.firstWhere((i) => i.id == id);
      expect(item('calc2').arquivado, isTrue);
      expect(item('almoco').arquivado, isFalse);
      expect(item('geo').arquivado, isFalse);
    });

    testWidgets('sem item exclusivo, avisa em vez de abrir a revisão',
        (tester) async {
      final item = Item(
        id: 'geo',
        nome: 'Geografia',
        sigla: 'GEO',
        tipo: '',
        cor: ItemColor.tomate,
      );
      var t1 = Tabela.nova(nome: '2026.1');
      t1 = t1.comCelula('SEGUNDA', 0, item.id);
      var t2 = Tabela.nova(nome: '2026.2');
      t2 = t2.comCelula('SEGUNDA', 0, item.id);
      semear(itens: [item], tabelas: [t1, t2], ativa: t2.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();
      await abrirAba(tester, 'Tabelas');

      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arquivar itens exclusivos'));
      await tester.pumpAndSettle();

      expect(
        find.text('Nenhum item aparece só nesta tabela.'),
        findsOneWidget,
      );
      expect((await lerDoDisco()).itens.single.arquivado, isFalse);
    });
  });

  group('tela dedicada da tabela', () {
    testWidgets('tocar num card abre a tela e cria item exclusivo isolado',
        (tester) async {
      final t1 = Tabela.nova(nome: '2026.1');
      final t2 = Tabela.nova(nome: '2026.2');
      semear(tabelas: [t1, t2], ativa: t1.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      await abrirAba(tester, 'Tabelas');
      await tester.tap(find.text('2026.2'));
      await tester.pumpAndSettle();

      // Entrou direto na grade da 2026.2, sem precisar trocar de aba.
      expect(find.text('Toque num dia pra montar o horário'), findsOneWidget);

      await tester.tap(find.text('SEG'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('vazio').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Criar item só pra esta tabela'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome'),
        'Cálculo II',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // De volta no seletor, o item recém-criado já aparece pra escolher.
      await tester.tap(find.text('Cálculo II'));
      await tester.pumpAndSettle();

      final depois = await lerDoDisco();
      final item = depois.itens.single;
      expect(item.nome, 'Cálculo II');
      expect(item.tabelaId, t2.id);
      expect(
        depois.tabelas.firstWhere((t) => t.id == t2.id).celula('SEGUNDA', 0),
        item.id,
      );

      // Some da paleta de qualquer outra tabela.
      expect(depois.itensParaTabela(t1.id), isEmpty);
      expect(depois.itensParaTabela(t2.id), [item]);
    });

    testWidgets('apagar a tabela leva o item exclusivo dela junto',
        (tester) async {
      var tabela = Tabela.nova(nome: '2026.2');
      final compartilhado = Item(
        id: 'geo',
        nome: 'Geografia',
        sigla: 'GEO',
        tipo: '',
        cor: ItemColor.tomate,
      );
      final exclusivo = Item(
        id: 'calc2',
        nome: 'Cálculo II',
        sigla: 'CALC2',
        tipo: '',
        cor: ItemColor.oceano,
        tabelaId: tabela.id,
      );
      tabela = tabela.comCelula('SEGUNDA', 0, compartilhado.id);
      tabela = tabela.comCelula('TERÇA', 0, exclusivo.id);
      semear(itens: [compartilhado, exclusivo], tabelas: [tabela], ativa: tabela.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();
      await abrirAba(tester, 'Tabelas');

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          '1 item que só existe nesta tabela também será apagado.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();

      final depois = await lerDoDisco();
      expect(depois.tabelas, isEmpty);
      // O compartilhado sobrevive, o exclusivo não.
      expect(depois.itens.map((i) => i.id), ['geo']);
    });
  });
}
