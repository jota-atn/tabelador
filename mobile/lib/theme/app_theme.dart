import 'package:flutter/material.dart';

/// Semente usada quando o aparelho não expõe cores dinâmicas — Android abaixo
/// do 12, ou fabricante que não implementou o Monet.
const Color _fallbackSeed = Color(0xFF3C5F92);

/// Resolve o esquema de cor efetivo: o dinâmico do sistema quando existe e
/// bate com o brilho pedido, senão a semente fixa.
///
/// Reaproveitado fora do tema também: é o que alimenta o snapshot do widget
/// nativo com as mesmas cores (Monet incluso) que o app está mostrando.
ColorScheme resolveColorScheme(ColorScheme? dynamicScheme, Brightness brightness) {
  return dynamicScheme?.brightness == brightness
      ? dynamicScheme!
      : ColorScheme.fromSeed(seedColor: _fallbackSeed, brightness: brightness);
}

/// Monta o tema a partir do esquema dinâmico do sistema, caindo na semente
/// quando ele não existe.
///
/// O chrome é deliberadamente neutro: barra, fundos, cards e navegação saem da
/// rampa neutra, e o acento dinâmico fica restrito a elementos interativos.
/// O croma da tela pertence aos itens da tabela — é o que os identifica.
ThemeData buildAppTheme(ColorScheme? dynamicScheme, Brightness brightness) {
  final scheme = resolveColorScheme(dynamicScheme, brightness);

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
