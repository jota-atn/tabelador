import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../model/evento.dart';
import '../model/item.dart';
import '../model/tabela.dart';
import '../state/app_state.dart';
import '../util/eventos_na_grade.dart';

const AndroidNotificationChannel kCanalHorarios = AndroidNotificationChannel(
  'horarios_proximos',
  'Horários se aproximando',
  description: 'Avisa antes de cada horário preenchido da tabela ativa',
);

const AndroidNotificationChannel kCanalEventos = AndroidNotificationChannel(
  'eventos',
  'Eventos',
  description: 'Avisa antes de provas, compromissos e outros eventos',
);

/// Quantos dias à frente os avisos de evento ficam agendados. Evento é
/// alarme único (não recorrente como o de horário), então a janela anda
/// sozinha a cada vez que o app abre e o agendador ressincroniza.
const int kDiasAvisoEventos = 14;


/// Prepara o plugin de notificação local — ícone, canal Android, fuso do
/// aparelho. Chamado uma vez em `main()`, antes de criar o
/// [NotificationScheduler].
Future<FlutterLocalNotificationsPlugin> inicializarNotificacoes() async {
  tz_data.initializeTimeZones();
  try {
    final fuso = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(fuso.identifier));
  } catch (_) {
    // Fuso não reconhecido (raro): segue no UTC em vez de travar o app —
    // o pior caso é o aviso chegar na hora errada, não o app não abrir.
  }

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(kCanalHorarios);
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(kCanalEventos);

  return plugin;
}

/// Mantém os avisos de "horário se aproximando" sincronizados com a tabela
/// ativa e a preferência de antecedência.
///
/// Mesmo padrão do `HomeWidgetSync`: ouve um listener só do [AppState] (que
/// já dispara em toda mutação) em vez de listar manualmente quais mutators
/// "importam" — editar a sigla de um item ou destravar um dia novo na tabela
/// ativa também muda o que devia estar agendado. Recalcula uma assinatura do
/// que deveria existir e só mexe no plugin nativo (cancelar tudo, reagendar
/// tudo) se ela realmente mudou.
class NotificationScheduler {
  NotificationScheduler(this._appState, this._plugin) {
    _appState.addListener(_agendar);
  }

  final AppState _appState;
  final FlutterLocalNotificationsPlugin _plugin;

  String? _ultimaAssinatura;
  bool _sincronizando = false;
  bool _pendente = false;

  void _agendar() => unawaited(sincronizarAgora());

