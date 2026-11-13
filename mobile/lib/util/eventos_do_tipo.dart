import '../model/evento.dart';

/// Um grupo da linha do tempo: "Esta semana", "Próxima semana", "Dezembro"…
class GrupoDaLinha {
  const GrupoDaLinha(this.rotulo, this.ocorrencias);

  final String rotulo;
  final List<Ocorrencia> ocorrencias;
}

/// Uma série (evento que repete), com a próxima ocorrência.
///
/// Além do evento do app que repete, vira série o que **parece** uma: a
/// série do Google (mesmo evento lá) e eventos separados com mesmo nome,
/// dia da semana e horário (as reuniões do CAESI). Só pra mostrar: cada
/// ocorrência continua sendo a sua, com o próprio link.
class Serie {
  const Serie(this.evento, this.proxima, this.vezes, {this.padrao});

  final Evento evento;
  final Ocorrencia proxima;

  /// Quantas ocorrências na janela olhada (um ano).
  final int vezes;

  /// "Segundas, 19:00" — pra série que não vem de uma repetição do app
  /// (essa se descreve pela [Evento.repeticao]).
  final String? padrao;
}

const _kDiasNoPlural = ['Segundas', 'Terças', 'Quartas', 'Quintas', 'Sextas', 'Sábados', 'Domingos'];

String _hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Mesmo evento recorrente no Google: id externo é `g:<EVENT_ID>:<início>`.
String? _chaveDoGoogle(Evento e) {
  if (!e.externo || !e.id.startsWith('g:')) return null;
  final partes = e.id.split(':');
  return partes.length >= 3 ? 'g:${partes[1]}' : null;
}

/// Mesmo nome (sem diferenciar maiúscula nem espaço sobrando), dia da
/// semana e horário.
String _chaveParecida(Ocorrencia o) {
  final nome = o.evento.titulo.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final quando = o.evento.diaInteiro ? 'dia' : _hhmm(o.inicio);
  return 'p:$nome|${o.inicio.weekday}|$quando';
}

/// Descreve uma série sem repetição do app pelas datas que ela tem.
String _padraoDe(List<Ocorrencia> l) {
  final p = l.first;
  final hora = p.evento.diaInteiro ? '' : ', ${_hhmm(p.inicio)}';
  if (l.every((o) => o.inicio.weekday == p.inicio.weekday)) {
    return '${_kDiasNoPlural[p.inicio.weekday - 1]}$hora';
  }
  if (l.every((o) => o.inicio.day == p.inicio.day)) return 'Todo dia ${p.inicio.day}$hora';
  return 'Se repete';
}

/// A página de um tipo organizada.
class PaginaDoTipo {
  const PaginaDoTipo({
    required this.proxima,
    required this.series,
    required this.grupos,
    required this.passadas,
    required this.total,
  });

  /// O destaque do topo: a próxima que ainda não passou.
  final Ocorrencia? proxima;
  final List<Serie> series;
  final List<GrupoDaLinha> grupos;

  /// Dos últimos 30 dias, mais recente primeiro, sem repetição.
  final List<Ocorrencia> passadas;

  /// Quantas ocorrências pela frente (contando cada repetição).
  final int total;
}

const _kMeses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

String nomeDoMes(DateTime m, DateTime agora) =>
    m.year == agora.year ? _kMeses[m.month - 1] : '${_kMeses[m.month - 1]} de ${m.year}';

bool _naoPassou(Ocorrencia o, DateTime agora) {
  if (o.evento.diaInteiro) {
    return !DateTime(o.inicio.year, o.inicio.month, o.inicio.day)
        .isBefore(DateTime(agora.year, agora.month, agora.day));
  }
  return o.fim.isAfter(o.inicio) ? o.fim.isAfter(agora) : !o.inicio.isBefore(agora);
}

