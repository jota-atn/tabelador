import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/agenda/agendas_do_aparelho.dart';
import 'package:tabelador/data/tabelador_store.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/state/app_state.dart';

class _FonteFalsa implements FonteDeEventosExternos {
  _FonteFalsa(this.eventos, {this.permissao = true});

  final List<Evento> eventos;
  final bool permissao;
  Set<String>? pedidas;

  @override
  Future<bool> temPermissao() async => permissao;

  @override
  Future<List<Evento>> lerEventos(
    Set<String> agendaIds,
    DateTime de,
    DateTime ate, {
    Map<String, int?> cores = const {},
  }) async {
    pedidas = agendaIds;
    return [
      for (final e in eventos)
        if (agendaIds.contains(e.agendaId)) e,
    ];
  }
}

Evento _externo(String titulo, DateTime inicio, String agenda) => Evento(
      id: 'g:$titulo',
      titulo: titulo,
      inicio: inicio,
      diaInteiro: true,
      agendaId: agenda,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('eventoDoAparelho', () {
    test('dia inteiro usa a data UTC, não a hora local', () {
      // Natal: meia-noite UTC de 25/12, como o Android guarda.
      final ms = DateTime.utc(2026, 12, 25).millisecondsSinceEpoch;
      final e = eventoDoAparelho({
        'eventoId': '7',
        'agendaId': '22',
        'titulo': 'Natal',
        'inicio': ms,
        'fim': DateTime.utc(2026, 12, 26).millisecondsSinceEpoch,
        'diaInteiro': true,
      }, {'22': 0xFF00AA00});

      expect(e.inicio, DateTime(2026, 12, 25));
      expect(e.diaInteiro, isTrue);
      expect(e.externo, isTrue);
      expect(e.corExterna, 0xFF00AA00);
      expect(e.id, 'g:7:$ms');
    });

    test('com hora vira horário local, com fim', () {
      final inicio = DateTime(2026, 11, 13, 10);
      final e = eventoDoAparelho({
        'eventoId': '1',
        'agendaId': '6',
        'titulo': '  ',
        'inicio': inicio.millisecondsSinceEpoch,
        'fim': inicio.add(const Duration(hours: 2)).millisecondsSinceEpoch,
        'diaInteiro': false,
        'local': '',
      }, const {});
      expect(e.inicio, inicio);
      expect(e.fim, DateTime(2026, 11, 13, 12));
      expect(e.titulo, '(sem título)');
      expect(e.local, isNull);
    });
  });

  test('só lê as agendas escolhidas, e elas entram nas ocorrências', () async {
    final hoje = DateTime.now();
    final daqui3 = DateTime(hoje.year, hoje.month, hoje.day + 3);
    final fonte = _FonteFalsa([
      _externo('Feriado', daqui3, 'feriados'),
      _externo('Da turma', daqui3, 'turma'),
    ]);
    final state = AppState(fonteExterna: fonte);
    await state.carregar();
    expect(state.eventosExternos, isEmpty); // nada escolhido ainda

    await state.definirAgendas({
      'feriados': const AgendaEscolhida(nome: 'Feriados no Brasil'),
    });
    expect(fonte.pedidas, {'feriados'});
    expect(state.eventosExternos.map((e) => e.titulo), ['Feriado']);
    expect(
      state
          .ocorrenciasEntre(daqui3, daqui3.add(const Duration(days: 1)))
          .map((o) => o.evento.titulo),
      ['Feriado'],
    );
    // Externo não vai pra lista de eventos do app (nem pro backup).
    expect(state.eventos, isEmpty);
    expect(state.paraBackup()['eventos'], isEmpty);

    // A escolha persiste.
    final outro = AppState(fonteExterna: fonte);
    await outro.carregar();
    expect(outro.agendasConfiguradas, isTrue);
    expect(outro.agendas.keys, ['feriados']);
  });

  test('sem permissão, nenhum evento externo e nenhum erro', () async {
    final fonte = _FonteFalsa(
      [_externo('Feriado', DateTime.now(), 'feriados')],
      permissao: false,
    );
    final state = AppState(fonteExterna: fonte);
    await state.carregar();
    await state.definirAgendas({'feriados': const AgendaEscolhida(nome: 'F')});
    expect(state.eventosExternos, isEmpty);
  });
}
