import '../model/evento.dart';

/// Um grupo da linha do tempo: "Esta semana", "Próxima semana", "Dezembro"…
class GrupoDaLinha {
  const GrupoDaLinha(this.rotulo, this.ocorrencias);

  final String rotulo;
  final List<Ocorrencia> ocorrencias;
}

/// Uma série (evento que repete), com a próxima ocorrência.
class Serie {
  const Serie(this.evento, this.proxima, this.vezes);

  final Evento evento;
  final Ocorrencia proxima;

  /// Quantas ocorrências na janela olhada (um ano).
  final int vezes;
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

  final porSerie = <String, List<Ocorrencia>>{};
  for (final o in futuras) {
    if (o.evento.repeticao != Repeticao.nenhuma) (porSerie[o.evento.id] ??= []).add(o);
  }
  final series = [
    for (final l in porSerie.values) Serie(l.first.evento, l.first, l.length),
  ];

  final semana = <Ocorrencia>[];
  final proximaSemana = <Ocorrencia>[];
  final porMes = <DateTime, List<Ocorrencia>>{};
  for (final o in futuras) {
    if (identical(o, proxima)) continue;
    final repete = o.evento.repeticao != Repeticao.nenhuma;
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
