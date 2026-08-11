import 'package:flutter/foundation.dart';

import '../theme/item_palette.dart';
import '../util/id.dart';

/// O que ocupa uma célula da tabela: disciplina, monitoria, almoço, o que for.
///
/// No script Python original a célula era uma string digitada e a cor saía de
/// um dicionário fixo. Aqui o item é cadastrado uma vez e referenciado por id,
/// então renomear "Cálculo II" atualiza todas as tabelas de uma vez.
@immutable
class Item {
  const Item({
    required this.id,
    required this.nome,
    required this.sigla,
    required this.tipo,
    required this.cor,
    this.local,
    this.professor,
    this.notas,
  });

  Item.novo({
    required this.nome,
    required this.sigla,
    this.tipo = '',
    this.cor = ItemColor.grafite,
    this.local,
    this.professor,
    this.notas,
  }) : id = gerarId();

  final String id;

  /// Nome por extenso. Aparece na biblioteca e no editor do dia.
  final String nome;

  /// Forma curta. É o que cabe numa célula de ~55dp e no widget.
  final String sigla;

  /// Texto livre com autocomplete dos tipos já usados — "Aula", "Monitoria",
  /// "Pausa". Não é enum fechado justamente pra não voltar a hardcodar.
  final String tipo;

  final ItemColor cor;
  final String? local;
  final String? professor;
  final String? notas;

  Item copyWith({
    String? nome,
    String? sigla,
    String? tipo,
    ItemColor? cor,
    String? local,
    String? professor,
    String? notas,
  }) {
    return Item(
      id: id,
      nome: nome ?? this.nome,
      sigla: sigla ?? this.sigla,
      tipo: tipo ?? this.tipo,
      cor: cor ?? this.cor,
      local: local ?? this.local,
      professor: professor ?? this.professor,
      notas: notas ?? this.notas,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'sigla': sigla,
        'tipo': tipo,
        'cor': cor.key,
        if (local != null) 'local': local,
        if (professor != null) 'professor': professor,
        if (notas != null) 'notas': notas,
      };

  /// Tolerante de propósito: dado gravado por uma versão antiga não pode
  /// derrubar o app. Campo faltando vira vazio, cor desconhecida vira grafite.
  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String? ?? gerarId(),
      nome: json['nome'] as String? ?? '',
      sigla: json['sigla'] as String? ?? '',
      tipo: json['tipo'] as String? ?? '',
      cor: ItemColor.fromKey(json['cor'] as String?),
      local: json['local'] as String?,
      professor: json['professor'] as String?,
      notas: json['notas'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Item &&
      other.id == id &&
      other.nome == nome &&
      other.sigla == sigla &&
      other.tipo == tipo &&
      other.cor == cor &&
      other.local == local &&
      other.professor == professor &&
      other.notas == notas;

  @override
  int get hashCode =>
      Object.hash(id, nome, sigla, tipo, cor, local, professor, notas);

  @override
  String toString() => 'Item($id, $sigla)';
}
