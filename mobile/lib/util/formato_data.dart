import '../model/evento.dart';
import '../model/tabela.dart';

/// Formatação de data/hora à mão em vez de `intl`: o app só precisa de três
/// formatos curtos, sempre em português.

String _doisDigitos(int n) => n.toString().padLeft(2, '0');

/// "SEG", "TER"... do dia da semana de [d].
String diaAbreviado(DateTime d) => kDiaAbreviado[kTodosDias[d.weekday - 1]]!;

/// "13/11".
String diaMes(DateTime d) => '${_doisDigitos(d.day)}/${_doisDigitos(d.month)}';

/// "13/11/2026".
String dataCompleta(DateTime d) => '${diaMes(d)}/${d.year}';

/// "10:00".
String hora(DateTime d) => '${_doisDigitos(d.hour)}:${_doisDigitos(d.minute)}';

/// "Dia todo", "10:00" ou "10:00–11:30".
String faixaHorario(Ocorrencia o) {
  if (o.evento.diaInteiro) return 'Dia todo';
  if (!o.fim.isAfter(o.inicio)) return hora(o.inicio);
  return '${hora(o.inicio)}–${hora(o.fim)}';
}

/// Vários dias: "ter 17 – sex 20/11" (dia todo) ou "sex 13 18:00 – dom
/// 15/11 22:00" (com hora). Durante, "Em viagem · volta sex 20/11" (Viagem)
/// ou "Até sex 20/11" (os outros tipos).
String faixaDeDias(Ocorrencia o, DateTime agora) {
  final comHora = !o.evento.diaInteiro;
  final ultimo = o.ultimoDia;
  String dia(DateTime d) => '${diaAbreviado(d).toLowerCase()} ${diaMes(d)}';
  final hojeEhOUltimo = inicioDoDia(agora) == ultimo;
  final volta = '${hojeEhOUltimo ? 'hoje' : dia(ultimo)}${comHora ? ' ${hora(o.fim)}' : ''}';
  if (o.acontecendo(agora)) {
    if (TipoEvento.doTexto(o.evento.tipo) == TipoEvento.viagem) return 'Em viagem · volta $volta';
    return hojeEhOUltimo && !comHora ? 'Termina hoje' : 'Até $volta';
  }
  final i = o.inicio;
  final comeco = i.month == ultimo.month ? '${i.day}' : diaMes(i);
  return '${diaAbreviado(i).toLowerCase()} $comeco${comHora ? ' ${hora(i)}' : ''}'
      ' – ${dia(ultimo)}${comHora ? ' ${hora(o.fim)}' : ''}';
}

/// Meia-noite do dia de [d].
DateTime inicioDoDia(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Hoje", "Amanhã" ou "qui 13/11" — relativo a [agora].
String rotuloDoDia(DateTime d, DateTime agora) {
  final dias = inicioDoDia(d).difference(inicioDoDia(agora)).inDays;
  if (dias == 0) return 'Hoje';
  if (dias == 1) return 'Amanhã';
  return '${diaAbreviado(d).toLowerCase()} ${diaMes(d)}';
}

const _kMesesPorExtenso = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

/// A semana que começa em [segunda]: "16 – 22 de novembro", e quando
/// atravessa o mês "30 nov – 6 dez". Ano só se não for o de [agora].
String rotuloDaSemana(DateTime segunda, DateTime agora) {
  final domingo = DateTime(segunda.year, segunda.month, segunda.day + 6);
  String curto(DateTime d) => '${d.day} ${_kMesesPorExtenso[d.month - 1].substring(0, 3)}';
  final outroAno = segunda.year != agora.year || domingo.year != agora.year;
  if (segunda.month == domingo.month) {
    final base = '${segunda.day} – ${domingo.day} de ${_kMesesPorExtenso[domingo.month - 1]}';
    return outroAno ? '$base de ${domingo.year}' : base;
  }
  if (segunda.year != domingo.year) {
    return '${curto(segunda)} ${segunda.year} – ${curto(domingo)} ${domingo.year}';
  }
  final base = '${curto(segunda)} – ${curto(domingo)}';
  return outroAno ? '$base ${domingo.year}' : base;
}

/// "Esta semana", "Semana que vem", "Semana passada" ou "Semana de 23/11".
String tituloDaSemana(DateTime segunda, DateTime agora) {
  final atual = DateTime(agora.year, agora.month, agora.day - (agora.weekday - 1));
  final semanas = (DateTime.utc(segunda.year, segunda.month, segunda.day)
              .difference(DateTime.utc(atual.year, atual.month, atual.day))
              .inDays /
          7)
      .round();
  return switch (semanas) {
    0 => 'Esta semana',
    1 => 'Semana que vem',
    -1 => 'Semana passada',
    _ => 'Semana de ${diaMes(segunda)}',
  };
}
