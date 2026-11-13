import 'package:flutter/foundation.dart';

/// Presente de um aniversário (uma ocorrência — cada ano tem o seu): a
/// ideia e se já foi comprado.
@immutable
class Presente {
  const Presente(this.ideia, {this.comprado = false});

  final String ideia;
  final bool comprado;

  Presente comComprado(bool valor) => Presente(ideia, comprado: valor);

  Map<String, dynamic> toJson() => {'i': ideia, if (comprado) 'c': true};

  /// Null se faltar a ideia.
  static Presente? fromJson(Object? json) {
    if (json is! Map) return null;
    final ideia = json['i'];
    if (ideia is! String || ideia.trim().isEmpty) return null;
    return Presente(ideia, comprado: json['c'] == true);
  }

  @override
  bool operator ==(Object other) => other is Presente && other.ideia == ideia && other.comprado == comprado;

  @override
  int get hashCode => Object.hash(ideia, comprado);

  @override
  String toString() => 'Presente($ideia${comprado ? ', comprado' : ''})';
}
