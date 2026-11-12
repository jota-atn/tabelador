import 'package:flutter/foundation.dart';

import '../util/id.dart';

/// Como um [Evento] se repete. De propósito sem editor de RRULE: os quatro
/// casos cobrem prova (nenhuma), reunião (semanal), fatura (mensal) e
/// aniversário (anual).
enum Repeticao {
  nenhuma('nenhuma', 'Não repete'),
  diaria('diaria', 'Todo dia'),
  semanal('semanal', 'Toda semana'),
  mensal('mensal', 'Todo mês'),
  anual('anual', 'Todo ano');

  const Repeticao(this.key, this.rotulo);

  final String key;
  final String rotulo;

  static Repeticao fromKey(String? key) => Repeticao.values.firstWhere(
        (r) => r.key == key,
        orElse: () => Repeticao.nenhuma,
      );
}

/// Como a duração de um evento é escolhida na folha de criação. Não é
/// guardado — sai de [Evento.diaInteiro]/[Evento.fim] — mas é o que os tipos
/// definem como padrão.
enum DuracaoPadrao { diaTodo, prazo, umaHora, horarioDoItem }

/// Hora padrão do aviso de evento de dia inteiro (e de tarefa sem hora):
/// 7:00, cedo o bastante pra dar tempo de fazer no dia.
const int kAvisoDiaTodoPadrao = 7 * 60;

/// [Evento.agendaId] dos feriados embutidos (calculados pelo app, ver
/// `util/feriados.dart`). Contam como externos: só leitura, nunca
/// persistidos nem no backup.
const String kAgendaEmbutidos = 'tabelador:feriados';

/// Tipos fixos de evento. O valor real não é a categoria, é o padrão que
/// cada um preenche (duração, repetição) — tocar em "Aniversário" já deixa
/// dia todo e anual.
///
/// Tarefa abre com "sem hora" (dia todo): o que importa é o dia, e o aviso
/// sai de manhã ([Evento.avisoMin]).
enum TipoEvento {
  tarefa('Tarefa', DuracaoPadrao.diaTodo),
  prova('Prova', DuracaoPadrao.horarioDoItem),
  compromisso('Compromisso', DuracaoPadrao.umaHora),
  consulta('Consulta', DuracaoPadrao.umaHora),
  reuniao('Reunião', DuracaoPadrao.umaHora),
  viagem('Viagem', DuracaoPadrao.diaTodo),
  aniversario('Aniversário', DuracaoPadrao.diaTodo, repeticao: Repeticao.anual),
  feriado('Feriado', DuracaoPadrao.diaTodo),
  outro('Outro', DuracaoPadrao.umaHora);

  const TipoEvento(this.rotulo, this.duracao, {this.repeticao = Repeticao.nenhuma});

  final String rotulo;
  final DuracaoPadrao duracao;
  final Repeticao repeticao;

  /// [Evento.tipo] é texto (compatível com eventos de antes dos tipos
  /// fixos); o que não bate com nenhum rótulo conta como "Outro". Vazio é
  /// "sem tipo".
  static TipoEvento? doTexto(String texto) {
    final t = texto.trim().toLowerCase();
    if (t.isEmpty) return null;
    for (final tipo in TipoEvento.values) {
      if (tipo.rotulo.toLowerCase() == t) return tipo;
    }
    return TipoEvento.outro;
  }
}

/// Um momento com data — ao contrário do [Item], que é um molde sem data
/// ocupando um slot da semana. "Prova de SO" (vinculada ao item SO) e
/// "Aniversário de Pedro" (solto) são eventos.
///
/// [inicio] guarda data e hora locais; em evento de [diaInteiro] a hora é
/// ignorada (fica meia-noite). [fim] nulo em evento com hora significa "só o
/// horário de início" — o app mostra como um ponto no tempo, não uma faixa.
@immutable
class Evento {
  const Evento({
    required this.id,
    required this.titulo,
    required this.inicio,
    this.fim,
    this.diaInteiro = false,
    this.tipo = '',
    this.repeticao = Repeticao.nenhuma,
    this.itemId,
    this.local,
    this.notas,
    this.agendaId,
    this.corExterna,
    this.idNoAparelho,
    this.agendaDestinoId,
    this.semData = false,
    this.feito = false,
    this.feitas = const {},
    this.avisoMin,
    this.comemorativa = false,
  });

