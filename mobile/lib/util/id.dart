import 'dart:math';

final Random _random = Random();

/// Gera um id curto e ordenável por criação.
///
/// Não é UUID de propósito: a escala aqui é dezenas de itens num aparelho só,
/// sem sincronização entre dispositivos. Timestamp em base 36 garante ordem e
/// unicidade entre chamadas; o sufixo aleatório cobre criações no mesmo
/// milissegundo.
String gerarId() {
  final agora = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final sufixo = _random.nextInt(1679616).toRadixString(36).padLeft(4, '0');
  return '$agora$sufixo';
}
