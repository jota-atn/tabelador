import '../model/evento.dart';
import '../model/tabela.dart';
import 'feriados.dart';
import 'formato_data.dart';

/// Se [evento] aparece em [tabela] (grade e widget): sempre quando é de um
/// item que a tabela usa; avulso só com [Tabela.mostrarEventos] ligado.
bool eventoVisivelNaTabela(Tabela tabela, Evento evento) {
  if (tabela.mostrarEventos) return true;
  final itemId = evento.itemId;
  return itemId != null && tabela.usosDe(itemId) > 0;
}

/// [e] é um feriado que dá folga em [tabela] (sem tabela: só a folga de
/// lei)? Embutido segue a natureza dele (ponto facultativo, a escolha da
/// tabela); criado à mão, folga a não ser que seja comemorativa. O do
/// Google chega comemorativo (a agenda dele mistura Dia dos Namorados com
/// feriado de verdade) até a pessoa marcar como folga.
bool ehFolga(Evento e, Tabela? tabela) {
  if (!e.ehFeriado) return false;
  if (e.embutido) return feriadoEmbutidoDe(e)?.ehFolgaPara(tabela) ?? false;
  if (e.comemorativa) return false;
  return tabela == null || eventoVisivelNaTabela(tabela, e);
}

/// Viagem marcada "Sem aula" ([Evento.comemorativa] falso, ver
/// [Evento.mantemAulas]): apaga as aulas de toda tabela nos dias dela.
bool ehViagemSemAula(Evento e) =>
    TipoEvento.doTexto(e.tipo) == TipoEvento.viagem && !e.mantemAulas;

/// O nome do feriado (ou viagem) que tira as aulas de [tabela] no dia de
/// [quando], ou null. [ocorrencias] são as do período (com os embutidos já
/// dentro, como sai de `AppState.ocorrenciasEntre`); o embutido também é
/// checado direto, pra quem chama sem eles.
String? folgaNoDia(DateTime quando, Tabela? tabela, Iterable<Ocorrencia> ocorrencias) {
  final embutido = folgaEmbutida(quando, tabela);
  if (embutido != null) return embutido.nome;
  for (final o in ocorrencias) {
    if (o.cobre(quando) && (ehFolga(o.evento, tabela) || ehViagemSemAula(o.evento))) {
      return o.evento.titulo;
    }
  }
  return null;
}

