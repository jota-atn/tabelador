import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Paleta curada de cores que um Item pode assumir.
///
/// Cada chave guarda uma semente em HCT (matiz + croma), não valores hex por
/// tema. A rampa tonal é gerada pelo `material_color_utilities`, o mesmo motor
/// que o Material 3 usa — assim os pares de contraste já vêm garantidos e o
/// usuário nunca consegue escolher uma combinação ilegível.
///
/// Os espaçamentos de matiz são irregulares de propósito. Grau de matiz em HCT
/// não é distância percebida: a faixa amarelo-verde comprime muito, e a
/// verde-ciano-azul comprime ainda mais no tom 40, onde tudo tende ao escuro.
/// Os valores aqui saíram de medir a distância entre todos os pares e afastar
/// os piores — ver o teste `nenhum par de cores fica próximo demais`, que
/// segura o resultado contra regressão.
enum ItemColor {
  tomate('tomate', 'Vermelho', 25),
  tangerina('tangerina', 'Laranja', 58),
  ambar('ambar', 'Amarelo', 92),
  oliva('oliva', 'Verde-oliva', 122),
  // Croma reduzido de propósito. Entre `ambar` (85) e `esmeralda` (165) o olho
  // separa matizes mal, e afastar só o matiz espremeria `oliva` contra `ambar`.
  // Dessaturar dá uma segunda pista além do matiz — e acerta o nome, já que
  // sálvia é um verde acinzentado, não um verde saturado.
  salvia('salvia', 'Verde acinzentado', 145, chroma: 30),
  esmeralda('esmeralda', 'Verde', 174),
  turquesa('turquesa', 'Ciano', 204),
  oceano('oceano', 'Azul', 240),
  indigo('indigo', 'Azul-violeta', 272),
  ametista('ametista', 'Roxo', 312),
  framboesa('framboesa', 'Rosa', 345),
  grafite('grafite', 'Neutro', 250, chroma: _neutralChroma);

  const ItemColor(this.key, this.label, this.hue, {this.chroma = _defaultChroma});

  /// Croma comum a todas as cromáticas, pra que pareçam uma família só em vez
  /// de um saco de cores avulsas.
  static const double _defaultChroma = 50;
  static const double _neutralChroma = 6;

  /// Identificador persistido no JSON. Nunca traduzir nem renomear: é o que
  /// liga um Item salvo à sua cor.
  final String key;

  /// Nome exibido ao usuário na hora de escolher a cor.
  final String label;

  final double hue;
  final double chroma;

  static final Map<String, ItemColor> _byKey = {
    for (final c in ItemColor.values) c.key: c,
  };

  /// Resolve uma chave vinda do disco. Cai em [grafite] se a chave for
  /// desconhecida — dado antigo ou corrompido não deve derrubar a tela.
  static ItemColor fromKey(String? key) => _byKey[key] ?? ItemColor.grafite;

  static final Map<ItemColor, TonalPalette> _ramps = {};

  TonalPalette get _ramp =>
      _ramps.putIfAbsent(this, () => TonalPalette.of(hue, chroma));

  /// Um degrau da rampa tonal, de 0 (preto) a 100 (branco).
  Color tone(int tone) => Color(_ramp.get(tone));
}
