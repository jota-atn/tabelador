import 'package:flutter/foundation.dart';

import '../util/id.dart';

/// Todos os dias da semana, na ordem do calendário — índice bate com
/// `DateTime.weekday - 1` (segunda=0 .. domingo=6). Uma tabela usa um
/// subconjunto disso (ver [Tabela.dias]), sempre nesta mesma ordem.
const List<String> kTodosDias = [
  'SEGUNDA',
  'TERÇA',
  'QUARTA',
  'QUINTA',
  'SEXTA',
  'SÁBADO',
  'DOMINGO',
];

/// Abreviação de cada dia, pro cabeçalho de coluna da grade.
const Map<String, String> kDiaAbreviado = {
  'SEGUNDA': 'SEG',
  'TERÇA': 'TER',
  'QUARTA': 'QUA',
  'QUINTA': 'QUI',
  'SEXTA': 'SEX',
  'SÁBADO': 'SÁB',
  'DOMINGO': 'DOM',
};

/// Dias de uma tabela nova quando o usuário não escolhe nada — igual ao
/// script original. Dias por tabela são configuráveis (ver [Tabela.dias]),
/// mas a maioria continua sendo isso.
const List<String> kDiasPadrao = [
  'SEGUNDA',
  'TERÇA',
  'QUARTA',
  'QUINTA',
  'SEXTA',
];

/// Ordena um subconjunto de dias na ordem do calendário — pra quem marca as
/// colunas fora de ordem na tela de configuração continuar vendo segunda
/// antes de terça, não a ordem em que tocou.
List<String> ordenarDias(Iterable<String> dias) {
  final conjunto = dias.toSet();
  return [for (final d in kTodosDias) if (conjunto.contains(d)) d];
}

/// Uma tabela de horários — "2026.1", "Estágio", "Academia".
///
/// As células guardam o **id** de um [Item], ou null se o slot está vazio.
@immutable
class Tabela {
  Tabela({
    required this.id,
    required this.nome,
    this.horaInicial = 8,
    this.intervalo = 2,
    this.qtdHorarios = 6,
    List<String>? dias,
    Map<String, List<String?>>? celulas,
    required this.criadaEm,
    required this.atualizadaEm,
  })  : dias = ordenarDias(dias ?? kDiasPadrao),
        celulas = _normalizar(celulas, ordenarDias(dias ?? kDiasPadrao), qtdHorarios);

  factory Tabela.nova({
    required String nome,
    int horaInicial = 8,
    int intervalo = 2,
    int qtdHorarios = 6,
    List<String>? dias,
  }) {
    final agora = DateTime.now();
    return Tabela(
      id: gerarId(),
      nome: nome,
      horaInicial: horaInicial,
      intervalo: intervalo,
      qtdHorarios: qtdHorarios,
      dias: dias,
      criadaEm: agora,
      atualizadaEm: agora,
    );
  }

  final String id;
  final String nome;
  final int horaInicial;
  final int intervalo;
  final int qtdHorarios;

  /// Dias que esta tabela tem coluna — subconjunto de [kTodosDias], sempre
  /// na ordem do calendário independente da ordem em que foram escolhidos.
  /// Segunda–sexta por padrão, mas configurável (ver "Depois do roadmap
  /// original" na spec): uma tabela de academia pode ser só terça/quinta.
  final List<String> dias;

  /// Dia -> lista de tamanho [qtdHorarios]. Cada posição é o id de um Item ou
  /// null. Sempre completa: nunca falta um dia de [dias] nem sobra/falta
  /// posição.
  final Map<String, List<String?>> celulas;

  final DateTime criadaEm;
  final DateTime atualizadaEm;

  /// Garante a forma da grade venha de onde vier o dado: preenche dias
  /// ausentes, corta o que sobra e completa com null o que falta. Dia que
  /// não está mais em [dias] (tabela encolheu os dias) simplesmente não
  /// entra — é assim que mudar os dias também limpa célula órfã.
  static Map<String, List<String?>> _normalizar(
    Map<String, List<String?>>? origem,
    List<String> dias,
    int qtdHorarios,
  ) {
    return Map.unmodifiable({
      for (final dia in dias)
        dia: List<String?>.unmodifiable(
          List<String?>.generate(
            qtdHorarios,
            (i) {
              final lista = origem?[dia];
              return (lista != null && i < lista.length) ? lista[i] : null;
            },
          ),
        ),
    });
  }

