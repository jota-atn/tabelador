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

  /// O que o app gravou "no aparelho": id lá -> (evento, agenda).
  final gravados = <String, (Evento, String)>{};
  var _proximoId = 100;

  @override
  Future<bool> temPermissao() async => permissao;

  @override
  Future<List<AgendaDoAparelho>> listar() async => const [
        AgendaDoAparelho(
          id: 'principal',
          nome: 'eu@gmail.com',
          conta: 'eu@gmail.com',
          tipoConta: 'com.google',
          cor: null,
          nivelAcesso: 700,
          visivel: true,
          sincroniza: true,
        ),
        AgendaDoAparelho(
          id: 'feriados',
          nome: 'Feriados no Brasil',
          conta: 'eu@gmail.com',
          tipoConta: 'com.google',
          cor: null,
          nivelAcesso: 200,
          visivel: true,
          sincroniza: true,
          dono: 'pt-br.brazilian#holiday@group.v.calendar.google.com',
        ),
        AgendaDoAparelho(
          id: 'feriados2',
          nome: 'Feriados no Brasil',
          conta: 'outra@gmail.com',
          tipoConta: 'com.google',
          cor: null,
          nivelAcesso: 200,
          visivel: true,
          sincroniza: true,
          dono: 'pt.brazilian#holiday@group.v.calendar.google.com',
        ),
        AgendaDoAparelho(
          id: 'turma',
          nome: '2025.2 Teoria da Computação',
          conta: 'eu@gmail.com',
          tipoConta: 'com.google',
          cor: null,
          nivelAcesso: 200,
          visivel: false,
          sincroniza: true,
          dono: 'classroom112233@group.calendar.google.com',
        ),
      ];

  @override
  Future<String> gravarEvento(Evento evento, String agendaId, {String? idNoAparelho}) async {
    final id = idNoAparelho ?? '${_proximoId++}';
    gravados[id] = (evento, agendaId);
    return id;
  }

  @override
  Future<void> apagarEvento(String idNoAparelho) async => gravados.remove(idNoAparelho);

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
      // O que foi gravado volta na leitura como externo, como no Android.
      for (final g in gravados.entries)
        if (agendaIds.contains(g.value.$2))
          Evento(
            id: 'g:${g.key}',
            titulo: g.value.$1.titulo,
            inicio: g.value.$1.inicio,
            agendaId: g.value.$2,
            idNoAparelho: g.key,
          ),
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

  group('gravar no Google', () {
    Future<(AppState, _FonteFalsa)> montar() async {
      final fonte = _FonteFalsa(const []);
      final state = AppState(fonteExterna: fonte);
      await state.carregar();
      await state.definirAgendas({
        'principal': const AgendaEscolhida(nome: 'eu@gmail.com', gravavel: true),
        'feriados': const AgendaEscolhida(nome: 'Feriados no Brasil'),
      });
      return (state, fonte);
    }

    final amanha = DateTime.now().add(const Duration(days: 1));

    test('salva cópia, lembra o destino e não duplica na leitura', () async {
      final (state, fonte) = await montar();
      expect(state.agendasGravaveis.keys, ['principal']);

      final ok = await state.adicionarEvento(
        Evento.novo(titulo: 'Prova', inicio: amanha),
        salvarEm: 'principal',
      );
      expect(ok, isTrue);
      expect(fonte.gravados, hasLength(1));
      expect(state.eventos.single.gravadoNoGoogle, isTrue);
      expect(state.agendaDestinoPadrao, 'principal');

      await state.recarregarEventosExternos();
      expect(state.eventosExternos, hasLength(1)); // voltou na leitura...
      final ocorrencias = state.ocorrenciasEntre(
        amanha.subtract(const Duration(days: 1)),
        amanha.add(const Duration(days: 1)),
      );
      expect(ocorrencias, hasLength(1)); // ...mas aparece uma vez só
      expect(ocorrencias.single.evento.externo, isFalse);
    });

    test('editar atualiza a mesma cópia; "só no app" apaga ela', () async {
      final (state, fonte) = await montar();
      final e = Evento.novo(titulo: 'Prova', inicio: amanha);
      await state.adicionarEvento(e, salvarEm: 'principal');
      final idLa = state.eventos.single.idNoAparelho;

      await state.atualizarEvento(
        Evento(id: e.id, titulo: 'Prova 2', inicio: amanha),
        salvarEm: 'principal',
      );
      expect(fonte.gravados.keys, [idLa]);
      expect(fonte.gravados[idLa]!.$1.titulo, 'Prova 2');

      await state.atualizarEvento(Evento(id: e.id, titulo: 'Prova 2', inicio: amanha));
      expect(fonte.gravados, isEmpty);
      expect(state.eventos.single.gravadoNoGoogle, isFalse);
    });

    test('apagar no app apaga a cópia', () async {
      final (state, fonte) = await montar();
      final e = Evento.novo(titulo: 'Prova', inicio: amanha);
      await state.adicionarEvento(e, salvarEm: 'principal');
      await state.removerEvento(e.id);
      expect(fonte.gravados, isEmpty);
    });

    test('metadados vêm do aparelho: "gravável" de versão antiga é corrigido',
        () async {
      final fonte = _FonteFalsa(const []);
      final state = AppState(fonteExterna: fonte);
      await state.carregar();
      // Como ficou salvo antes de existir "gravável".
      await state.definirAgendas({'principal': const AgendaEscolhida(nome: 'x')});
      expect(state.agendasGravaveis.keys, ['principal']);
    });
  });

  test('campos pro aparelho: dia inteiro em meia-noite UTC e RRULE', () {
    final c = camposParaAparelho(Evento.novo(
      titulo: 'Aniversário',
      inicio: DateTime(2026, 12, 25),
      diaInteiro: true,
      repeticao: Repeticao.anual,
    ));
    expect(c['inicio'], DateTime.utc(2026, 12, 25).millisecondsSinceEpoch);
    expect(c['fim'], DateTime.utc(2026, 12, 26).millisecondsSinceEpoch);
    expect(c['rrule'], 'FREQ=YEARLY');
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

  group('tipo por agenda (v1.2)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('dono sugere o tipo', () {
      expect(tipoSugeridoPeloDono('classroom1@group.calendar.google.com'), TipoEvento.tarefa);
      expect(tipoSugeridoPeloDono('c_classroom9@group.calendar.google.com'), TipoEvento.tarefa);
      expect(tipoSugeridoPeloDono('pt-br.brazilian#holiday@group.v.calendar.google.com'),
          TipoEvento.feriado);
      expect(tipoSugeridoPeloDono('eu@gmail.com'), TipoEvento.outro);
    });

    test('Classroom vira tarefa concluível e ocultável; feriado repetido aparece uma vez',
        () async {
      final hoje = DateTime.now();
      final daqui3 = DateTime(hoje.year, hoje.month, hoje.day + 3);
      final fonte = _FonteFalsa([
        _externo('Lista 3', daqui3, 'turma'),
        _externo('Natal', daqui3, 'feriados'),
        _externo('Natal', daqui3, 'feriados2'),
      ]);
      final state = AppState(fonteExterna: fonte);
      await state.carregar();
      await state.definirAgendas({
        'turma': const AgendaEscolhida(nome: 'turma'),
        'feriados': const AgendaEscolhida(nome: 'f'),
        'feriados2': const AgendaEscolhida(nome: 'f2'),
      });

      expect(state.eventosExternos.map((e) => '${e.titulo}:${e.tipo}'),
          ['Lista 3:Tarefa', 'Natal:Feriado']);
      final lista = state.tarefas.single;
      expect(lista.externo, isTrue);

      await state.marcarFeita(Ocorrencia(lista, lista.inicio, lista.fim ?? lista.inicio), true);
      expect(state.tarefas.single.feito, isTrue);

      // Persistido: outra instância lê o "feito" de volta.
      final outro = AppState(fonteExterna: fonte);
      await outro.carregar();
      // carregar() já dispara a leitura do Google sem esperar; dá a vez.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(outro.tarefas.single.feito, isTrue);

      await state.ocultarExterno(lista.id);
      expect(state.tarefas, isEmpty);
      await state.reexibirExterno(lista.id);
      expect(state.tarefas, hasLength(1));

      // Mudar o tipo da agenda vale na hora, sem reler.
      await state.definirTipoDaAgenda('turma', TipoEvento.prova);
      expect(state.tarefas, isEmpty);
      expect(state.agendas['turma']!.tipo, 'Prova');
    });
  });
}