  Evento.novo({
    required this.titulo,
    required this.inicio,
    this.fim,
    this.diaInteiro = false,
    this.tipo = '',
    this.repeticao = Repeticao.nenhuma,
    this.itemId,
    this.local,
    this.notas,
    this.semData = false,
    this.avisoMin,
    this.comemorativa = false,
  })  : id = gerarId(),
        feito = false,
        feitas = const {},
        agendaId = null,
        corExterna = null,
        idNoAparelho = null,
        agendaDestinoId = null;

  final String id;
  final String titulo;
  final DateTime inicio;
  final DateTime? fim;
  final bool diaInteiro;

  /// Texto livre como [Item.tipo] — "Prova", "Entrega", "Compromisso".
  final String tipo;
  final Repeticao repeticao;

  /// Item a que o evento se refere, se algum. Apagar o item solta o evento
  /// (vira avulso) em vez de apagá-lo — a prova continua existindo.
  final String? itemId;
  final String? local;
  final String? notas;

  /// Agenda do aparelho de onde o evento veio (Google Agenda). Nulo =
  /// criado no app. Evento externo é só leitura por enquanto, não é
  /// persistido (relido do Android a cada abertura) nem vai pro backup.
  final String? agendaId;

  /// Cor da agenda de origem (ARGB), pra marcar evento externo sem item.
  final int? corExterna;

  /// Id do evento na agenda do Android. Em evento do app gravado no Google
  /// é o espelho dele lá; em evento externo é o próprio evento lido. É o
  /// que deixa o app reconhecer, na leitura, o que ele mesmo gravou — e não
  /// mostrar a mesma prova duas vezes.
  final String? idNoAparelho;

  /// Agenda do aparelho onde este evento do app foi gravado ("salvar também
  /// em"). Nulo = só no app.
  final String? agendaDestinoId;

  /// Tarefa sem data: só lembrar que precisa ser feita. [inicio] fica com
  /// a data de criação e é ignorado — não gera ocorrência, não vai pra
  /// grade, calendário, aviso nem Google.
  final bool semData;

  /// Concluída — vale pra evento que não repete (com ou sem data).
  final bool feito;

  /// Dias (meia-noite) das ocorrências concluídas de uma tarefa que repete:
  /// concluir marca só a ocorrência, não a série.
  final Set<DateTime> feitas;

  /// Hora do aviso de evento de dia inteiro, em minutos desde a meia-noite.
  /// Nulo = padrão ([kAvisoDiaTodoPadrao]).
  final int? avisoMin;

  /// Feriado que é só data comemorativa (não é folga): aparece, mas não
  /// esmaece as aulas nem conta em "N feriados até o fim do ano". Falso =
  /// folga, que é o caso de quem cria um feriado à mão.
  final bool comemorativa;

  bool get externo => agendaId != null;
  bool get embutido => agendaId == kAgendaEmbutidos;
  bool get ehFeriado => TipoEvento.doTexto(tipo) == TipoEvento.feriado;
  bool get ehTarefa => TipoEvento.doTexto(tipo) == TipoEvento.tarefa;

  /// A ocorrência que começa em [inicioDaOcorrencia] está concluída?
  bool feitaEm(DateTime inicioDaOcorrencia) => repeticao == Repeticao.nenhuma
      ? feito
      : feitas.contains(_dia(inicioDaOcorrencia));

  /// Marca (ou desmarca) a ocorrência de [inicioDaOcorrencia] — em evento
  /// que não repete, o evento todo.
  Evento marcandoFeita(DateTime inicioDaOcorrencia, bool valor) {
    if (repeticao == Repeticao.nenhuma) return _copiar(feito: valor);
    final dia = _dia(inicioDaOcorrencia);
    return _copiar(feitas: valor ? {...feitas, dia} : ({...feitas}..remove(dia)));
  }

