import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/ui/widgets/evento_tile.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/util/link_reuniao.dart';

const _blocoDoGoogle = '''-::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-
Entrar com o Google Meet: https://meet.google.com/cts-uuez-vci
Ou disque: (BR) +55 31 3958-9617 PIN: 952352610#
Mais números de telefone: https://tel.meet/cts-uuez-vci?pin=6652276356673&hs=7

Saiba mais sobre o Meet em: https://support.google.com/a/users/answer/9282720

Não edite esta seção.
-::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-''';

Evento _ev({String? local, String? notas}) =>
    Evento(id: 'x', titulo: 'Reunião', inicio: DateTime(2026, 11, 16, 19), local: local, notas: notas);

void main() {
  test('acha o Meet no bloco do Google e ignora suporte/telefone', () {
    expect(linkDeReuniao(_ev(notas: _blocoDoGoogle)), 'https://meet.google.com/cts-uuez-vci');
  });

  test('link colado no Local, mesmo sem https', () {
    expect(linkDeReuniao(_ev(local: 'meet.google.com/abc-defg-hij')), 'https://meet.google.com/abc-defg-hij');
    expect(linkDeReuniao(_ev(local: 'https://us02web.zoom.us/j/123456?pwd=x')),
        'https://us02web.zoom.us/j/123456?pwd=x');
  });

  test('híbrida: sala no Local, link nas Notas', () {
    expect(linkDeReuniao(_ev(local: 'Sala 204', notas: 'Link: https://teams.microsoft.com/l/meetup-join/abc.')),
        'https://teams.microsoft.com/l/meetup-join/abc');
  });

  test('sem link de chamada, nada', () {
    expect(linkDeReuniao(_ev(local: 'Bloco C', notas: 'ver https://exemplo.com/pauta')), isNull);
    expect(linkDeReuniao(_ev(notas: 'meet.google.com')), isNull);
  });

  test('notas sem o bloco de chamada', () {
    expect(notasSemBlocoDeChamada(_blocoDoGoogle), isNull);
    expect(notasSemBlocoDeChamada('Pauta: orçamento\n\n$_blocoDoGoogle'), 'Pauta: orçamento');
    expect(notasSemBlocoDeChamada('Só texto'), 'Só texto');
  });

  test('hora de entrar: 10 min antes até o fim', () {
    final e = Evento(
      id: 'x',
      titulo: 'R',
      inicio: DateTime(2026, 11, 16, 19),
      fim: DateTime(2026, 11, 16, 20),
    );
    final o = Ocorrencia(e, e.inicio, e.fim!);
    expect(horaDeEntrar(o, DateTime(2026, 11, 16, 18, 49)), isFalse);
    expect(horaDeEntrar(o, DateTime(2026, 11, 16, 18, 50)), isTrue);
    expect(horaDeEntrar(o, DateTime(2026, 11, 16, 19, 59)), isTrue);
    expect(horaDeEntrar(o, DateTime(2026, 11, 16, 20)), isFalse);
  });

  testWidgets('card: Entrar no lugar do bloco do Google', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final state = AppState();
    await state.carregar();
    final e = Evento.novo(
      titulo: 'Entrevista',
      tipo: 'Reunião',
      inicio: DateTime(2026, 12, 2, 15),
      fim: DateTime(2026, 12, 2, 16),
      notas: 'Levar portfólio\n\n$_blocoDoGoogle',
    );
    await state.adicionarEvento(e);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: Scaffold(body: EventoTile(ocorrencia: Ocorrencia(e, e.inicio, e.fim!)))),
      ),
    );
    // Longe da hora: sem atalho na linha.
    expect(find.byTooltip('Entrar'), findsNothing);

    await tester.tap(find.byType(EventoTile));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Levar portfólio'), findsOneWidget);
    expect(find.textContaining('Não edite esta seção'), findsNothing);
  });
}
