import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/tabela.dart';
import '../state/app_state.dart';
import 'aparencia_screen.dart';
import 'dia_editor.dart';
import 'widgets/grade_semana.dart';

/// A tela inicial: a semana inteira da tabela ativa, só leitura.
class SemanaScreen extends StatelessWidget {
  const SemanaScreen({super.key, required this.onToggleBrightness});

  final VoidCallback onToggleBrightness;

  void _abrirDia(BuildContext context, String dia) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DiaEditor(diaInicial: dia)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final tabela = state.tabelaAtiva;

    return Scaffold(
      appBar: AppBar(
        title: tabela == null
            ? const Text('Tabelador')
            : _SeletorDeTabela(ativa: tabela, tabelas: state.tabelas),
        actions: [
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
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GradeSemana(
                    tabela: tabela,
                    densidade: state.densidade,
                    itemPorId: state.itemPorId,
                    aoTocarDia: (dia) => _abrirDia(context, dia),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Toque num dia pra montar o horário',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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
