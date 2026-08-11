import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'itens_screen.dart';
import 'semana_screen.dart';
import 'tabelas_screen.dart';

/// A navegação principal do app.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.onToggleBrightness});

  final VoidCallback onToggleBrightness;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Enquanto o disco não respondeu, não vale desenhar estado vazio: a tela
    // piscaria "nenhuma tabela ainda" antes de mostrar as tabelas existentes.
    if (!state.carregado) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: IndexedStack(
        index: _aba,
        children: [
          SemanaScreen(onToggleBrightness: widget.onToggleBrightness),
          const ItensScreen(),
          const TabelasScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Semana',
          ),
          NavigationDestination(
            icon: Icon(Icons.label_outline),
            selectedIcon: Icon(Icons.label),
            label: 'Itens',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_rows_outlined),
            selectedIcon: Icon(Icons.table_rows),
            label: 'Tabelas',
          ),
        ],
      ),
    );
  }
}
