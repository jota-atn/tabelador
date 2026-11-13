import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/main.dart';
import 'package:tabelador/model/item.dart';
import 'package:tabelador/model/tabela.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/theme/item_palette.dart';
import 'package:tabelador/ui/widgets/grade_semana.dart';
import 'package:tabelador/util/formato_data.dart';

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

/// Item e tabela de exemplo, com sigla diferente do nome pra que os finders
/// consigam distinguir a bandeja (mostra sigla) das linhas (mostram nome).
final _calc = Item(
  id: 'calc',
  nome: 'Cálculo II',
  sigla: 'CALC',
  tipo: 'Aula',
  cor: ItemColor.oceano,
);

/// Segunda-feira daqui a [semanas] semanas.
DateTime _segundaDaqui(int semanas) {
  final h = DateTime.now();
  return DateTime(h.year, h.month, h.day - (h.weekday - 1) + 7 * semanas);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'onboarding_seen': true}));

  group('visão semana', () {
    testWidgets('mostra as siglas da tabela ativa', (tester) async {
      var tabela = Tabela.nova(nome: '2026.1');
      tabela = tabela.comCelula('QUARTA', 0, _calc.id);
      semear(itens: [_calc], tabelas: [tabela], ativa: tabela.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      expect(find.text('2026.1'), findsOneWidget);
      expect(find.text('CALC'), findsOneWidget);
      // Os cinco dias (padrão) e as seis faixas de horário.
      for (final dia in kDiasPadrao) {
        expect(find.text(kDiaAbreviado[dia]!), findsOneWidget);
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

    testWidgets('arrastar a grade passa a semana, não a tabela', (tester) async {
      final a = Tabela.nova(nome: 'Primeira');
      final b = Tabela.nova(nome: 'Segunda');
      semear(tabelas: [a, b], ativa: a.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      await tester.fling(find.byType(GradeSemana), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Semana que vem'), findsOneWidget);
      expect((await lerDoDisco()).tabelaAtiva?.nome, 'Primeira');

      await tester.fling(find.byType(GradeSemana), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Esta semana'), findsOneWidget);
    });

    testWidgets('setas trocam de semana sem mexer na grade; Hoje volta', (tester) async {
      final tabela = Tabela.nova(nome: '2026.1');
      semear(tabelas: [tabela], ativa: tabela.id);

      await tester.pumpWidget(const TabeladorApp());
      await tester.pumpAndSettle();

      IconButton hoje() => tester.widget<IconButton>(
            find.ancestor(of: find.byTooltip('Voltar pra hoje'), matching: find.byType(IconButton)),
          );
      final topoDaGrade = tester.getTopLeft(find.byType(GradeSemana));
      expect(find.text('Esta semana'), findsOneWidget);
      expect(hoje().onPressed, isNull); // já está em hoje

      await tester.tap(find.byTooltip('Próxima semana'));
      await tester.tap(find.byTooltip('Próxima semana'));
      await tester.pumpAndSettle();
      expect(find.text('Semana de ${diaMes(_segundaDaqui(2))}'), findsOneWidget);
      expect(hoje().onPressed, isNotNull);
      // A grade não sobe nem desce com a semana.
      expect(tester.getTopLeft(find.byType(GradeSemana)), topoDaGrade);

      await tester.tap(find.byTooltip('Voltar pra hoje'));
      await tester.pumpAndSettle();
      expect(find.text('Esta semana'), findsOneWidget);
    });

    testWidgets('destaca hoje só quando é um dos dias da tabela',
        (tester) async {
      // Segunda a sexta viram índices 0..4 na tabela padrão; sábado e
      // domingo, que não estão nela, -1.
      expect(GradeSemana.indiceDeHoje(kDiasPadrao, DateTime(2026, 8, 10)), 0);
      expect(GradeSemana.indiceDeHoje(kDiasPadrao, DateTime(2026, 8, 14)), 4);
      expect(GradeSemana.indiceDeHoje(kDiasPadrao, DateTime(2026, 8, 15)), -1);
      expect(GradeSemana.indiceDeHoje(kDiasPadrao, DateTime(2026, 8, 16)), -1);

      // Tabela com dias fora do padrão: sábado passa a ter índice, e um dia
      // útil que não está nela (segunda) fica de fora.
      const dias = ['TERÇA', 'QUINTA', 'SÁBADO'];
      expect(GradeSemana.indiceDeHoje(dias, DateTime(2026, 8, 15)), 2); // sáb
      expect(GradeSemana.indiceDeHoje(dias, DateTime(2026, 8, 16)), -1); // dom
      expect(GradeSemana.indiceDeHoje(dias, DateTime(2026, 8, 10)), -1); // seg
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

    testWidgets('arrastar pra um slot ocupado troca os dois', (tester) async {
      final fisica = Item(
        id: 'fisica',
        nome: 'Física I',
        sigla: 'FIS',
        tipo: 'Aula',
        cor: ItemColor.tomate,
      );
      var tabela = Tabela.nova(nome: '2026.1');
      tabela = tabela.comCelula('SEGUNDA', 0, _calc.id);
      tabela = tabela.comCelula('SEGUNDA', 1, fisica.id);
      semear(itens: [_calc, fisica], tabelas: [tabela], ativa: tabela.id);

      await abrirEditor(tester, 'SEG');

      final origem = tester.getCenter(find.text('Cálculo II'));
      final destino = tester.getCenter(find.text('Física I'));

      final gesto = await tester.startGesture(origem);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesto.moveTo(Offset.lerp(origem, destino, 0.5)!);
      await tester.pump();
      await gesto.moveTo(destino);
      await tester.pump();
      await gesto.up();
      await tester.pumpAndSettle();

      final salvo = await lerDoDisco();
      // O que estava no destino foi pra origem — nenhum dos dois sumiu.
      expect(salvo.tabelas.single.celula('SEGUNDA', 0), fisica.id);
      expect(salvo.tabelas.single.celula('SEGUNDA', 1), _calc.id);
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
