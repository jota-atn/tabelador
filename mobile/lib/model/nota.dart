import 'package:flutter/foundation.dart';

/// Nota tirada numa avaliação: [valor] de [maximo] — "7,5 de 10",
/// "18 de 20". Guardar o máximo é o que deixa a média da Disciplina (v2.1)
/// juntar provas de escalas diferentes.
@immutable
class Nota {
  const Nota(this.valor, this.maximo);

  final double valor;
  final double maximo;

  /// 0..1 — pra comparar e fazer média sem olhar a escala.
  double get fracao => maximo <= 0 ? 0 : valor / maximo;

  /// "7,5 de 10".
  String get texto => '${formatarNumero(valor)} de ${formatarNumero(maximo)}';

  /// "7,5/10" — pra caber numa linha de lista.
  String get curto => '${formatarNumero(valor)}/${formatarNumero(maximo)}';

  Map<String, dynamic> toJson() => {'v': valor, 'm': maximo};

  /// Null se faltar o valor ou o máximo for inválido.
  static Nota? fromJson(Object? json) {
    if (json is! Map) return null;
    final v = (json['v'] as num?)?.toDouble();
    final m = (json['m'] as num?)?.toDouble();
    if (v == null || m == null || m <= 0) return null;
    return Nota(v, m);
  }

  @override
  bool operator ==(Object other) => other is Nota && other.valor == valor && other.maximo == maximo;

  @override
  int get hashCode => Object.hash(valor, maximo);

  @override
  String toString() => 'Nota($texto)';
}

/// "7,5", "10", "8,25" — vírgula decimal, sem ",0" sobrando.
String formatarNumero(double n) {
  final arredondado = (n * 100).round() / 100;
  if (arredondado == arredondado.truncateToDouble()) return arredondado.toInt().toString();
  return arredondado.toString().replaceAll('.', ',');
}

/// Lê "7,5", "7.5" ou " 10 " — null se não for número.
double? lerNumero(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));
