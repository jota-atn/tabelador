import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import 'native_widget/home_widget_sync.dart';
import 'notifications/notification_scheduler.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationsPlugin = await inicializarNotificacoes();
  runApp(TabeladorApp(notificationsPlugin: notificationsPlugin));
}

class TabeladorApp extends StatefulWidget {
  /// [notificationsPlugin] nulo desliga o agendamento de notificação por
  /// completo, sem tocar em nenhum canal de plataforma — é o caso dos testes
  /// de widget, que não têm o plugin nativo disponível. Em produção,
  /// `main()` sempre inicializa e passa um.
  const TabeladorApp({super.key, this.notificationsPlugin});

  final FlutterLocalNotificationsPlugin? notificationsPlugin;

  @override
  State<TabeladorApp> createState() => _TabeladorAppState();
}

class _TabeladorAppState extends State<TabeladorApp> with WidgetsBindingObserver {
  /// Só existe pra comparar os dois temas na tela de laboratório. O app final
  /// segue o tema do sistema.
  ThemeMode _mode = ThemeMode.system;

  late final AppState _appState = AppState()..carregar();
  late final HomeWidgetSync _widgetSync = HomeWidgetSync(_appState);
  late final NotificationScheduler? _notificationScheduler =
      widget.notificationsPlugin == null
          ? null
          : NotificationScheduler(_appState, widget.notificationsPlugin!);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetSync.dispose();
    _notificationScheduler?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // O Android não garante refresh de widget em background, e alarme
    // inexato pode ter sido perdido (reinício do aparelho, Doze) — os dois
    // se reforçam sempre que o app volta pro primeiro plano.
    if (state == AppLifecycleState.resumed) {
      _widgetSync.sincronizarAgora();
      _notificationScheduler?.sincronizarAgora();
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _appState),
        // Nulo nos testes de widget (sem o plugin nativo disponível) — quem
        // usa isso já trata esse caso, é só pra pedir permissão na hora de
        // ligar o interruptor de notificação.
        Provider<FlutterLocalNotificationsPlugin?>.value(
          value: widget.notificationsPlugin,
        ),
      ],
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