/// Segunda-feira (meia-noite) da semana de [d].
DateTime segundaDaSemana(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Data de uma coluna da grade: a [segunda] da semana mostrada mais o
/// deslocamento do dia (`kTodosDias` é segunda-primeiro, igual a weekday-1).
DateTime dataDaColuna(DateTime segunda, String dia) =>
    DateTime(segunda.year, segunda.month, segunda.day + kTodosDias.indexOf(dia));

/// Onde cada evento de uma semana cai na grade de uma tabela — calculado
/// uma vez, fora do widget, pra ser testável sem montar UI.
///
/// Os quatro destinos da spec: célula (dentro do horário), faixa "dia todo"
/// em cima, faixa "fora do horário" embaixo, e nenhum (dia que a tabela não
/// tem — esse só aparece na lista "Próximos").
class EventosDaSemana {
  EventosDaSemana._(this.segunda, this._celulas, this._diaTodo, this._fora,
      [this._folgas = const {}]);

  static final EventosDaSemana vazio =
      EventosDaSemana._(DateTime(2000), const {}, const {}, const {});

  /// Dia -> nome do feriado que dá folga nele (aulas esmaecidas).
  final Map<String, String> _folgas;
  String? folga(String dia) => _folgas[dia];

  final DateTime segunda;
  final Map<String, List<Ocorrencia>> _celulas;
  final Map<String, List<Ocorrencia>> _diaTodo;
  final Map<String, List<Ocorrencia>> _fora;

  List<Ocorrencia> naCelula(String dia, int slot) =>
      _celulas['$dia/$slot'] ?? const [];
  List<Ocorrencia> diaTodo(String dia) => _diaTodo[dia] ?? const [];
  List<Ocorrencia> foraDoHorario(String dia) => _fora[dia] ?? const [];

  bool get temDiaTodo => _diaTodo.isNotEmpty;
  bool get temForaDoHorario => _fora.isNotEmpty;

  DateTime dataDe(String dia) => dataDaColuna(segunda, dia);
}

/// Distribui [ocorrencias] (já filtradas pra semana que começa em
/// [segunda]) pela grade de [tabela].
///
/// Evento com faixa ocupa todo slot que ela sobrepõe — uma prova de 10h às
/// 13h numa tabela de blocos de 2h marca 10-12 e 12-14. Evento pontual (sem
/// término) marca só o slot que contém o início. Com
/// [Tabela.mostrarEventos] desligado, só passa evento vinculado a um item
/// que esta tabela usa.
EventosDaSemana distribuirEventos({
  required Tabela tabela,
  required DateTime segunda,
  required Iterable<Ocorrencia> ocorrencias,
}) {
  final celulas = <String, List<Ocorrencia>>{};
  final diaTodo = <String, List<Ocorrencia>>{};
  final fora = <String, List<Ocorrencia>>{};

  for (final o in ocorrencias) {
    if (!eventoVisivelNaTabela(tabela, o.evento)) continue;

    // Dia todo vai pra faixa de cada dia que ocupa nesta semana — a
    // viagem de ter a sex aparece nos quatro.
    if (o.evento.diaInteiro) {
      for (final dia in tabela.dias) {
        if (o.cobre(dataDaColuna(segunda, dia))) (diaTodo[dia] ??= []).add(o);
      }
      continue;
    }

    final dia = kTodosDias[o.inicio.weekday - 1];
    if (!tabela.dias.contains(dia)) continue;
    // Fora da semana mostrada (o chamador deveria ter filtrado, mas uma
    // ocorrência de outra semana no mesmo dia da semana iria pra coluna
    // errada sem esta checagem).
    if (inicioDoDia(o.inicio) != dataDaColuna(segunda, dia)) continue;

    final minIni = o.inicio.hour * 60 + o.inicio.minute;
    final pontual = !o.fim.isAfter(o.inicio);
    // Faixa que atravessa a meia-noite fica cortada no fim do dia.
    final minFim = pontual
        ? minIni
        : (inicioDoDia(o.fim) == inicioDoDia(o.inicio)
            ? o.fim.hour * 60 + o.fim.minute
            : 24 * 60);

    var caiuEmAlgum = false;
    for (var slot = 0; slot < tabela.qtdHorarios; slot++) {
      final comeco = (tabela.horaInicial + slot * tabela.intervalo) * 60;
      final fim = comeco + tabela.intervalo * 60;
      final sobrepoe = pontual
          ? minIni >= comeco && minIni < fim
          : minIni < fim && minFim > comeco;
      if (sobrepoe) {
        (celulas['$dia/$slot'] ??= []).add(o);
        caiuEmAlgum = true;
      }
    }
    if (!caiuEmAlgum) (fora[dia] ??= []).add(o);
  }

  final folgas = <String, String>{
    for (final dia in tabela.dias)
      dia: ?folgaNoDia(dataDaColuna(segunda, dia), tabela, ocorrencias),
  };

  return EventosDaSemana._(segunda, celulas, diaTodo, fora, folgas);
}

/// Próximo horário (a partir de [agora]) em que [itemId] ocupa uma célula de
/// [tabela], com início e fim do slot — o atalho "próximo horário de SO" do
/// formulário de evento. Null se o item não está na tabela.
({DateTime inicio, DateTime fim})? proximoHorarioDoItem(
  Tabela tabela,
  String itemId,
  DateTime agora,
) {
  final hoje = DateTime(agora.year, agora.month, agora.day);
  // 8 dias: hoje (horários que ainda não começaram) até o mesmo dia da
  // semana que vem.
  for (var d = 0; d <= 7; d++) {
    final data = DateTime(hoje.year, hoje.month, hoje.day + d);
    final dia = kTodosDias[data.weekday - 1];
    if (!tabela.dias.contains(dia)) continue;
    for (var slot = 0; slot < tabela.qtdHorarios; slot++) {
      if (tabela.celula(dia, slot) != itemId) continue;
      final hora = tabela.horaInicial + slot * tabela.intervalo;
      final inicio = DateTime(data.year, data.month, data.day, hora);
      if (!inicio.isAfter(agora)) continue;
      return (
        inicio: inicio,
        fim: DateTime(data.year, data.month, data.day, hora + tabela.intervalo),
      );
    }
  }
  return null;
}
