import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/ui/eventos_do_tipo_screen.dart';
import 'package:tabelador/util/eventos_do_tipo.dart';

void main() {
  // Quarta, 11/11/2026, 10h. Semana vai até domingo 15/11.
  final agora = DateTime(2026, 11, 11, 10);

  final semanal = Evento(
    id: 'grupo',
    titulo: 'Grupo de pesquisa',
    inicio: DateTime(2026, 11, 5, 16), // quinta
    fim: DateTime(2026, 11, 5, 17),
    tipo: 'Reunião',
    repeticao: Repeticao.semanal,
  );
  Evento unica(String id, DateTime inicio) =>
      Evento(id: id, titulo: id, inicio: inicio, fim: inicio.add(const Duration(hours: 1)), tipo: 'Reunião');

  List<Ocorrencia> ocorrencias(List<Evento> es) => [
        for (final e in es) ...e.ocorrenciasEntre(DateTime(2026, 10, 12), DateTime(2027, 11, 11)),
      ]..sort((a, b) => a.inicio.compareTo(b.inicio));

  test('série vira uma linha; na linha do tempo só a desta semana', () {
    final p = organizarPaginaDoTipo(
      ocorrencias([
        semanal,
        unica('Alinhamento', DateTime(2026, 11, 14, 9)),
        unica('Planejamento', DateTime(2026, 11, 18, 10)),
        unica('Kickoff', DateTime(2026, 12, 2, 10)),
        unica('Retro', DateTime(2026, 11, 3, 10)), // passou
      ]),
      agora,
    );
    expect(p.proxima!.evento.titulo, 'Grupo de pesquisa'); // qui 12
    expect(p.series.single.evento.id, 'grupo');
    expect(p.series.single.vezes, greaterThan(50));
    expect(
      [for (final g in p.grupos) '${g.rotulo}: ${g.ocorrencias.map((o) => o.evento.titulo).join(', ')}'],
      [
        'Esta semana: Alinhamento',
        'Próxima semana: Planejamento',
        'Dezembro: Kickoff',
      ],
    );
    expect(p.passadas.map((o) => o.evento.titulo), ['Retro']);
  });

  test('reuniões separadas de mesmo nome, dia e hora viram série; cada uma com seu link', () {
    Evento caesi(String id, DateTime inicio, String link) => Evento(
          id: id,
          titulo: id == 'c3' ? 'reunião geral caesi ' : 'Reunião Geral CAESI',
          inicio: inicio,
          fim: inicio.add(const Duration(hours: 1)),
          tipo: 'Reunião',
          local: link,
          agendaId: 'principal',
        );
    final es = [
      caesi('c1', DateTime(2026, 11, 16, 19), 'meet.google.com/aaa-aaaa-aaa'),
      caesi('c2', DateTime(2026, 11, 23, 19), 'meet.google.com/bbb-bbbb-bbb'),
      caesi('c3', DateTime(2026, 11, 30, 19), 'meet.google.com/ccc-cccc-ccc'),
      // Mesmo nome, outro horário: fica de fora.
      caesi('c4', DateTime(2026, 11, 21, 10), 'meet.google.com/ddd-dddd-ddd'),
    ];
    final p = organizarPaginaDoTipo(ocorrencias(es), agora);

    final serie = p.series.single;
    expect(serie.vezes, 3);
    expect(serie.padrao, 'Segundas, 19:00');
    expect(serie.proxima.evento.id, 'c1');
    // Fora da semana, as da série saem da linha do tempo; a solta fica.
    final naLinha = [for (final g in p.grupos) for (final o in g.ocorrencias) o.evento.id];
    expect(naLinha, isNot(contains('c2')));
    expect(naLinha, contains('c4'));
  });

  test('série do Google (mesmo evento lá) também agrupa', () {
    Evento instancia(DateTime inicio) => Evento(
          id: 'g:77:${inicio.millisecondsSinceEpoch}',
          titulo: 'Aluguel',
          inicio: inicio,
          diaInteiro: true,
          tipo: 'Reunião',
          agendaId: 'principal',
        );
    final p = organizarPaginaDoTipo(
      ocorrencias([instancia(DateTime(2026, 12, 5)), instancia(DateTime(2027, 1, 5))]),
      agora,
    );
    expect(p.series.single.padrao, 'Todo dia 5');
  });

  test('contagem regressiva', () {
    expect(contagemRegressiva(DateTime(2026, 11, 11, 20), agora), 'Hoje');
    expect(contagemRegressiva(DateTime(2026, 11, 12), agora), 'Amanhã');
    expect(contagemRegressiva(DateTime(2026, 11, 16), agora), 'em 5 dias');
    expect(contagemRegressiva(DateTime(2027, 3, 11), agora), 'em 4 meses');
  });

  testWidgets('tela: destaque, calendário, série e tocar num dia', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final state = AppState();
    await state.carregar();
    final hoje = DateTime.now();
    final daqui3 = DateTime(hoje.year, hoje.month, hoje.day + 3, 10);
    await state.adicionarEvento(Evento(
      id: 'r',
      titulo: 'Reunião semanal',
      inicio: DateTime(hoje.year, hoje.month, hoje.day + 1, 16),
      fim: DateTime(hoje.year, hoje.month, hoje.day + 1, 17),
      tipo: 'Reunião',
      repeticao: Repeticao.semanal,
    ));
    await state.adicionarEvento(unica('Planejamento', daqui3));

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: EventosDoTipoScreen(tipo: TipoEvento.reuniao)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PRÓXIMA REUNIÃO'), findsOneWidget);
    expect(find.text('SE REPETEM'), findsOneWidget);
    // A semanal aparece uma vez como série (+ destaque), não 53 vezes.
    expect(find.text('Reunião semanal'), findsNWidgets(2));

    // Tocar no dia do Planejamento abre o painel do dia (se for este mês).
    if (daqui3.month == hoje.month) {
      await tester.tap(find.text('${daqui3.day}').first);
      await tester.pumpAndSettle();
      // Painel do dia aberto (com o botão de fechar) mostrando o evento.
      expect(find.byTooltip('Fechar'), findsOneWidget);
      expect(find.text('Planejamento'), findsWidgets);
    }
  });
}
