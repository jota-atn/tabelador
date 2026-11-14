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

  final todas = [
    semanal,
    unica('Alinhamento', DateTime(2026, 11, 14, 9)),
    unica('Planejamento', DateTime(2026, 11, 18, 10)),
    unica('Kickoff', DateTime(2026, 12, 2, 10)),
    unica('Retro', DateTime(2026, 11, 3, 10)), // passou
  ];

  test('topo: destaques um por evento; série conta no ano', () {
    final p = organizarPaginaDoTipo(ocorrencias(todas), agora);
    expect(p.proxima!.evento.titulo, 'Grupo de pesquisa'); // qui 12
    // A semanal entra uma vez só; o resto em ordem.
    expect(p.destaques.map((o) => o.evento.titulo), ['Grupo de pesquisa', 'Alinhamento', 'Planejamento', 'Kickoff']);
    expect(p.series.single.evento.id, 'grupo');
    expect(p.series.single.vezes, greaterThan(50));
  });

  test('lista do mês: série uma vez com quantas no mês; passadas também', () {
    final novembro = [
      for (final o in ocorrencias(todas))
        if (o.inicio.month == 11 && o.inicio.year == 2026) o,
    ];
    final m = organizarMesDoTipo(novembro, agora);
    expect(m.series.single.evento.id, 'grupo');
    expect(m.series.single.vezes, 4); // 5, 12, 19, 26
    expect(m.series.single.proxima.inicio.day, 12);
    expect(m.avulsas.map((o) => o.evento.titulo), ['Retro', 'Alinhamento', 'Planejamento']);
  });

  test('no mês, repetição do app com uma vez só é linha comum (aniversário)', () {
    final anual = Evento(
      id: 'niver',
      titulo: 'Aniversário',
      inicio: DateTime(2020, 11, 20),
      diaInteiro: true,
      tipo: 'Aniversário',
      repeticao: Repeticao.anual,
    );
    final m = organizarMesDoTipo(anual.ocorrenciasEntre(DateTime(2026, 11), DateTime(2026, 12)), agora);
    expect(m.series, isEmpty);
    expect(m.avulsas, hasLength(1));
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
    // No mês: a série numa linha, a de outro horário avulsa.
    final m = organizarMesDoTipo(ocorrencias(es), agora);
    expect(m.series.single.vezes, 3);
    expect(m.avulsas.map((o) => o.evento.id), ['c4']);
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

  testWidgets('tela: destaque que desliza, calendário e tocar num dia', (tester) async {
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
    // O card seguinte já aparece na borda.
    expect(find.text('DEPOIS'), findsWidgets);
    // A semanal não enche a tela: no máximo destaque + uma linha no mês.
    expect(find.text('Reunião semanal').evaluate().length, lessThanOrEqualTo(2));

    // Tocar no dia do Planejamento filtra a lista (se for este mês).
    if (daqui3.month == hoje.month) {
      await tester.tap(find.descendant(of: find.byType(GridView), matching: find.text('${daqui3.day}')));
      await tester.pumpAndSettle();
      expect(find.text('Mês todo'), findsOneWidget);
      expect(find.text('Planejamento'), findsWidgets);
      await tester.tap(find.text('Mês todo'));
      await tester.pumpAndSettle();
      expect(find.text('Mês todo'), findsNothing);
    }
  });
}