  /// Chamada em toda mutação de [AppState] e também quando o app volta pro
  /// primeiro plano — inexato + sem `RECEIVE_BOOT_COMPLETED` significa que
  /// reiniciar o aparelho derruba os alarmes; abrir o app de novo é o que
  /// reagenda, o mesmo reforço que o widget já usa pro próprio refresh.
  Future<void> sincronizarAgora() async {
    if (!_appState.carregado) return;

    if (_sincronizando) {
      _pendente = true;
      return;
    }

    _sincronizando = true;
    try {
      var repetir = true;
      while (repetir) {
        repetir = false;
        await _aplicar();
        if (_pendente) {
          _pendente = false;
          repetir = true;
        }
      }
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> _aplicar() async {
    final tabela = _appState.tabelaAtiva;
    final agendamentos = !_appState.notificacoesAtivas || tabela == null
        ? const <_Agendamento>[]
        : _construirAgendamentos(
            tabela,
            _appState.antecedenciaMinutos,
            _appState.itemPorId,
            DateTime.now(),
            _folgasDaTabela(_appState, tabela),
          );
    final avisosDeEvento =
        !_appState.notificacoesAtivas || !_appState.notificarEventos
            ? const <_AvisoUnico>[]
            : _construirAvisosDeEvento(
                _appState,
                _appState.antecedenciaMinutos,
                DateTime.now(),
              );

    final assinatura = jsonEncode([
      for (final a in agendamentos)
        [a.id, a.titulo, a.corpo, a.primeira.toIso8601String()],
      for (final a in avisosDeEvento)
        [a.id, a.titulo, a.corpo, a.quando.toIso8601String()],
    ]);
    if (assinatura == _ultimaAssinatura) return;
    _ultimaAssinatura = assinatura;

    await _plugin.cancelAll();
    for (final a in agendamentos) {
      await _plugin.zonedSchedule(
        a.id,
        a.titulo,
        a.corpo,
        tz.TZDateTime(
          tz.local,
          a.primeira.year,
          a.primeira.month,
          a.primeira.day,
          a.primeira.hour,
          a.primeira.minute,
        ),
        NotificationDetails(
          android: AndroidNotificationDetails(
            kCanalHorarios.id,
            kCanalHorarios.name,
            channelDescription: kCanalHorarios.description,
          ),
        ),
        // Sem alarme exato — não pede a permissão "Alarmes e lembretes".
        // Pode atrasar alguns minutos em segundo plano; aceitável pra um
        // aviso de "está chegando", não pra um compromisso ao segundo.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    for (final a in avisosDeEvento) {
      await _plugin.zonedSchedule(
        a.id,
        a.titulo,
        a.corpo,
        tz.TZDateTime.from(a.quando, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            kCanalEventos.id,
            kCanalEventos.name,
            channelDescription: kCanalEventos.description,
          ),
        ),
        // Mesmo tradeoff do aviso de horário: inexato, sem permissão extra.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  void dispose() {
    _appState.removeListener(_agendar);
  }
}

class _Agendamento {
  const _Agendamento({
    required this.id,
    required this.titulo,
    required this.corpo,
    required this.primeira,
  });

  final int id;
  final String titulo;
  final String corpo;

  /// Primeiro disparo; dali repete toda semana no mesmo dia e hora. Pula
  /// a semana em que a aula cai em folga (o Android não deixa tirar uma
  /// data de um aviso recorrente — então ele só começa depois dela).
  final DateTime primeira;
}

/// Quantas semanas à frente procurar folga pra adiar o começo dos avisos
/// de aula. Feriado mais longe que isso é resolvido quando o app abrir de
/// novo.
const int _kSemanasFolga = 8;

/// "O dia de [quando] é folga na tabela?" pras próximas [_kSemanasFolga]
/// semanas, calculado uma vez.
String? Function(DateTime) _folgasDaTabela(AppState state, Tabela tabela) {
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final ocorrencias =
      state.ocorrenciasEntre(hoje, DateTime(hoje.year, hoje.month, hoje.day + 7 * _kSemanasFolga + 1));
  return (quando) => folgaNoDia(quando, tabela, ocorrencias);
}

class _AvisoUnico {
  const _AvisoUnico({
    required this.id,
    required this.titulo,
    required this.corpo,
    required this.quando,
  });

  final int id;
  final String titulo;
  final String corpo;
  final DateTime quando;
}

/// Base dos ids de aviso de evento — bem acima do maior id de horário
/// (7 × 100 + slot), pra nunca colidir.
const int _kBaseIdEvento = 100000;

/// Um aviso por ocorrência de evento nos próximos [kDiasAvisoEventos] dias,
/// de **todos** os eventos — ao contrário da grade, não filtra pela tabela
/// ativa: o aniversário escondido da tabela da academia continua merecendo
/// aviso. Aviso que já passou não é agendado.
List<_AvisoUnico> _construirAvisosDeEvento(
  AppState state,
  int antecedenciaMinutos,
  DateTime agora,
) {
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final ocorrencias = state.ocorrenciasEntre(
    hoje,
    DateTime(hoje.year, hoje.month, hoje.day + kDiasAvisoEventos),
  );

  final resultado = <_AvisoUnico>[];
  for (final o in ocorrencias) {
    final e = o.evento;
    // Tarefa já feita não precisa de lembrete; feriado embutido não é
    // compromisso, é calendário.
    if (o.feita || e.embutido) continue;
    final aviso = e.avisoMin ?? kAvisoDiaTodoPadrao;
    final quando = e.diaInteiro
        ? DateTime(o.inicio.year, o.inicio.month, o.inicio.day, aviso ~/ 60, aviso % 60)
        : o.inicio.subtract(Duration(minutes: antecedenciaMinutos));
    if (!quando.isAfter(agora)) continue;

    final local = e.local ?? state.itemPorId(e.itemId)?.local;
    String doisDigitos(int n) => n.toString().padLeft(2, '0');
    resultado.add(
      _AvisoUnico(
        id: _kBaseIdEvento + resultado.length,
        titulo: e.titulo,
        corpo: [
          e.diaInteiro
              ? 'Hoje'
              : 'Às ${doisDigitos(o.inicio.hour)}:${doisDigitos(o.inicio.minute)}',
          ?local,
        ].join(' · '),
        quando: quando,
      ),
    );
  }
  return resultado;
}

/// Um agendamento por célula preenchida da tabela — o próprio `id` (dia da
/// semana × 100 + slot) garante um por posição, sem colidir dentro da mesma
/// tabela. Como só a tabela ativa tem agendamento por vez (tudo é cancelado
/// antes de reagendar), não importa colidir com o id de outra tabela.
List<_Agendamento> _construirAgendamentos(
  Tabela tabela,
  int antecedenciaMinutos,
  Item? Function(String? id) itemPorId,
  DateTime agora,
  String? Function(DateTime dia) folgaEm,
) {
  final resultado = <_Agendamento>[];
  for (final dia in tabela.dias) {
    final diaSemana = kTodosDias.indexOf(dia) + 1;
    for (var slot = 0; slot < tabela.qtdHorarios; slot++) {
      final item = itemPorId(tabela.celula(dia, slot));
      if (item == null) continue;

      final horaDoSlot = tabela.horaInicial + slot * tabela.intervalo;
      final aviso = _comAntecedencia(diaSemana, horaDoSlot, antecedenciaMinutos);
      var primeira = _proximaOcorrencia(aviso.diaSemana, aviso.hora, aviso.minuto, agora);
      for (var i = 0;
          i < _kSemanasFolga &&
              folgaEm(primeira.add(Duration(minutes: antecedenciaMinutos))) != null;
          i++) {
        primeira = DateTime(primeira.year, primeira.month, primeira.day + 7,
            primeira.hour, primeira.minute);
      }

      resultado.add(
        _Agendamento(
          id: diaSemana * 100 + slot,
          titulo: '${item.nome} se aproximando',
          corpo: [
            'Começa às $horaDoSlot:00',
            if (item.local != null) item.local!,
          ].join(' · '),
          primeira: primeira,
        ),
      );
    }
  }
  return resultado;
}

/// Subtrai a antecedência do horário do slot, resolvendo a virada de dia
/// (ex: 0h de segunda menos 15 min vira domingo 23h45) via aritmética normal
/// de [DateTime] em vez de conta manual de módulo.
({int diaSemana, int hora, int minuto}) _comAntecedencia(
  int diaSemana,
  int horaDoSlot,
  int antecedenciaMinutos,
) {
  // 2026-01-05 é uma segunda-feira — só serve de âncora pro weekday bater.
  final base = DateTime(2026, 1, 4 + diaSemana, horaDoSlot);
  final comAviso = base.subtract(Duration(minutes: antecedenciaMinutos));
  return (
    diaSemana: comAviso.weekday,
    hora: comAviso.hour,
    minuto: comAviso.minute,
  );
}

/// Próxima data/hora (a partir de [agora]) em que [diaSemana] e o horário
/// batem — `zonedSchedule` exige uma âncora inicial mesmo pra um agendamento
/// recorrente (`matchDateTimeComponents`).
DateTime _proximaOcorrencia(int diaSemana, int hora, int minuto, DateTime agora) {
  var data = DateTime(agora.year, agora.month, agora.day, hora, minuto);
  while (data.weekday != diaSemana || data.isBefore(agora)) {
    data = DateTime(data.year, data.month, data.day + 1, hora, minuto);
  }
  return data;
}
