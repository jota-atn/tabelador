import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/ui/folha_evento.dart';
import 'package:tabelador/ui/tarefas_screen.dart';
import 'package:tabelador/util/tarefas.dart';

Evento tarefa(
  String titulo, {
  DateTime? inicio,
  bool semData = false,
  bool diaInteiro = true,
  Repeticao repeticao = Repeticao.nenhuma,
  bool feito = false,
}) =>
    Evento(
      id: titulo,
      titulo: titulo,
      inicio: inicio ?? DateTime(2026, 11, 1),
      diaInteiro: diaInteiro,
      tipo: 'Tarefa',
      repeticao: repeticao,
      semData: semData,
      feito: feito,
    );

void main() {
  group('modelo', () {
    test('sem data não gera ocorrência', () {
      final e = tarefa('Ligar pro banco', semData: true);
      expect(e.ocorrenciasEntre(DateTime(2000), DateTime(2100)), isEmpty);
    });

    test('feito, feitas e avisoMin sobrevivem ao JSON', () {
      final e = Evento(
        id: 'x',
        titulo: 'Lavar roupa',
        inicio: DateTime(2026, 11, 2),
        diaInteiro: true,
        tipo: 'Tarefa',
        repeticao: Repeticao.semanal,
        feitas: {DateTime(2026, 11, 9)},
        avisoMin: 9 * 60 + 30,
      );
      final volta = Evento.fromJson(e.toJson());
      expect(volta, e);
      expect(Evento.fromJson(tarefa('a', semData: true, feito: true).toJson()).semData, isTrue);
    });

    test('recorrente: concluir marca só a ocorrência', () {
      final e = tarefa('Lixo', inicio: DateTime(2026, 11, 2), repeticao: Repeticao.semanal);
      final f = e.marcandoFeita(DateTime(2026, 11, 9), true);
      expect(f.feitaEm(DateTime(2026, 11, 9)), isTrue);
      expect(f.feitaEm(DateTime(2026, 11, 16)), isFalse);
      expect(f.feito, isFalse);
      expect(f.marcandoFeita(DateTime(2026, 11, 9), false).feitas, isEmpty);
    });

    test('Entrega vira Tarefa; a que já passou conta como entregue', () {
      final agora = DateTime(2026, 11, 11, 10);
      final velha = Evento(id: 'a', titulo: 'TP1', inicio: DateTime(2026, 11, 5), tipo: 'Entrega');
      final nova = Evento(id: 'b', titulo: 'TP2', inicio: DateTime(2026, 11, 20), tipo: 'Entrega');
      expect(velha.migrado(agora).tipo, 'Tarefa');
      expect(velha.migrado(agora).feito, isTrue);
      expect(nova.migrado(agora).feito, isFalse);
      final prova = Evento(id: 'c', titulo: 'P1', inicio: DateTime(2026, 11, 5), tipo: 'Prova');
      expect(identical(prova.migrado(agora), prova), isTrue);
    });
  });

  group('organizarTarefas', () {
    // Quarta, 11/11/2026, 10h. Semana vai até domingo 15/11.
    final agora = DateTime(2026, 11, 11, 10);

    test('cada tarefa na sua seção, na ordem', () {
      final linhas = organizarTarefas([
        tarefa('depois', inicio: DateTime(2026, 11, 20)),
        tarefa('sem', semData: true),
        tarefa('semana', inicio: DateTime(2026, 11, 14)),
        tarefa('hoje', inicio: DateTime(2026, 11, 11)),
        tarefa('atrasada', inicio: DateTime(2026, 11, 10)),
        tarefa('hora passou', inicio: DateTime(2026, 11, 11, 9), diaInteiro: false),
        tarefa('feita', inicio: DateTime(2026, 11, 10), feito: true),
      ], agora);
      expect(
        [for (final l in linhas) '${l.secao.name}:${l.ocorrencia.evento.titulo}'],
        [
          'atrasadas:atrasada',
          'atrasadas:hora passou',
          'hoje:hoje',
          'semana:semana',
          'depois:depois',
          'semData:sem',
          'concluidas:feita',
        ],
      );
    });

    test('recorrente mostra a próxima ocorrência pendente', () {
      final e = tarefa('Lixo', inicio: DateTime(2026, 11, 4), repeticao: Repeticao.semanal)
          .marcandoFeita(DateTime(2026, 11, 11), true);
      final l = organizarTarefas([e], agora).single;
      expect(l.ocorrencia.inicio, DateTime(2026, 11, 18));
      expect(l.secao, SecaoTarefa.depois);
    });
  });

  group('estado', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('marcarFeita persiste e atrasadas ignora feita e recorrente', () async {
      final state = AppState();
      await state.carregar();
      final ontem = DateTime.now().subtract(const Duration(days: 1));
      await state.adicionarEvento(tarefa('A', inicio: DateTime(ontem.year, ontem.month, ontem.day)));
      await state.adicionarEvento(tarefa(
        'R',
        inicio: DateTime(ontem.year, ontem.month, ontem.day - 7),
        repeticao: Repeticao.semanal,
      ));
      await state.adicionarEvento(tarefa('S', semData: true));
      expect(state.tarefas, hasLength(3));
      expect([for (final o in state.tarefasAtrasadas(DateTime.now())) o.evento.titulo], ['A']);

      final a = state.tarefasAtrasadas(DateTime.now()).single;
      await state.marcarFeita(a, true);
      expect(state.tarefasAtrasadas(DateTime.now()), isEmpty);

      final outro = AppState();
      await outro.carregar();
      expect(outro.eventoPorId('A')!.feito, isTrue);
    });

    test('tarefa sem data nunca vai pro Google', () async {
      final state = AppState();
      await state.carregar();
      final ok = await state.adicionarEvento(tarefa('S', semData: true), salvarEm: 'qualquer');
      expect(ok, isTrue);
      expect(state.eventoPorId('S')!.gravadoNoGoogle, isFalse);
    });
  });

  group('telas', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> montar(WidgetTester tester, AppState state, Widget home) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: state, child: MaterialApp(home: home)),
      );
    }

    testWidgets('folha: tarefa sem data salva sem data', (tester) async {
      final state = AppState();
      await state.carregar();
      await montar(
        tester,
        state,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => abrirFolhaDeEvento(context, tipo: TipoEvento.tarefa),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      // Tarefa abre "sem hora", com o aviso das 7h.
      expect(find.text('Sem hora'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Renovar RG');
      await tester.tap(find.text('Sem data'));
      await tester.pump();
      expect(find.text('Sem hora'), findsNothing);
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final e = state.eventos.single;
      expect(e.titulo, 'Renovar RG');
      expect(e.ehTarefa, isTrue);
      expect(e.semData, isTrue);
    });

    testWidgets('página: caixinha conclui, risca e desce; arrastar ← apaga', (tester) async {
      final state = AppState();
      await state.carregar();
      await state.adicionarEvento(tarefa('Renovar RG', semData: true));
      await state.adicionarEvento(tarefa('Pagar luz', semData: true, inicio: DateTime(2026, 10, 1)));
      await montar(tester, state, const TarefasScreen());
      await tester.pump();

      expect(find.text('Sem data · 2'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(state.eventoPorId('Pagar luz')!.feito, isTrue);
      // Ainda riscada no lugar.
      expect(find.text('Sem data · 2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Sem data · 1'), findsOneWidget);
      expect(find.text('Mostrar 1 concluída'), findsOneWidget);

      await tester.drag(find.text('Renovar RG'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(state.eventoPorId('Renovar RG'), isNull);
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(state.eventoPorId('Renovar RG'), isNotNull);
    });
  });
}
