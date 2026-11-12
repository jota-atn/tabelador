import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/model/item.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/ui/item_editor.dart';
import 'package:tabelador/ui/widgets/proximos_eventos.dart';

void main() {
  group('Evento.ocorrenciasEntre', () {
    test('único: entra só se começar dentro da janela', () {
      final e = Evento.novo(titulo: 'Prova', inicio: DateTime(2026, 11, 13, 10));
      expect(e.ocorrenciasEntre(DateTime(2026, 11, 13), DateTime(2026, 11, 14)),
          hasLength(1));
      expect(e.ocorrenciasEntre(DateTime(2026, 11, 14), DateTime(2026, 11, 20)),
          isEmpty);
    });

    test('semanal: uma por semana, mesma hora, mesmo começando anos depois', () {
      final e = Evento.novo(
        titulo: 'Reunião',
        inicio: DateTime(2020, 1, 6, 9), // segunda
        fim: DateTime(2020, 1, 6, 10),
        repeticao: Repeticao.semanal,
      );
      final oc = e.ocorrenciasEntre(DateTime(2026, 11, 9), DateTime(2026, 11, 23));
      expect(oc.map((o) => o.inicio),
          [DateTime(2026, 11, 9, 9), DateTime(2026, 11, 16, 9)]);
      expect(oc.first.fim, DateTime(2026, 11, 9, 10));
    });

    test('mensal no dia 31 pula mês sem dia 31', () {
      final e = Evento.novo(
        titulo: 'Fatura',
        inicio: DateTime(2026, 1, 31),
        diaInteiro: true,
        repeticao: Repeticao.mensal,
      );
      final oc = e.ocorrenciasEntre(DateTime(2026, 1, 1), DateTime(2026, 6, 1));
      expect(oc.map((o) => o.inicio.month), [1, 3, 5]);
    });

    test('anual em 29/02 só aparece em ano bissexto', () {
      final e = Evento.novo(
        titulo: 'Aniversário',
        inicio: DateTime(2024, 2, 29),
        diaInteiro: true,
        repeticao: Repeticao.anual,
      );
      final oc = e.ocorrenciasEntre(DateTime(2025, 1, 1), DateTime(2029, 1, 1));
      expect(oc.map((o) => o.inicio.year), [2028]);
    });

    test('não devolve ocorrência anterior ao início da série', () {
      final e = Evento.novo(
        titulo: 'Treino',
        inicio: DateTime(2026, 11, 10, 18),
        repeticao: Repeticao.semanal,
      );
      final oc = e.ocorrenciasEntre(DateTime(2026, 10, 1), DateTime(2026, 11, 11));
      expect(oc.map((o) => o.inicio), [DateTime(2026, 11, 10, 18)]);
    });
  });

  test('JSON ida e volta preserva tudo', () {
    final e = Evento.novo(
      titulo: 'Prova',
      inicio: DateTime(2026, 11, 13, 10),
      fim: DateTime(2026, 11, 13, 12),
      tipo: 'Prova',
      repeticao: Repeticao.mensal,
      itemId: 'so',
      local: 'Sala 2',
      notas: 'Cap. 1-4',
    );
    expect(Evento.fromJson(e.toJson()), e);
  });

  group('AppState e eventos', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('persiste entre carregamentos', () async {
      final state = AppState();
      await state.carregar();
      final e = Evento.novo(titulo: 'Prova', inicio: DateTime(2026, 11, 13, 10));
      await state.adicionarEvento(e);

      final outro = AppState();
      await outro.carregar();
      expect(outro.eventos, [e]);
    });

    test('apagar o item solta o evento em vez de apagá-lo', () async {
      final state = AppState();
      await state.carregar();
      final item = Item.novo(nome: 'Sistemas Operacionais', sigla: 'SO');
      await state.adicionarItem(item);
      final e = Evento.novo(
        titulo: 'Prova',
        inicio: DateTime(2026, 11, 13, 10),
        itemId: item.id,
      );
      await state.adicionarEvento(e);

      await state.removerItem(item.id);
      expect(state.eventos, hasLength(1));
      expect(state.eventos.single.itemId, isNull);
    });

    test('backup leva e traz eventos; backup antigo sem a chave não quebra',
        () async {
      final state = AppState();
      await state.carregar();
      await state.adicionarEvento(
        Evento.novo(titulo: 'Prova', inicio: DateTime(2026, 11, 13, 10)),
      );
      final backup = state.paraBackup();

      final restaurado = AppState();
      await restaurado.carregar();
      await restaurado.restaurarBackup(backup);
      expect(restaurado.eventos, state.eventos);

      await restaurado.restaurarBackup({...backup}..remove('eventos'));
      expect(restaurado.eventos, isEmpty);
    });
  });

  group('telas', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<AppState> montar(WidgetTester tester, Widget filho) async {
      final state = AppState(feriadosEmbutidos: false);
      await state.carregar();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(home: Scaffold(body: filho)),
        ),
      );
      return state;
    }

    testWidgets('"Esta semana" mostra o próximo; botão embaixo abre o resto',
        (tester) async {
      final state = await montar(tester, const SingleChildScrollView(
        child: ProximosEventos(),
      ));
      // Daqui a pouco: sempre cai nesta semana (salvo rodar o teste nos
      // últimos minutos de domingo).
      final logo = DateTime.now().add(const Duration(minutes: 5));
      await state.adicionarEvento(Evento.novo(titulo: 'Aniversário de Pedro', inicio: logo));
      await state.adicionarEvento(Evento.novo(
        titulo: 'Dentista',
        inicio: logo.add(const Duration(minutes: 1)),
      ));
      await state.adicionarEvento(Evento.novo(
        titulo: 'Já foi',
        inicio: DateTime.now().subtract(const Duration(days: 2)),
      ));
      await tester.pump();

      expect(find.text('Aniversário de Pedro'), findsOneWidget);
      expect(find.text('Dentista'), findsNothing);

      await tester.tap(find.text('Ver mais 1 evento da semana'));
      await tester.pump();
      expect(find.text('Dentista'), findsOneWidget);
      expect(find.text('Já foi'), findsNothing);
      expect(state.semanaAberta, isTrue); // lembrado

      await tester.tap(find.text('Mostrar só o próximo'));
      await tester.pump();
      expect(find.text('Dentista'), findsNothing);
    });

    testWidgets('tela do item separa próximos de passados', (tester) async {
      final item = Item.novo(nome: 'Sistemas Operacionais', sigla: 'SO');
      final state = AppState();
      await state.carregar();
      await state.adicionarItem(item);
      final agora = DateTime.now();
      await state.adicionarEvento(Evento.novo(
        titulo: 'P2',
        inicio: agora.add(const Duration(days: 5)),
        itemId: item.id,
      ));
      await state.adicionarEvento(Evento.novo(
        titulo: 'P1',
        inicio: agora.subtract(const Duration(days: 30)),
        itemId: item.id,
      ));

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(home: ItemEditor(original: item)),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('1 passado'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('P2'), findsOneWidget);
      // Passado fica recolhido até tocar.
      expect(find.text('P1'), findsNothing);
      await tester.ensureVisible(find.text('1 passado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 passado'));
      await tester.pumpAndSettle();
      expect(find.text('P1', skipOffstage: false), findsOneWidget);
    });
  });
}
