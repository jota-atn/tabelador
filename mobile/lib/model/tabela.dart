import 'package:flutter/foundation.dart';

import '../util/id.dart';

/// Dias da grade, na ordem em que aparecem. Fixos em Segunda–Sexta, herdado do
/// script original — tornar configurável é possível, mas não está no escopo.
const List<String> kDias = [
  'SEGUNDA',
  'TERÇA',
  'QUARTA',
  'QUINTA',
  'SEXTA',
];

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
    Map<String, List<String?>>? celulas,
    required this.criadaEm,
    required this.atualizadaEm,
  }) : celulas = _normalizar(celulas, qtdHorarios);

  factory Tabela.nova({
    required String nome,
    int horaInicial = 8,
    int intervalo = 2,
    int qtdHorarios = 6,
  }) {
    final agora = DateTime.now();
    return Tabela(
      id: gerarId(),
      nome: nome,
      horaInicial: horaInicial,
      intervalo: intervalo,
      qtdHorarios: qtdHorarios,
      criadaEm: agora,
      atualizadaEm: agora,
    );
  }

  final String id;
  final String nome;
  final int horaInicial;
  final int intervalo;
  final int qtdHorarios;

  /// Dia -> lista de tamanho [qtdHorarios]. Cada posição é o id de um Item ou
  /// null. Sempre completa: nunca falta dia nem sobra/falta posição.
  final Map<String, List<String?>> celulas;

  final DateTime criadaEm;
  final DateTime atualizadaEm;

  /// Garante a forma da grade venha de onde vier o dado: preenche dias
  /// ausentes, corta o que sobra e completa com null o que falta.
  static Map<String, List<String?>> _normalizar(
    Map<String, List<String?>>? origem,
    int qtdHorarios,
  ) {
    return Map.unmodifiable({
      for (final dia in kDias)
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
    if (!kDias.contains(dia) || slot < 0 || slot >= qtdHorarios) return this;

    final novas = {
      for (final d in kDias) d: List<String?>.from(celulas[d]!),
    };
    novas[dia]![slot] = itemId;

    return copyWith(celulas: novas, atualizadaEm: DateTime.now());
  }

  /// Remove todas as referências a [itemId]. Usado quando um Item é apagado.
  Tabela semItem(String itemId) {
    if (usosDe(itemId) == 0) return this;

    final novas = {
      for (final d in kDias)
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

  Tabela copyWith({
    String? nome,
    int? horaInicial,
    int? intervalo,
    int? qtdHorarios,
    Map<String, List<String?>>? celulas,
    DateTime? atualizadaEm,
  }) {
    return Tabela(
      id: id,
      nome: nome ?? this.nome,
      horaInicial: horaInicial ?? this.horaInicial,
      intervalo: intervalo ?? this.intervalo,
      qtdHorarios: qtdHorarios ?? this.qtdHorarios,
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
