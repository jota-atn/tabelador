import 'package:flutter/material.dart';

/// Semente usada quando o aparelho não expõe cores dinâmicas — Android abaixo
/// do 12, ou fabricante que não implementou o Monet.
const Color _fallbackSeed = Color(0xFF3C5F92);

/// Cores do app em Ajustes → Aparência (fora o Material You, que é o
/// padrão). Só mudam a moldura (botões, seleção, destaques): itens e tipos
/// de evento mantêm as cores deles.
const Map<String, ({String nome, Color cor})> kCoresDoApp = {
  'azul': (nome: 'Azul', cor: Color(0xFF3C5F92)),
  'verde': (nome: 'Verde', cor: Color(0xFF3E7D5A)),
  'roxo': (nome: 'Roxo', cor: Color(0xFF6B4FA8)),
  'terracota': (nome: 'Terracota', cor: Color(0xFFB45A34)),
  'rosa': (nome: 'Rosa', cor: Color(0xFFAE4A73)),
  'grafite': (nome: 'Grafite', cor: Color(0xFF5B6570)),
};

/// Resolve o esquema de cor efetivo: o dinâmico do sistema quando existe e
/// bate com o brilho pedido, senão a semente fixa.
///
/// Reaproveitado fora do tema também: é o que alimenta o snapshot do widget
/// nativo com as mesmas cores (Monet incluso) que o app está mostrando.
///
/// Com [corDoApp] (chave de [kCoresDoApp]), a semente é ela e o dinâmico
/// fica de lado.
ColorScheme resolveColorScheme(ColorScheme? dynamicScheme, Brightness brightness, {String? corDoApp}) {
  final escolhida = kCoresDoApp[corDoApp]?.cor;
  if (escolhida != null) return ColorScheme.fromSeed(seedColor: escolhida, brightness: brightness);
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
ThemeData buildAppTheme(ColorScheme? dynamicScheme, Brightness brightness, {String? corDoApp}) {
  final scheme = resolveColorScheme(dynamicScheme, brightness, corDoApp: corDoApp);

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
