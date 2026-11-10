import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/tabela.dart';
import '../state/app_state.dart';
import '../util/eventos_na_grade.dart';
import 'aparencia_screen.dart';
import 'calendario_screen.dart';
import 'dia_editor.dart';
import 'evento_editor.dart';
import 'widgets/celula_picker.dart';
import 'widgets/proximos_eventos.dart';
import 'widgets/semana_corpo.dart';

/// A tela inicial: a semana inteira da tabela ativa, só leitura.
class SemanaScreen extends StatelessWidget {
  const SemanaScreen({super.key, required this.onToggleBrightness});

  final VoidCallback onToggleBrightness;

  void _abrirDia(BuildContext context, String dia) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DiaEditor(diaInicial: dia)),
    );
  }

  /// Troca pra próxima/anterior tabela na lista — o mesmo swipe horizontal
  /// que o editor do dia usa pra trocar de dia, aqui trocando de tabela.
  void _trocarTabela(BuildContext context, AppState state, int delta) {
    final tabelas = state.tabelas;
    if (tabelas.length < 2) return;
    final indice = tabelas.indexWhere((t) => t.id == state.tabelaAtivaId);
    if (indice == -1) return;
    final novoIndice = (indice + delta + tabelas.length) % tabelas.length;
    state.definirTabelaAtiva(tabelas[novoIndice].id);
  }

  /// Início do slot nesta semana — ou na próxima, se nesta já passou. É a
  /// data que um evento criado pelo toque longo recebe: "prova no horário da
  /// aula" quase sempre é numa aula que ainda vai acontecer.
  static DateTime _proximaDataDoSlot(
    Tabela tabela,
    String dia,
    int slot,
    DateTime segunda,
  ) {
    final d = dataDaColuna(segunda, dia);
    final hora = tabela.horaInicial + slot * tabela.intervalo;
    final nestaSemana = DateTime(d.year, d.month, d.day, hora);
    return nestaSemana.isBefore(DateTime.now())
        ? DateTime(d.year, d.month, d.day + 7, hora)
        : nestaSemana;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final tabela = state.tabelaAtiva;
    final segunda = segundaDaSemana(DateTime.now());
    final eventos = tabela == null
        ? null
        : distribuirEventos(
            tabela: tabela,
            segunda: segunda,
            ocorrencias: state.ocorrenciasEntre(
              segunda,
              DateTime(segunda.year, segunda.month, segunda.day + 7),
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: tabela == null
            ? const Text('Tabelador')
            : _SeletorDeTabela(ativa: tabela, tabelas: state.tabelas),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CalendarioScreen()),
            ),
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Calendário',
          ),
          IconButton(
            onPressed: onToggleBrightness,
            icon: Icon(
              scheme.brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: 'Alternar tema',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AparenciaScreen()),
            ),
            icon: const Icon(Icons.tune),
            tooltip: 'Aparência',
          ),
        ],
      ),
      body: tabela == null
          ? const _SemTabela()
          : GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -200) _trocarTabela(context, state, 1);
                if (v > 200) _trocarTabela(context, state, -1);
              },
              child: SemanaCorpo(
                tabela: tabela,
                densidade: state.densidade,
                itemPorId: state.itemPorId,
                aoTocarDia: (dia) => _abrirDia(context, dia),
                aoEditarCelula: (dia, slot) => abrirSeletorDeCelula(
                  context,
                  tabela: tabela,
                  dia: dia,
                  slot: slot,
                  dataDoSlot: _proximaDataDoSlot(tabela, dia, slot, segunda),
                ),
                rodape: const ProximosEventos(),
                eventos: eventos,
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EventoEditor()),
        ),
        tooltip: 'Novo evento',
        child: const Icon(Icons.event_outlined),
      ),
    );
  }
}

class _SeletorDeTabela extends StatelessWidget {
  const _SeletorDeTabela({required this.ativa, required this.tabelas});

  final Tabela ativa;
  final List<Tabela> tabelas;

  @override
  Widget build(BuildContext context) {
    // Com uma tabela só, o menu não teria o que oferecer.
    if (tabelas.length < 2) return Text(ativa.nome);

    return PopupMenuButton<String>(
      onSelected: (id) => context.read<AppState>().definirTabelaAtiva(id),
      itemBuilder: (_) => [
        for (final t in tabelas)
          PopupMenuItem(
            value: t.id,
            child: Row(
              children: [
                Expanded(child: Text(t.nome)),
                if (t.id == ativa.id) const Icon(Icons.check, size: 18),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(ativa.nome, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

class _SemTabela extends StatelessWidget {
  const _SemTabela();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nenhuma tabela ativa',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Crie uma tabela na aba Tabelas pra começar a montar seu horário.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
