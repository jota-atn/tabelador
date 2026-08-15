import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'native_widget/home_widget_sync.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'ui/app_shell.dart';

void main() => runApp(const TabeladorApp());

class TabeladorApp extends StatefulWidget {
  const TabeladorApp({super.key});

  @override
  State<TabeladorApp> createState() => _TabeladorAppState();
}

class _TabeladorAppState extends State<TabeladorApp> with WidgetsBindingObserver {
  /// Só existe pra comparar os dois temas na tela de laboratório. O app final
  /// segue o tema do sistema.
  ThemeMode _mode = ThemeMode.system;

  late final AppState _appState = AppState()..carregar();
  late final HomeWidgetSync _widgetSync = HomeWidgetSync(_appState);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetSync.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // O Android não garante refresh de widget em background — reforça toda
    // vez que o app volta pro primeiro plano.
    if (state == AppLifecycleState.resumed) {
      _widgetSync.sincronizarAgora();
    }
  }

  void _toggleBrightness() {
    final isDark = _mode == ThemeMode.dark ||
        (_mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    setState(() => _mode = isDark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appState,
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          _widgetSync.atualizarEsquemas(
            resolveColorScheme(lightDynamic, Brightness.light),
            resolveColorScheme(darkDynamic, Brightness.dark),
          );
          return MaterialApp(
            title: 'Tabelador',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(lightDynamic, Brightness.light),
            darkTheme: buildAppTheme(darkDynamic, Brightness.dark),
            themeMode: _mode,
            home: AppShell(onToggleBrightness: _toggleBrightness),
          );
        },
      ),
    );
  }
}
