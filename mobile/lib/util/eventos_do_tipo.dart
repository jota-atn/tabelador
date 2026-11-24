import '../model/evento.dart';

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

  /// Quantas ocorrências na janela olhada (o ano, ou o mês da lista).
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

/// A página de um tipo organizada (o topo; a lista é por mês, ver
/// [organizarMesDoTipo]).
class PaginaDoTipo {
  const PaginaDoTipo({
    required this.destaques,
    required this.series,
    required this.total,
  });

  /// O destaque do topo, que desliza: as próximas que ainda não passaram,
  /// uma por evento (a reunião semanal não ocupa os 4 lugares).
  final List<Ocorrencia> destaques;
  Ocorrencia? get proxima => destaques.firstOrNull;

  /// Séries no ano olhado (pro resumo do topo).
  final List<Serie> series;

  /// Quantas ocorrências pela frente (contando cada repetição).
  final int total;
}

/// Um mês da lista de baixo: cada série uma vez, com quantas vezes cai no
/// mês, e o resto avulso em ordem.
class MesDoTipo {
  const MesDoTipo({required this.series, required this.avulsas});

  final List<Serie> series;
  final List<Ocorrencia> avulsas;

  bool get vazio => series.isEmpty && avulsas.isEmpty;
}

/// Quantos cards o destaque desliza.
const kDestaquesDoTipo = 4;

const _kMeses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

String nomeDoMes(DateTime m, DateTime agora) =>
    m.year == agora.year ? _kMeses[m.month - 1] : '${_kMeses[m.month - 1]} de ${m.year}';

bool naoPassou(Ocorrencia o, DateTime agora) {
  if (o.evento.diaInteiro) {
    return !DateTime(o.inicio.year, o.inicio.month, o.inicio.day)
        .isBefore(DateTime(agora.year, agora.month, agora.day));
  }
  return o.fim.isAfter(o.inicio) ? o.fim.isAfter(agora) : !o.inicio.isBefore(agora);
}

/// A que série [o] pertenceria: o próprio evento (repetição do app), o
/// evento do Google, ou o "parecido" (nome, dia da semana, hora).
String _chaveDeSerie(Ocorrencia o) => o.evento.repeticao != Repeticao.nenhuma
    ? 'id:${o.evento.id}'
    : _chaveDoGoogle(o.evento) ?? _chaveParecida(o);

/// Agrupa [ocorrencias] (em ordem) em séries: repetição do app sempre (ou
/// só com 2+, se [appSempre] for falso — no mês, o aniversário anual é uma
/// linha comum); série do Google e parecidas só com 2 ou mais. Devolve as
/// séries e quem ficou dentro delas.
(List<Serie>, Set<Ocorrencia>) _agruparSeries(
  List<Ocorrencia> ocorrencias,
  DateTime agora, {
  bool appSempre = true,
}) {
  final grupos = <String, List<Ocorrencia>>{};
  for (final o in ocorrencias) {
    (grupos[_chaveDeSerie(o)] ??= []).add(o);
  }
  final series = <Serie>[];
  final emSerie = <Ocorrencia>{};
  for (final MapEntry(:key, value: l) in grupos.entries) {
    final doApp = key.startsWith('id:');
    if (!(doApp && appSempre) && l.length < 2) continue;
    final proxima = l.firstWhere((o) => naoPassou(o, agora), orElse: () => l.first);
    series.add(Serie(l.first.evento, proxima, l.length, padrao: doApp ? null : _padraoDe(l)));
    emSerie.addAll(l);
  }
  series.sort((a, b) => a.proxima.inicio.compareTo(b.proxima.inicio));
  return (series, emSerie);
}

/// Organiza o topo da página a partir das [ocorrencias] do tipo de hoje até
/// um ano à frente (em ordem).
PaginaDoTipo organizarPaginaDoTipo(List<Ocorrencia> ocorrencias, DateTime agora) {
  final futuras = [
    for (final o in ocorrencias)
      if (!o.feita && naoPassou(o, agora)) o,
  ];
  final vistos = <String>{};
  final destaques = <Ocorrencia>[];
  for (final o in futuras) {
    if (destaques.length == kDestaquesDoTipo) break;
    if (vistos.add(_chaveDeSerie(o))) destaques.add(o);
  }
  final (series, _) = _agruparSeries(futuras, agora);
  return PaginaDoTipo(destaques: destaques, series: series, total: futuras.length);
}

/// Organiza a lista de um mês: séries uma vez (com [Serie.vezes] = quantas
/// no mês), o resto avulso.
MesDoTipo organizarMesDoTipo(List<Ocorrencia> doMes, DateTime agora) {
  final (series, emSerie) = _agruparSeries(doMes, agora, appSempre: false);
  return MesDoTipo(
    series: series,
    avulsas: [for (final o in doMes) if (!emSerie.contains(o)) o],
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
