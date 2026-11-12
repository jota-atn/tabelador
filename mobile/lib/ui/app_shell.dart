import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'eventos_screen.dart';
import 'itens_screen.dart';
import 'semana_screen.dart';
import 'tabelas_screen.dart';

/// Um destino da navegação principal — mesmo dado alimenta a barra debaixo
/// (celular em pé) e a barra lateral (tela larga: tablet, celular deitado).
typedef _Destino = ({IconData icone, IconData selecionado, String rotulo});

const List<_Destino> _kDestinos = [
  (
    icone: Icons.grid_view_outlined,
    selecionado: Icons.grid_view,
    rotulo: 'Semana',
  ),
  (
    icone: Icons.event_note_outlined,
    selecionado: Icons.event_note,
    rotulo: 'Eventos',
  ),
  (
    icone: Icons.category_outlined,
    selecionado: Icons.category,
    rotulo: 'Itens',
  ),
  (
    icone: Icons.table_rows_outlined,
    selecionado: Icons.table_rows,
    rotulo: 'Tabelas',
  ),
];

/// Largura a partir da qual a navegação vira barra lateral — a fronteira
/// "compacta/média" do Material 3, que também é onde um celular deitado
/// (~800dp de largura) cai naturalmente.
const double _kLarguraBarraLateral = 600;

/// A navegação principal do app.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.onToggleBrightness});

  final VoidCallback onToggleBrightness;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _aba = 0;

  /// Último pedido de "ir pra Semana" já atendido (ver
  /// [AppState.pedidosDeSemana]).
  int _pedidoAtendido = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Enquanto o disco não respondeu, não vale desenhar estado vazio: a tela
    // piscaria "nenhuma tabela ainda" antes de mostrar as tabelas existentes.
    if (!state.carregado) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // O calendário pediu a tela inicial numa semana: troca de aba. Mexe no
    // campo antes de usá-lo neste mesmo build, sem setState.
    if (state.pedidosDeSemana != _pedidoAtendido) {
      _pedidoAtendido = state.pedidosDeSemana;
      _aba = 0;
    }

    final telas = IndexedStack(
      index: _aba,
      children: [
        SemanaScreen(onToggleBrightness: widget.onToggleBrightness),
        const EventosScreen(),
        const ItensScreen(),
        const TabelasScreen(),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _kLarguraBarraLateral) {
          return Scaffold(
            body: telas,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _aba,
              onDestinationSelected: (i) => setState(() => _aba = i),
              destinations: [
                for (final d in _kDestinos)
                  NavigationDestination(
                    icon: Icon(d.icone),
                    selectedIcon: Icon(d.selecionado),
                    label: d.rotulo,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _aba,
                onDestinationSelected: (i) => setState(() => _aba = i),
                labelType: NavigationRailLabelType.all,
                // Padrão alinha no topo, sobrando um vão vazio embaixo — 0.0
                // centraliza o grupo na altura toda da barra.
                groupAlignment: 0.0,
                destinations: [
                  for (final d in _kDestinos)
                    NavigationRailDestination(
                      icon: Icon(d.icone),
                      selectedIcon: Icon(d.selecionado),
                      label: Text(d.rotulo),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: telas),
            ],
          ),
        );
      },
    );
  }
}
