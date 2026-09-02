import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/main.dart';
import 'package:tabelador/model/item.dart';
import 'package:tabelador/model/tabela.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/theme/item_palette.dart';
import 'package:tabelador/ui/widgets/grade_semana.dart';

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

/// Item e tabela de exemplo, com sigla diferente do nome pra que os finders
/// consigam distinguir a bandeja (mostra sigla) das linhas (mostram nome).
final _calc = Item(
  id: 'calc',
  nome: 'Cálculo II',
  sigla: 'CALC',
  tipo: 'Aula',
  cor: ItemColor.oceano,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('visão semana', () {
    testWidgets('mostra as siglas da tabela ativa', (tester) async {
      var tabela = Tabela.nova(nome: '2026.1');
      tabela = tabela.comCelula('QUARTA', 0, _calc.id);
      semear(itens: [_calc], tabelas: [tabela], ativa: tabela.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      expect(find.text('2026.1'), findsOneWidget);
      expect(find.text('CALC'), findsOneWidget);
      // Os cinco dias e as seis faixas de horário.
      for (final dia in kDiasCurtos) {
        expect(find.text(dia), findsOneWidget);
      }
      expect(find.text('8:00'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
    });

    testWidgets('tocar num dia abre o editor daquele dia', (tester) async {
      final tabela = Tabela.nova(nome: '2026.1');
      semear(itens: [_calc], tabelas: [tabela], ativa: tabela.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('QUI'));
      await tester.pumpAndSettle();

      expect(find.text('QUINTA'), findsOneWidget);
    });

    testWidgets('toque longo numa célula edita só ela, com desfazer',
        (tester) async {
      var tabela = Tabela.nova(nome: '2026.1');
      tabela = tabela.comCelula('QUARTA', 0, _calc.id);
      semear(itens: [_calc], tabelas: [tabela], ativa: tabela.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('CALC'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deixar vazio'));
      await tester.pumpAndSettle();

      expect((await lerDoDisco()).tabelas.single.celula('QUARTA', 0), isNull);
      expect(find.text('"CALC" removido'), findsOneWidget);

      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();

      expect(
        (await lerDoDisco()).tabelas.single.celula('QUARTA', 0),
        _calc.id,
      );
    });

    testWidgets('arrastar a grade troca de tabela', (tester) async {
      final a = Tabela.nova(nome: 'Primeira');
      final b = Tabela.nova(nome: 'Segunda');
      semear(tabelas: [a, b], ativa: a.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      expect(find.text('Primeira'), findsOneWidget);

      await tester.fling(find.byType(GradeSemana), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect((await lerDoDisco()).tabelaAtiva?.nome, 'Segunda');
    });

    testWidgets('destaca hoje só em dia útil', (tester) async {
      // Segunda a sexta viram índices 0..4; sábado e domingo, -1.
      expect(GradeSemana.indiceDeHoje(DateTime(2026, 8, 10)), 0); // segunda
      expect(GradeSemana.indiceDeHoje(DateTime(2026, 8, 14)), 4); // sexta
      expect(GradeSemana.indiceDeHoje(DateTime(2026, 8, 15)), -1); // sábado
      expect(GradeSemana.indiceDeHoje(DateTime(2026, 8, 16)), -1); // domingo
    });
  });

  group('editor do dia', () {
    Future<void> abrirEditor(WidgetTester tester, String diaCurto) async {
      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text(diaCurto));
      await tester.pumpAndSettle();
    }

    testWidgets('preenche um horário tocando no slot vazio', (tester) async {
      final tabela = Tabela.nova(nome: '2026.1');
      semear(itens: [_calc], tabelas: [tabela], ativa: tabela.id);

      await abrirEditor(tester, 'SEG');

      expect(find.text('vazio'), findsNWidgets(6));

      await tester.tap(find.text('vazio').first);
      await tester.pumpAndSettle();

      // O bottom sheet lista os itens pelo nome.
      await tester.tap(find.text('Cálculo II').last);
      await tester.pumpAndSettle();

      final salvo = await lerDoDisco();
      expect(salvo.tabelas.single.celula('SEGUNDA', 0), _calc.id);
    });

    testWidgets('arrastar da bandeja preenche o horário', (tester) async {
      final tabela = Tabela.nova(nome: '2026.1');
      semear(itens: [_calc], tabelas: [tabela], ativa: tabela.id);

      await abrirEditor(tester, 'SEG');

      final origem = tester.getCenter(find.text('CALC'));
      final destino = tester.getCenter(find.text('vazio').first);

      // Long-press pra pegar, move em passos pro DragTarget receber o hover,
      // e solta.
      final gesto = await tester.startGesture(origem);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesto.moveTo(Offset.lerp(origem, destino, 0.5)!);
      await tester.pump();
      await gesto.moveTo(destino);
      await tester.pump();
      await gesto.up();
      await tester.pumpAndSettle();

      final salvo = await lerDoDisco();
      expect(salvo.tabelas.single.celula('SEGUNDA', 0), _calc.id);
    });

    testWidgets('deslizar a linha esvazia o horário', (tester) async {
      var tabela = Tabela.nova(nome: '2026.1');
      tabela = tabela.comCelula('SEGUNDA', 0, _calc.id);
      semear(itens: [_calc], tabelas: [tabela], ativa: tabela.id);

      await abrirEditor(tester, 'SEG');

      expect(find.text('Cálculo II'), findsOneWidget);

      await tester.drag(find.text('Cálculo II'), const Offset(-400, 0));
      await tester.pumpAndSettle();

      final salvo = await lerDoDisco();
      expect(salvo.tabelas.single.celula('SEGUNDA', 0), isNull);
      // Deslizar também oferece desfazer, não só o toque longo na grade.
      expect(find.text('Desfazer'), findsOneWidget);
    });

    testWidgets('limpar pelo seletor deixa o slot vazio', (tester) async {
      var tabela = Tabela.nova(nome: '2026.1');
      tabela = tabela.comCelula('SEGUNDA', 2, _calc.id);
      semear(itens: [_calc], tabelas: [tabela], ativa: tabela.id);

      await abrirEditor(tester, 'SEG');

      await tester.tap(find.text('Cálculo II'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deixar vazio'));
      await tester.pumpAndSettle();

      final salvo = await lerDoDisco();
      expect(salvo.tabelas.single.celula('SEGUNDA', 2), isNull);
    });

    testWidgets('as setas trocam de dia e dão a volta', (tester) async {
      final tabela = Tabela.nova(nome: '2026.1');
      semear(itens: [_calc], tabelas: [tabela], ativa: tabela.id);

      await abrirEditor(tester, 'SEX');
      expect(find.text('SEXTA'), findsOneWidget);

      await tester.tap(find.byTooltip('Próximo dia'));
      await tester.pumpAndSettle();
      expect(find.text('SEGUNDA'), findsOneWidget);

      await tester.tap(find.byTooltip('Dia anterior'));
      await tester.pumpAndSettle();
      expect(find.text('SEXTA'), findsOneWidget);
    });
  });
}
