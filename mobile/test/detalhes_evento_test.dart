import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/model/item.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/ui/detalhes_evento.dart';
import 'package:tabelador/ui/widgets/evento_tile.dart';

void main() {
  final agora = DateTime(2026, 11, 10, 9);

  test('distância em dias', () {
    expect(distanciaEmDias(DateTime(2026, 11, 10, 22), agora), 'Hoje');
    expect(distanciaEmDias(DateTime(2026, 11, 11), agora), 'Amanhã');
    expect(distanciaEmDias(DateTime(2026, 11, 9), agora), 'Ontem');
    expect(distanciaEmDias(DateTime(2026, 11, 15), agora), 'Em 5 dias');
    expect(distanciaEmDias(DateTime(2026, 11, 7), agora), 'Há 3 dias');
  });

  test('data por extenso só mostra o ano se não for o atual', () {
    expect(dataPorExtenso(DateTime(2026, 11, 11), agora), 'quarta-feira, 11 de novembro');
    expect(dataPorExtenso(DateTime(2027, 1, 3), agora), 'domingo, 3 de janeiro de 2027');
  });

  group('card de detalhes', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<AppState> montar(WidgetTester tester, Evento evento) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final state = AppState();
      await state.carregar();
      await state.adicionarEvento(evento);
      final o = Ocorrencia(evento, evento.inicio, evento.inicio.add(evento.duracao));
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(home: Scaffold(body: EventoTile(ocorrencia: o))),
        ),
      );
      return state;
    }

    testWidgets('tocar no evento mostra o card, não o editor', (tester) async {
      final item = Item.novo(nome: 'Sistemas Operacionais', sigla: 'SO');
      final e = Evento.novo(
        titulo: 'Prova de SO',
        tipo: 'Prova',
        inicio: DateTime(2026, 12, 2, 10),
        fim: DateTime(2026, 12, 2, 12),
        local: 'Bloco C',
        notas: 'Capítulos 1 a 4',
        itemId: item.id,
      );
      final state = await montar(tester, e);
      await state.adicionarItem(item);
      await tester.pump();

      await tester.tap(find.byType(EventoTile));
      await tester.pumpAndSettle();

      expect(find.byType(DetalhesDoEvento), findsOneWidget);
      expect(find.text('Editar evento'), findsNothing);
      expect(find.text('10:00–12:00 · 2 h'), findsOneWidget);
      expect(find.text('Bloco C'), findsOneWidget);
      expect(find.text('Capítulos 1 a 4'), findsOneWidget);
      expect(find.text('Sistemas Operacionais'), findsOneWidget);
      expect(find.text('Só neste aparelho'), findsNothing); // rodapé só pra evento do Google
    });

    testWidgets('o lápis troca o card pela folha de edição', (tester) async {
      final e = Evento.novo(
        titulo: 'Pedro',
        tipo: 'Aniversário',
        inicio: DateTime(2026, 12, 20),
        diaInteiro: true,
        repeticao: Repeticao.anual,
      );
      await montar(tester, e);

      await tester.tap(find.byType(EventoTile));
      await tester.pumpAndSettle();
      expect(find.text('Todo ano'), findsOneWidget);

      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();

      expect(find.byType(DetalhesDoEvento), findsNothing);
      expect(find.text('Editar evento'), findsOneWidget);
    });
  });
}
