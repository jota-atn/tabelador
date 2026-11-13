import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../model/evento.dart';

/// Uma agenda que o Android conhece — normalmente as do Google Agenda das
/// contas do aparelho (a principal, com o e-mail como nome; "Feriados no
/// Brasil"; uma por turma do Classroom...).
@immutable
class AgendaDoAparelho {
  const AgendaDoAparelho({
    required this.id,
    required this.nome,
    required this.conta,
    required this.tipoConta,
    required this.cor,
    required this.nivelAcesso,
    required this.visivel,
    required this.sincroniza,
    this.dono = '',
  });

  factory AgendaDoAparelho.fromMap(Map<Object?, Object?> m) => AgendaDoAparelho(
        id: m['id']! as String,
        nome: (m['nome'] as String?)?.trim().isNotEmpty == true
            ? m['nome']! as String
            : 'Sem nome',
        conta: (m['conta'] as String?) ?? '',
        tipoConta: (m['tipoConta'] as String?) ?? '',
        cor: m['cor'] as int?,
        nivelAcesso: (m['nivelAcesso'] as int?) ?? 0,
        visivel: (m['visivel'] as bool?) ?? false,
        sincroniza: (m['sincroniza'] as bool?) ?? false,
        dono: (m['dono'] as String?) ?? '',
      );

  final String id;
  final String nome;

  /// Conta dona da agenda (o e-mail, no caso do Google). Agrupa a lista.
  final String conta;

  /// `com.google`, `LOCAL`... — local é agenda criada por algum app no
  /// próprio aparelho, sem conta por trás.
  final String tipoConta;

  /// ARGB, como o Android guarda.
  final int? cor;

  /// `CALENDAR_ACCESS_LEVEL` do Android: 700 dono, 500 colaborador, 200
  /// só leitura (feriados, turmas do Classroom pra aluno).
  final int nivelAcesso;

  /// Marcada pra aparecer no app de agenda do sistema. Não afeta o que o
  /// Android baixa.
  final bool visivel;

  /// `SYNC_EVENTS`: se o Android baixa os eventos dela. Turma do Classroom
  /// costuma vir desligada — aí a agenda existe mas fica vazia no aparelho.
  final bool sincroniza;

  /// `OWNER_ACCOUNT`: identifica turma do Classroom
  /// (`classroom…@group.calendar.google.com`) e agenda de feriados
  /// (`…#holiday@group.v.calendar.google.com`).
  final String dono;

  TipoEvento get tipoSugerido => tipoSugeridoPeloDono(dono);

  bool get somenteLeitura => nivelAcesso < 500;
  bool get doGoogle => tipoConta == 'com.google';

  /// O que já vem marcado na primeira vez: as agendas que o usuário de fato
  /// usa — do Google, visíveis e sincronizando (a principal de cada conta e
  /// os feriados, tipicamente). Turmas ficam pra ele escolher.
  bool get selecionadaPorPadrao => doGoogle && visivel && sincroniza;
}

/// Tipo padrão dos eventos de uma agenda, pelo dono dela: turma do
/// Classroom → Tarefa (cada atividade tem prazo); feriados → Feriado;
/// qualquer outra → Outro.
TipoEvento tipoSugeridoPeloDono(String dono) {
  final d = dono.toLowerCase();
  if (d.endsWith('#holiday@group.v.calendar.google.com')) return TipoEvento.feriado;
  if (d.endsWith('@group.calendar.google.com') &&
      (d.startsWith('classroom') || d.startsWith('c_classroom'))) {
    return TipoEvento.tarefa;
  }
  return TipoEvento.outro;
}

/// De onde o [AppState] lê eventos externos. Interface pra os testes
/// trocarem por uma fonte falsa sem canal de plataforma.
abstract class FonteDeEventosExternos {
  Future<bool> temPermissao();

  Future<List<AgendaDoAparelho>> listar();

  /// Grava [evento] (do app) na agenda [agendaId] do aparelho — cria se
  /// [idNoAparelho] for nulo, atualiza se não. Devolve o id lá.
  Future<String> gravarEvento(Evento evento, String agendaId, {String? idNoAparelho});

  Future<void> apagarEvento(String idNoAparelho);

  /// Ocorrências das agendas [agendaIds] que se sobrepõem a `[de, ate)`.
  Future<List<Evento>> lerEventos(
    Set<String> agendaIds,
    DateTime de,
    DateTime ate, {
    Map<String, int?> cores = const {},
  });
}

/// Agenda do Android (CalendarContract). Permissão pelo plugin
/// `device_calendar`; o resto por uma ponte própria (`AgendaChannel.kt`),
/// porque o plugin não expõe a chave de sincronização das agendas nem
/// trata bem evento de dia inteiro. O app fala só com esta classe — trocar
/// o mecanismo por baixo mexe só aqui.
class AgendasDoAparelho implements FonteDeEventosExternos {
  AgendasDoAparelho([dc.DeviceCalendarPlugin? plugin])
      : _plugin = plugin ?? dc.DeviceCalendarPlugin();

  final dc.DeviceCalendarPlugin _plugin;
  static const _canal = MethodChannel('tabelador/agenda');

  @override
  Future<bool> temPermissao() async {
    final r = await _plugin.hasPermissions();
    return r.isSuccess && (r.data ?? false);
  }

  /// Mostra o diálogo do sistema se ainda não foi concedida.
  Future<bool> pedirPermissao() async {
    final r = await _plugin.requestPermissions();
    return r.isSuccess && (r.data ?? false);
  }

