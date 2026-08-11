import 'package:flutter/material.dart';

import 'item_palette.dart';

/// Quanta cor cada item carrega na tela. É preferência do usuário, não decisão
/// fechada: a mesma tabela pode ser lida como texto organizado ou como mosaico
/// colorido, dependendo de quem está olhando.
enum ColorDensity {
  /// Célula neutra com um fio de cor na lateral.
  discreto('discreto', 'Discreto', 'Cor só na aresta'),

  /// Célula preenchida no tom mais claro da rampa, com o fio por cima.
  suave('suave', 'Suave', 'Padrão'),

  /// Container cheio do Material 3, sem fio.
  solido('solido', 'Sólido', 'Cor cheia na célula');

  const ColorDensity(this.key, this.label, this.description);

  /// Identificador persistido. Ver nota em [ItemColor.key].
  final String key;
  final String label;
  final String description;

  static final Map<String, ColorDensity> _byKey = {
    for (final d in ColorDensity.values) d.key: d,
  };

  static const ColorDensity fallback = ColorDensity.suave;

  static ColorDensity fromKey(String? key) => _byKey[key] ?? fallback;
}

/// As cores já resolvidas de uma célula ocupada.
///
/// Deliberadamente burro: só valores prontos. Quem consome — grade, editor,
/// miniaturas, snapshot do widget — não precisa saber nada de HCT nem de
/// densidade.
@immutable
class CellStyle {
  const CellStyle({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.accentWidth,
  });

  final Color background;
  final Color foreground;

  /// Cor do fio lateral. Transparente quando [accentWidth] é zero.
  final Color accent;

  /// Largura do fio em dp. Zero significa "sem fio".
  final double accentWidth;

  bool get hasAccent => accentWidth > 0;

  @override
  bool operator ==(Object other) =>
      other is CellStyle &&
      other.background == background &&
      other.foreground == foreground &&
      other.accent == accent &&
      other.accentWidth == accentWidth;

  @override
  int get hashCode => Object.hash(background, foreground, accent, accentWidth);
}

/// O ponto de reuso do projeto: `(cor, densidade, tema) -> aparência da célula`.
///
/// A grade semanal, o editor do dia, as miniaturas da tela de Aparência e o
/// snapshot enviado ao widget nativo passam todos por aqui. Errar nessa função
/// propaga pras quatro superfícies; acertar resolve as quatro de uma vez.
CellStyle resolveCellStyle({
  required ItemColor cor,
  required ColorDensity densidade,
  required ColorScheme esquema,
}) {
  final escuro = esquema.brightness == Brightness.dark;

  // Tons 40/80 são os que o M3 usa como acento sobre superfície neutra;
  // 90/30 como container; 10/90 como texto sobre esse container.
  final filete = cor.tone(escuro ? 80 : 40);

  switch (densidade) {
    case ColorDensity.discreto:
      return CellStyle(
        background: esquema.surfaceContainer,
        foreground: esquema.onSurface,
        accent: filete,
        accentWidth: 3,
      );

    case ColorDensity.suave:
      return CellStyle(
        background: cor.tone(escuro ? 20 : 95),
        foreground: esquema.onSurface,
        accent: filete,
        accentWidth: 4,
      );

    case ColorDensity.solido:
      return CellStyle(
        background: cor.tone(escuro ? 30 : 90),
        foreground: cor.tone(escuro ? 90 : 10),
        accent: Colors.transparent,
        accentWidth: 0,
      );
  }
}
