import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'ui/density_lab.dart';

void main() => runApp(const TabeladorApp());

class TabeladorApp extends StatefulWidget {
  const TabeladorApp({super.key});

  @override
  State<TabeladorApp> createState() => _TabeladorAppState();
}

class _TabeladorAppState extends State<TabeladorApp> {
  /// Só existe pra comparar os dois temas na tela de laboratório. O app final
  /// segue o tema do sistema.
  ThemeMode _mode = ThemeMode.system;

  void _toggleBrightness() {
    final isDark = _mode == ThemeMode.dark ||
        (_mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    setState(() => _mode = isDark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp(
        title: 'Tabelador',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(lightDynamic, Brightness.light),
        darkTheme: buildAppTheme(darkDynamic, Brightness.dark),
        themeMode: _mode,
        home: DensityLab(
          onToggleBrightness: _toggleBrightness,
          // Diagnóstico da fase 2: saber se o aparelho realmente entrega o
          // Monet, em vez de deduzir isso olhando a cor de um botão.
          monetDisponivel: lightDynamic != null || darkDynamic != null,
        ),
      ),
    );
  }
}
