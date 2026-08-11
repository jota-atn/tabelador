import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'ui/app_shell.dart';

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
    return ChangeNotifierProvider(
      create: (_) => AppState()..carregar(),
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) => MaterialApp(
          title: 'Tabelador',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(lightDynamic, Brightness.light),
          darkTheme: buildAppTheme(darkDynamic, Brightness.dark),
          themeMode: _mode,
          home: AppShell(onToggleBrightness: _toggleBrightness),
        ),
      ),
    );
  }
}
