import 'package:flutter/material.dart';

/// Semente usada quando o aparelho não expõe cores dinâmicas — Android abaixo
/// do 12, ou fabricante que não implementou o Monet.
const Color _fallbackSeed = Color(0xFF3C5F92);

/// Monta o tema a partir do esquema dinâmico do sistema, caindo na semente
/// quando ele não existe.
///
/// O chrome é deliberadamente neutro: barra, fundos, cards e navegação saem da
/// rampa neutra, e o acento dinâmico fica restrito a elementos interativos.
/// O croma da tela pertence aos itens da tabela — é o que os identifica.
ThemeData buildAppTheme(ColorScheme? dynamicScheme, Brightness brightness) {
  final scheme = dynamicScheme?.brightness == brightness
      ? dynamicScheme!
      : ColorScheme.fromSeed(seedColor: _fallbackSeed, brightness: brightness);

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
  );
}
