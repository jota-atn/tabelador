import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/ui/eventos_screen.dart';
import 'package:tabelador/ui/folha_evento.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('aviso de dia todo, lembrete de presente e tipos escondidos: guarda e o backup leva', () async {
    final state = AppState(feriadosEmbutidos: false);
    await state.carregar();
    expect(state.avisoDiaTodoMin, kAvisoDiaTodoPadrao);
    expect(state.diasAvisoPresente, kDiasAvisoPresentePadrao);

    await state.definirAvisoDiaTodoMin(8 * 60 + 30);
    await state.definirDiasAvisoPresente(3);
    await state.definirTipoEscondido(TipoEvento.viagem, true);

    final outro = AppState(feriadosEmbutidos: false);
    await outro.carregar();
    expect(outro.avisoDiaTodoMin, 8 * 60 + 30);
    expect(outro.diasAvisoPresente, 3);
    expect(outro.tiposEscondidos, {TipoEvento.viagem});

    final backup = outro.paraBackup();
    SharedPreferences.setMockInitialValues({});
    final restaurado = AppState(feriadosEmbutidos: false);
    await restaurado.carregar();
    await restaurado.restaurarBackup(backup);
    expect(restaurado.avisoDiaTodoMin, 8 * 60 + 30);
    expect(restaurado.diasAvisoPresente, 3);
    expect(restaurado.tiposEscondidos, {TipoEvento.viagem});
  });

  Future<void> montar(WidgetTester tester, AppState state, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: MaterialApp(home: home)));
    await tester.pump();
  }

  testWidgets('tipo escondido some da aba Eventos e da criação', (tester) async {
    final state = AppState(feriadosEmbutidos: false);
    await state.carregar();
    await montar(tester, state, const EventosScreen());
    expect(find.text('Viagens'), findsOneWidget); // chip de tipo vazio

    await state.definirTipoEscondido(TipoEvento.viagem, true);
    await tester.pump();
    expect(find.text('Viagens'), findsNothing);

    await montar(tester, state, const Scaffold(body: FolhaDeEvento()));
    await tester.pumpAndSettle();
    expect(find.text('Consulta'), findsOneWidget);
    expect(find.text('Viagem'), findsNothing);
  });

  testWidgets('evento novo de dia todo usa o aviso padrão de Ajustes', (tester) async {
    final state = AppState(feriadosEmbutidos: false);
    await state.carregar();
    await state.definirAvisoDiaTodoMin(9 * 60);
    await montar(tester, state, const Scaffold(body: FolhaDeEvento(tipoInicial: TipoEvento.aniversario)));
    await tester.pumpAndSettle();
    final folha = tester.state<FolhaDeEventoState>(find.byType(FolhaDeEvento));
    expect(folha.avisoMin, 9 * 60);
  });
}