/// Organiza as [ocorrencias] de um tipo (já filtradas, de 30 dias atrás até
/// um ano à frente, em ordem):
///
/// - a **próxima** vai pro destaque e sai da linha do tempo;
/// - quem repete vira uma **série** (uma linha só, em vez de 53) e na linha
///   do tempo só aparece **nesta semana** — pra semana ficar completa;
/// - o resto: "Esta semana", "Próxima semana", depois por mês.
PaginaDoTipo organizarPaginaDoTipo(List<Ocorrencia> ocorrencias, DateTime agora) {
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final fimDaSemana = DateTime(hoje.year, hoje.month, hoje.day + (8 - hoje.weekday));
  final fimDaProxima = fimDaSemana.add(const Duration(days: 7));

  final futuras = [
    for (final o in ocorrencias)
      if (!o.feita && _naoPassou(o, agora)) o,
  ];
  final passadas = [
    for (final o in ocorrencias.reversed)
      if (!_naoPassou(o, agora) && o.evento.repeticao == Repeticao.nenhuma) o,
  ];

  final proxima = futuras.isEmpty ? null : futuras.first;

  // 1) Repetição do app: sempre série.
  final doApp = <String, List<Ocorrencia>>{};
  // 2) Série do Google; 3) parecidas — só com 2 ou mais.
  final doGoogle = <String, List<Ocorrencia>>{};
  for (final o in futuras) {
    if (o.evento.repeticao != Repeticao.nenhuma) {
      (doApp[o.evento.id] ??= []).add(o);
    } else if (_chaveDoGoogle(o.evento) case final chave?) {
      (doGoogle[chave] ??= []).add(o);
    }
  }
  final agrupadas = <Ocorrencia>{
    for (final l in doApp.values) ...l,
    for (final l in doGoogle.values)
      if (l.length > 1) ...l,
  };
  final parecidas = <String, List<Ocorrencia>>{};
  for (final o in futuras) {
    if (!agrupadas.contains(o)) (parecidas[_chaveParecida(o)] ??= []).add(o);
  }
  final series = [
    for (final l in doApp.values) Serie(l.first.evento, l.first, l.length),
    for (final l in [...doGoogle.values, ...parecidas.values])
      if (l.length > 1) Serie(l.first.evento, l.first, l.length, padrao: _padraoDe(l)),
  ]..sort((a, b) => a.proxima.inicio.compareTo(b.proxima.inicio));
  final emSerie = <Ocorrencia>{
    ...agrupadas,
    for (final l in parecidas.values)
      if (l.length > 1) ...l,
  };

  final semana = <Ocorrencia>[];
  final proximaSemana = <Ocorrencia>[];
  final porMes = <DateTime, List<Ocorrencia>>{};
  for (final o in futuras) {
    if (identical(o, proxima)) continue;
    final repete = emSerie.contains(o);
    if (o.inicio.isBefore(fimDaSemana)) {
      semana.add(o);
    } else if (repete) {
      continue;
    } else if (o.inicio.isBefore(fimDaProxima)) {
      proximaSemana.add(o);
    } else {
      (porMes[DateTime(o.inicio.year, o.inicio.month)] ??= []).add(o);
    }
  }

  return PaginaDoTipo(
    proxima: proxima,
    series: series,
    grupos: [
      if (semana.isNotEmpty) GrupoDaLinha('Esta semana', semana),
      if (proximaSemana.isNotEmpty) GrupoDaLinha('Próxima semana', proximaSemana),
      for (final m in porMes.entries) GrupoDaLinha(nomeDoMes(m.key, agora), m.value),
    ],
    passadas: passadas,
    total: futuras.length,
  );
}

/// "Hoje", "Amanhã", "em 5 dias", "em 3 meses" — pela data, não pela hora.
String contagemRegressiva(DateTime quando, DateTime agora) {
  final dias = DateTime(quando.year, quando.month, quando.day)
      .difference(DateTime(agora.year, agora.month, agora.day))
      .inDays;
  if (dias <= 0) return 'Hoje';
  if (dias == 1) return 'Amanhã';
  if (dias < 60) return 'em $dias dias';
  return 'em ${(dias / 30).round()} meses';
}
