import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'density_lab.dart';
import 'itens_screen.dart';
import 'tabelas_screen.dart';

/// A navegação principal do app.
///
/// A aba "Semana" ainda mostra o laboratório de cores da fase 2 — a visão
/// semana de verdade chega na fase 5 e entra no lugar dele.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.onToggleBrightness,
    required this.monetDisponivel,
  });

  final VoidCallback onToggleBrightness;
  final bool monetDisponivel;

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
          DensityLab(
            onToggleBrightness: widget.onToggleBrightness,
            monetDisponivel: widget.monetDisponivel,
          ),
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
