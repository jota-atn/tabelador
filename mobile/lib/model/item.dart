import 'package:flutter/foundation.dart';

import '../theme/item_palette.dart';
import '../util/id.dart';

/// O que ocupa uma célula da tabela: disciplina, treino, compromisso, o que
/// for — o app não presume que é sempre aula.
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
    this.notas,
    this.arquivado = false,
    this.tabelaId,
  });

  Item.novo({
    required this.nome,
    required this.sigla,
    this.tipo = '',
    this.cor = ItemColor.grafite,
    this.local,
    this.notas,
    this.arquivado = false,
    this.tabelaId,
  }) : id = gerarId();

  final String id;

  /// Nome por extenso. Aparece na biblioteca e no editor do dia.
  final String nome;

  /// Forma curta. É o que cabe numa célula de ~55dp e no widget.
  final String sigla;

  /// Texto livre com autocomplete dos tipos já usados — "Aula", "Treino",
  /// "Pausa". Não é enum fechado justamente pra não voltar a hardcodar.
  final String tipo;

  final ItemColor cor;
  final String? local;
  final String? notas;

  /// Some da paleta de arrastar (bandeja do editor do dia, seletor por
  /// toque), mas continua existindo pra qualquer tabela antiga que ainda o
  /// referencia renderizar nome e cor certos. Nunca apagar um item só porque
  /// o semestre acabou — apagar esvazia célula de tabela velha, arquivar não.
  final bool arquivado;

  /// Null significa compartilhado (a biblioteca inteira, como a spec sempre
  /// previu). Não-nulo prende o item à paleta de uma única tabela — pra
  /// disciplina de um semestre específico que o usuário já sabe, na hora de
  /// cadastrar, que não vai reaproveitar. Some junto se a tabela for apagada
  /// (ver `AppState.removerTabela`), ao contrário de arquivar.
  final String? tabelaId;

  Item copyWith({
    String? nome,
    String? sigla,
    String? tipo,
    ItemColor? cor,
    String? local,
    String? notas,
    bool? arquivado,
    String? tabelaId,
  }) {
    return Item(
      id: id,
      nome: nome ?? this.nome,
      sigla: sigla ?? this.sigla,
      tipo: tipo ?? this.tipo,
      cor: cor ?? this.cor,
      local: local ?? this.local,
      notas: notas ?? this.notas,
      arquivado: arquivado ?? this.arquivado,
      tabelaId: tabelaId ?? this.tabelaId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'sigla': sigla,
        'tipo': tipo,
        'cor': cor.key,
        if (local != null) 'local': local,
        if (notas != null) 'notas': notas,
        if (arquivado) 'arquivado': arquivado,
        if (tabelaId != null) 'tabelaId': tabelaId,
      };

  /// Tolerante de propósito: dado gravado por uma versão antiga não pode
  /// derrubar o app. Campo faltando vira vazio, cor desconhecida vira
  /// grafite, arquivado ausente vira false, tabelaId ausente vira
  /// compartilhado. `professor` de uma versão anterior é ignorado — o campo
  /// foi removido por ser específico demais de aula; quem tinha preenchido
  /// isso ainda vê o texto em `notas`, se também tiver preenchido.
  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String? ?? gerarId(),
      nome: json['nome'] as String? ?? '',
      sigla: json['sigla'] as String? ?? '',
      tipo: json['tipo'] as String? ?? '',
      cor: ItemColor.fromKey(json['cor'] as String?),
      local: json['local'] as String?,
      notas: json['notas'] as String?,
      arquivado: json['arquivado'] as bool? ?? false,
      tabelaId: json['tabelaId'] as String?,
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
      other.notas == notas &&
      other.arquivado == arquivado &&
      other.tabelaId == tabelaId;

  @override
  int get hashCode => Object.hash(
        id,
        nome,
        sigla,
        tipo,
        cor,
        local,
        notas,
        arquivado,
        tabelaId,
      );

  @override
  String toString() => 'Item($id, $sigla)';
}