  /// Os rótulos de horário, na mesma lógica do `gerar_horarios` do script.
  List<String> get horarios => [
        for (var i = 0; i < qtdHorarios; i++)
          '${horaInicial + i * intervalo}:00-${horaInicial + (i + 1) * intervalo}:00',
      ];

  String? celula(String dia, int slot) {
    final lista = celulas[dia];
    if (lista == null || slot < 0 || slot >= lista.length) return null;
    return lista[slot];
  }

  /// Quantas células apontam para [itemId] nesta tabela.
  int usosDe(String itemId) => celulas.values
      .expand((lista) => lista)
      .where((id) => id == itemId)
      .length;

  Tabela comCelula(String dia, int slot, String? itemId) {
    if (!dias.contains(dia) || slot < 0 || slot >= qtdHorarios) return this;

    final novas = {
      for (final d in dias) d: List<String?>.from(celulas[d]!),
    };
    novas[dia]![slot] = itemId;

    return copyWith(celulas: novas, atualizadaEm: DateTime.now());
  }

  /// Remove todas as referências a [itemId]. Usado quando um Item é apagado.
  Tabela semItem(String itemId) {
    if (usosDe(itemId) == 0) return this;

    final novas = {
      for (final d in dias)
        d: [for (final id in celulas[d]!) id == itemId ? null : id],
    };
    return copyWith(celulas: novas, atualizadaEm: DateTime.now());
  }

  /// Quantas células seriam perdidas se a tabela encolhesse para [nova].
  ///
  /// A tela pergunta isso **antes** de aplicar: truncar horário em silêncio
  /// apaga trabalho que o usuário não sabe que está apagando.
  int celulasPerdidasAo(int nova) {
    if (nova >= qtdHorarios) return 0;
    var perdidas = 0;
    for (final lista in celulas.values) {
      for (var i = nova; i < lista.length; i++) {
        if (lista[i] != null) perdidas++;
      }
    }
    return perdidas;
  }

  /// Quantas células seriam perdidas se os dias virassem [novosDias] — mesma
  /// ideia de [celulasPerdidasAo], só que pra tirar um dia da tabela em vez
  /// de encolher a quantidade de horários.
  int celulasPerdidasAoMudarDias(List<String> novosDias) {
    var perdidas = 0;
    for (final d in dias) {
      if (novosDias.contains(d)) continue;
      perdidas += celulas[d]!.where((id) => id != null).length;
    }
    return perdidas;
  }

  Tabela copyWith({
    String? nome,
    int? horaInicial,
    int? intervalo,
    int? qtdHorarios,
    List<String>? dias,
    Map<String, List<String?>>? celulas,
    DateTime? atualizadaEm,
  }) {
    return Tabela(
      id: id,
      nome: nome ?? this.nome,
      horaInicial: horaInicial ?? this.horaInicial,
      intervalo: intervalo ?? this.intervalo,
      qtdHorarios: qtdHorarios ?? this.qtdHorarios,
      dias: dias ?? this.dias,
      celulas: celulas ?? this.celulas,
      criadaEm: criadaEm,
      atualizadaEm: atualizadaEm ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'horaInicial': horaInicial,
        'intervalo': intervalo,
        'qtdHorarios': qtdHorarios,
        'dias': dias,
        'celulas': celulas,
        'criadaEm': criadaEm.toIso8601String(),
        'atualizadaEm': atualizadaEm.toIso8601String(),
      };

  factory Tabela.fromJson(Map<String, dynamic> json) {
    final brutas = json['celulas'] as Map<String, dynamic>? ?? const {};
    final agora = DateTime.now();

    return Tabela(
      id: json['id'] as String? ?? gerarId(),
      nome: json['nome'] as String? ?? 'Sem nome',
      horaInicial: json['horaInicial'] as int? ?? 8,
      intervalo: json['intervalo'] as int? ?? 2,
      qtdHorarios: json['qtdHorarios'] as int? ?? 6,
      // Ausente (dado de antes dos dias configuráveis) vira o padrão
      // segunda-sexta — tolerante com o que já estava salvo no disco.
      dias: (json['dias'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          kDiasPadrao,
      celulas: {
        for (final entrada in brutas.entries)
          entrada.key: [
            for (final id in (entrada.value as List<dynamic>? ?? const []))
              id as String?,
          ],
      },
      criadaEm: DateTime.tryParse(json['criadaEm'] as String? ?? '') ?? agora,
      atualizadaEm:
          DateTime.tryParse(json['atualizadaEm'] as String? ?? '') ?? agora,
    );
  }

  @override
  String toString() => 'Tabela($id, $nome)';
}