  static DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);
  bool get gravadoNoGoogle => !externo && idNoAparelho != null;

  Duration get duracao =>
      fim == null || !fim!.isAfter(inicio) ? Duration.zero : fim!.difference(inicio);

  /// Ocorrências que **começam** em `[de, ate)`, em ordem. Evento que começou
  /// antes de [de] e ainda não acabou não entra — pra lista "Próximos" e pra
  /// grade da semana isso é o que importa (o que vai acontecer).
  ///
  /// Mensal num dia 31 pula mês sem dia 31; anual em 29/02 pula ano não
  /// bissexto — mesmo comportamento do Google Agenda, em vez de escorregar
  /// pro dia seguinte.
  List<Ocorrencia> ocorrenciasEntre(DateTime de, DateTime ate) {
    final resultado = <Ocorrencia>[];
    if (semData) return resultado;
    void considerar(DateTime comeco) {
      if (!comeco.isBefore(de) && comeco.isBefore(ate)) {
        resultado.add(Ocorrencia(this, comeco, comeco.add(duracao)));
      }
    }

    switch (repeticao) {
      case Repeticao.nenhuma:
        considerar(inicio);
      case Repeticao.diaria:
        var n = de.isAfter(inicio) ? de.difference(inicio).inDays - 1 : 0;
        if (n < 0) n = 0;
        while (true) {
          final c = _somarDias(inicio, n);
          if (!c.isBefore(ate)) break;
          considerar(c);
          n++;
        }
      case Repeticao.semanal:
        // Pula direto pra primeira semana relevante em vez de iterar desde
        // o início da série (um evento de 2020 não deveria custar 300 voltas).
        var n = 0;
        if (de.isAfter(inicio)) {
          n = de.difference(inicio).inDays ~/ 7;
          if (n > 0) n -= 1;
        }
        while (true) {
          final c = _somarDias(inicio, n * 7);
          if (!c.isBefore(ate)) break;
          considerar(c);
          n++;
        }
      case Repeticao.mensal:
        var n = de.isAfter(inicio)
            ? (de.year - inicio.year) * 12 + de.month - inicio.month - 1
            : 0;
        if (n < 0) n = 0;
        while (true) {
          final mesBruto = inicio.month - 1 + n;
          final ano = inicio.year + mesBruto ~/ 12;
          final mes = mesBruto % 12 + 1;
          final primeiroDoMes = DateTime(ano, mes);
          if (!primeiroDoMes.isBefore(ate)) break;
          final c = _naData(ano, mes, inicio.day);
          if (c != null) considerar(c);
          n++;
        }
      case Repeticao.anual:
        var ano = inicio.year;
        if (de.year - 1 > ano) ano = de.year - 1;
        while (DateTime(ano).isBefore(ate)) {
          final c = _naData(ano, inicio.month, inicio.day);
          if (c != null) considerar(c);
          ano++;
        }
    }
    return resultado;
  }

  /// Soma dias pelo calendário (não por 24h), pra mudança de horário de verão
  /// não deslocar a hora do evento.
  DateTime _somarDias(DateTime base, int dias) => DateTime(
        base.year,
        base.month,
        base.day + dias,
        base.hour,
        base.minute,
      );

  /// A data pedida com a hora de [inicio], ou null se ela não existe (31/04).
  DateTime? _naData(int ano, int mes, int dia) {
    final d = DateTime(ano, mes, dia, inicio.hour, inicio.minute);
    return d.month == mes ? d : null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'inicio': inicio.toIso8601String(),
        if (fim != null) 'fim': fim!.toIso8601String(),
        if (diaInteiro) 'diaInteiro': true,
        if (tipo.isNotEmpty) 'tipo': tipo,
        if (repeticao != Repeticao.nenhuma) 'repeticao': repeticao.key,
        if (itemId != null) 'itemId': itemId,
        if (local != null) 'local': local,
        if (notas != null) 'notas': notas,
        if (idNoAparelho != null) 'idNoAparelho': idNoAparelho,
        if (agendaDestinoId != null) 'agendaDestinoId': agendaDestinoId,
        if (semData) 'semData': true,
        if (feito) 'feito': true,
        if (feitas.isNotEmpty)
          'feitas': [for (final d in feitas.toList()..sort()) _diaIso(d)],
        if (avisoMin != null) 'avisoMin': avisoMin,
        if (comemorativa) 'comemorativa': true,
      };

  static String _diaIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Tolerante como [Item.fromJson]. Sem data de início válida não há o que
  /// mostrar, então cai em "agora" em vez de derrubar o carregamento inteiro.
  factory Evento.fromJson(Map<String, dynamic> json) {
    return Evento(
      id: json['id'] as String? ?? gerarId(),
      titulo: json['titulo'] as String? ?? '',
      inicio: DateTime.tryParse(json['inicio'] as String? ?? '') ?? DateTime.now(),
      fim: DateTime.tryParse(json['fim'] as String? ?? ''),
      diaInteiro: json['diaInteiro'] as bool? ?? false,
      tipo: json['tipo'] as String? ?? '',
      repeticao: Repeticao.fromKey(json['repeticao'] as String?),
      itemId: json['itemId'] as String?,
      local: json['local'] as String?,
      notas: json['notas'] as String?,
      idNoAparelho: json['idNoAparelho'] as String?,
      agendaDestinoId: json['agendaDestinoId'] as String?,
      semData: json['semData'] as bool? ?? false,
      feito: json['feito'] as bool? ?? false,
      feitas: {
        for (final d in (json['feitas'] as List<dynamic>? ?? const []))
          if (d is String && DateTime.tryParse(d) != null) _dia(DateTime.parse(d)),
      },
      avisoMin: (json['avisoMin'] as num?)?.toInt(),
      comemorativa: json['comemorativa'] as bool? ?? false,
    );
  }

  /// Mesmo evento apontando (ou deixando de apontar, com nulos) pra uma
  /// cópia na agenda do aparelho.
  Evento comEspelho(String? idNoAparelho, String? agendaDestinoId) => _copiar(
        idNoAparelho: () => idNoAparelho,
        agendaDestinoId: () => agendaDestinoId,
      );

  /// Mesmo evento com o vínculo removido — usado quando o item é apagado.
  Evento semItem() => _copiar(itemId: () => null);

  /// Cópia com campos trocados. Os anuláveis vêm embrulhados numa função
  /// pra dar pra trocar por null.
  Evento _copiar({
    String? tipo,
    bool? comemorativa,
    String? Function()? itemId,
    String? Function()? idNoAparelho,
    String? Function()? agendaDestinoId,
    bool? feito,
    Set<DateTime>? feitas,
  }) =>
      Evento(
        id: id,
        titulo: titulo,
        inicio: inicio,
        fim: fim,
        diaInteiro: diaInteiro,
        tipo: tipo ?? this.tipo,
        repeticao: repeticao,
        itemId: itemId == null ? this.itemId : itemId(),
        local: local,
        notas: notas,
        agendaId: agendaId,
        corExterna: corExterna,
        idNoAparelho: idNoAparelho == null ? this.idNoAparelho : idNoAparelho(),
        agendaDestinoId: agendaDestinoId == null ? this.agendaDestinoId : agendaDestinoId(),
        semData: semData,
        feito: feito ?? this.feito,
        feitas: feitas ?? this.feitas,
        avisoMin: avisoMin,
        comemorativa: comemorativa ?? this.comemorativa,
      );

  /// Evento externo com o tipo da agenda e o "feito" guardado no app.
  Evento decorado({required String tipo, required bool feito, bool comemorativa = false}) =>
      _copiar(tipo: tipo, feito: feito, comemorativa: comemorativa);

  /// Tipos que saíram da lista: "Entrega" vira Tarefa — e a que já passou
  /// conta como entregue, pra não chegar tudo como atrasada. Devolve o
  /// mesmo objeto quando não há o que mudar.
  Evento migrado(DateTime agora) {
    if (tipo.trim().toLowerCase() != 'entrega') return this;
    final passou = repeticao == Repeticao.nenhuma && inicio.isBefore(_dia(agora));
    return _copiar(tipo: TipoEvento.tarefa.rotulo, feito: feito || passou);
  }

  @override
  bool operator ==(Object other) =>
      other is Evento &&
      other.id == id &&
      other.titulo == titulo &&
      other.inicio == inicio &&
      other.fim == fim &&
      other.diaInteiro == diaInteiro &&
      other.tipo == tipo &&
      other.repeticao == repeticao &&
      other.itemId == itemId &&
      other.local == local &&
      other.notas == notas &&
      other.agendaId == agendaId &&
      other.corExterna == corExterna &&
      other.idNoAparelho == idNoAparelho &&
      other.agendaDestinoId == agendaDestinoId &&
      other.semData == semData &&
      other.feito == feito &&
      setEquals(other.feitas, feitas) &&
      other.avisoMin == avisoMin &&
      other.comemorativa == comemorativa;

  @override
  int get hashCode => Object.hash(
        id,
        titulo,
        inicio,
        fim,
        diaInteiro,
        tipo,
        repeticao,
        itemId,
        local,
        notas,
        agendaId,
        corExterna,
        idNoAparelho,
        agendaDestinoId,
        semData,
        feito,
        Object.hashAllUnordered(feitas),
        avisoMin,
        comemorativa,
      );

  @override
  String toString() => 'Evento($id, $titulo, $inicio)';
}

/// Uma ocorrência concreta de um [Evento] — pra recorrente, uma das datas da
/// série.
@immutable
class Ocorrencia {
  const Ocorrencia(this.evento, this.inicio, this.fim);

  final Evento evento;
  final DateTime inicio;
  final DateTime fim;

  bool get feita => evento.feitaEm(inicio);

  /// Tarefa sem data não tem ocorrência de verdade; esta é a "de mentira"
  /// que as listas e o card de detalhes usam pra mostrar ela.
  factory Ocorrencia.semData(Evento e) => Ocorrencia(e, e.inicio, e.inicio);
}
