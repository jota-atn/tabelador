import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../model/item.dart';
import '../model/tabela.dart';
import '../state/app_state.dart';

const AndroidNotificationChannel kCanalHorarios = AndroidNotificationChannel(
  'horarios_proximos',
  'Horários se aproximando',
  description: 'Avisa antes de cada horário preenchido da tabela ativa',
);

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
          );

    final assinatura = jsonEncode([
      for (final a in agendamentos)
        [a.id, a.titulo, a.corpo, a.diaSemana, a.hora, a.minuto],
    ]);
    if (assinatura == _ultimaAssinatura) return;
    _ultimaAssinatura = assinatura;

    await _plugin.cancelAll();
    for (final a in agendamentos) {
      await _plugin.zonedSchedule(
        a.id,
        a.titulo,
        a.corpo,
        _proximaOcorrencia(a.diaSemana, a.hora, a.minuto),
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
    required this.diaSemana,
    required this.hora,
    required this.minuto,
  });

  final int id;
  final String titulo;
  final String corpo;

  /// 1=segunda..7=domingo, igual `DateTime.weekday`.
  final int diaSemana;
  final int hora;
  final int minuto;
}

/// Um agendamento por célula preenchida da tabela — o próprio `id` (dia da
/// semana × 100 + slot) garante um por posição, sem colidir dentro da mesma
/// tabela. Como só a tabela ativa tem agendamento por vez (tudo é cancelado
/// antes de reagendar), não importa colidir com o id de outra tabela.
List<_Agendamento> _construirAgendamentos(
  Tabela tabela,
  int antecedenciaMinutos,
  Item? Function(String? id) itemPorId,
) {
  final resultado = <_Agendamento>[];
  for (final dia in tabela.dias) {
    final diaSemana = kTodosDias.indexOf(dia) + 1;
    for (var slot = 0; slot < tabela.qtdHorarios; slot++) {
      final item = itemPorId(tabela.celula(dia, slot));
      if (item == null) continue;

      final horaDoSlot = tabela.horaInicial + slot * tabela.intervalo;
      final aviso = _comAntecedencia(diaSemana, horaDoSlot, antecedenciaMinutos);

      resultado.add(
        _Agendamento(
          id: diaSemana * 100 + slot,
          titulo: '${item.nome} se aproximando',
          corpo: [
            'Começa às $horaDoSlot:00',
            if (item.local != null) item.local!,
          ].join(' · '),
          diaSemana: aviso.diaSemana,
          hora: aviso.hora,
          minuto: aviso.minuto,
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

/// Próxima data/hora (a partir de agora) em que [diaSemana] e o horário
/// batem — `zonedSchedule` exige uma âncora inicial mesmo pra um agendamento
/// recorrente (`matchDateTimeComponents`).
tz.TZDateTime _proximaOcorrencia(int diaSemana, int hora, int minuto) {
  final agora = tz.TZDateTime.now(tz.local);
  var data = tz.TZDateTime(tz.local, agora.year, agora.month, agora.day, hora, minuto);
  while (data.weekday != diaSemana || data.isBefore(agora)) {
    data = data.add(const Duration(days: 1));
  }
  return data;
}