  @override
  Future<List<AgendaDoAparelho>> listar() async {
    final bruto = await _canal.invokeListMethod<Map<Object?, Object?>>('listarAgendas');
    return [for (final m in bruto ?? const []) AgendaDoAparelho.fromMap(m)];
  }

  /// Liga/desliga o "baixar eventos" de uma agenda no Android. Ligado, o
  /// adaptador do Google baixa os eventos dela na próxima sincronização —
  /// leva de segundos a alguns minutos, não é imediato.
  Future<void> definirSincronizacao(String id, {required bool ativa}) =>
      _canal.invokeMethod<void>('definirSincronizacao', {'id': id, 'ativa': ativa});

  @override
  Future<String> gravarEvento(Evento evento, String agendaId, {String? idNoAparelho}) async {
    final id = await _canal.invokeMethod<String>('gravarEvento', {
      'eventoId': idNoAparelho,
      'agendaId': agendaId,
      'campos': camposParaAparelho(evento),
    });
    return id!;
  }

  @override
  Future<void> apagarEvento(String idNoAparelho) =>
      _canal.invokeMethod<void>('apagarEvento', {'eventoId': idNoAparelho});

  @override
  Future<List<Evento>> lerEventos(
    Set<String> agendaIds,
    DateTime de,
    DateTime ate, {
    Map<String, int?> cores = const {},
  }) async {
    if (agendaIds.isEmpty) return const [];
    final bruto = await _canal.invokeListMethod<Map<Object?, Object?>>('lerEventos', {
      'ids': agendaIds.toList(),
      'de': de.millisecondsSinceEpoch,
      'ate': ate.millisecondsSinceEpoch,
    });
    return [for (final m in bruto ?? const []) eventoDoAparelho(m, cores)];
  }
}

/// Converte uma linha de `lerEventos` em [Evento] externo (só leitura).
///
/// Dia inteiro: o Android guarda em meia-noite **UTC**; ler como hora local
/// jogaria o Natal pro dia 24 à noite em qualquer fuso a oeste de
/// Greenwich. Por isso a data sai dos componentes UTC, e a hora é ignorada.
@visibleForTesting
Evento eventoDoAparelho(Map<Object?, Object?> m, Map<String, int?> cores) {
  final diaInteiro = (m['diaInteiro'] as bool?) ?? false;
  final inicioMs = (m['inicio']! as num).toInt();
  final fimMs = (m['fim'] as num?)?.toInt() ?? inicioMs;

  DateTime inicio;
  DateTime? fim;
  if (diaInteiro) {
    final u = DateTime.fromMillisecondsSinceEpoch(inicioMs, isUtc: true);
    inicio = DateTime(u.year, u.month, u.day);
    // Fim do Google é exclusivo (meia-noite do dia seguinte ao último); no
    // app [Evento.fim] de dia todo é o último dia.
    final f = DateTime.fromMillisecondsSinceEpoch(fimMs, isUtc: true);
    final ultimo = DateTime(f.year, f.month, f.day - 1);
    if (ultimo.isAfter(inicio)) fim = ultimo;
  } else {
    inicio = DateTime.fromMillisecondsSinceEpoch(inicioMs);
    fim = DateTime.fromMillisecondsSinceEpoch(fimMs);
  }

  final agendaId = m['agendaId']! as String;
  String? texto(Object? v) => (v is String && v.trim().isNotEmpty) ? v.trim() : null;

  return Evento(
    // Mesma série recorrente gera várias linhas com o mesmo eventoId — o
    // início desambigua cada ocorrência.
    id: 'g:${m['eventoId']}:$inicioMs',
    titulo: texto(m['titulo']) ?? '(sem título)',
    inicio: inicio,
    fim: fim,
    diaInteiro: diaInteiro,
    local: texto(m['local']),
    notas: texto(m['descricao']),
    agendaId: agendaId,
    corExterna: cores[agendaId],
    idNoAparelho: '${m['eventoId']}',
  );
}

/// O que vai pro `gravarEvento` nativo. Dia inteiro em meia-noite UTC (o
/// inverso de [eventoDoAparelho]); evento sem término vira um ponto
/// (início = fim); repetição vira RRULE.
@visibleForTesting
Map<String, Object?> camposParaAparelho(Evento e) {
  int inicio;
  int fim;
  if (e.diaInteiro) {
    inicio = DateTime.utc(e.inicio.year, e.inicio.month, e.inicio.day).millisecondsSinceEpoch;
    final ultimo = e.ultimoDia;
    fim = DateTime.utc(ultimo.year, ultimo.month, ultimo.day + 1).millisecondsSinceEpoch;
  } else {
    inicio = e.inicio.millisecondsSinceEpoch;
    fim = (e.fim != null && e.fim!.isAfter(e.inicio) ? e.fim! : e.inicio).millisecondsSinceEpoch;
  }
  return {
    'titulo': e.titulo,
    'inicio': inicio,
    'fim': fim,
    'diaInteiro': e.diaInteiro,
    'local': e.local,
    'descricao': e.notas,
    // Mesma semântica do app: mensal num dia 31 e anual em 29/02 pulam o
    // que não existe — é o que a RFC 5545 já faz com data inválida.
    'rrule': switch (e.repeticao) {
      Repeticao.nenhuma => null,
      Repeticao.diaria => 'FREQ=DAILY',
      Repeticao.semanal => 'FREQ=WEEKLY',
      Repeticao.mensal => 'FREQ=MONTHLY',
      Repeticao.anual => 'FREQ=YEARLY',
    },
  };
}
