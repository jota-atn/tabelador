import 'package:flutter/foundation.dart';

import '../util/id.dart';

/// Como um [Evento] se repete. De propósito sem editor de RRULE: os quatro
/// casos cobrem prova (nenhuma), reunião (semanal), fatura (mensal) e
/// aniversário (anual).
enum Repeticao {
  nenhuma('nenhuma', 'Não repete'),
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
  })  : id = gerarId(),
        agendaId = null,
        corExterna = null;

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

  bool get externo => agendaId != null;

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
    void considerar(DateTime comeco) {
      if (!comeco.isBefore(de) && comeco.isBefore(ate)) {
        resultado.add(Ocorrencia(this, comeco, comeco.add(duracao)));
      }
    }

    switch (repeticao) {
      case Repeticao.nenhuma:
        considerar(inicio);
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
      };

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
    );
  }

  /// Mesmo evento com o vínculo removido — usado quando o item é apagado.
  Evento semItem() => Evento(
        id: id,
        titulo: titulo,
        inicio: inicio,
        fim: fim,
        diaInteiro: diaInteiro,
        tipo: tipo,
        repeticao: repeticao,
        local: local,
        notas: notas,
      );

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
      other.corExterna == corExterna;

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
}
