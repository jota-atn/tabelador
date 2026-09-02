import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'dia_editor.dart';
import 'widgets/celula_picker.dart';
import 'widgets/semana_corpo.dart';

/// Editor de uma tabela específica, aberto a partir do card em Tabelas.
///
/// Ao contrário da aba Semana (que sempre mostra "a tabela ativa", seja lá
/// qual for, com um seletor pra trocar), esta tela está amarrada à tabela que
/// o usuário tocou — título fixo, sem seletor. É uma segunda porta de
/// entrada pra mesma edição: reaproveita [GradeSemana] e [DiaEditor], só que
/// chegando direto pela tabela em vez de precisar trocar de aba.
class TabelaEditorScreen extends StatelessWidget {
  const TabelaEditorScreen({super.key, required this.tabelaId});

  final String tabelaId;

  void _abrirDia(BuildContext context, String dia) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DiaEditor(diaInicial: dia)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tabela = state.tabelaPorId(tabelaId);

    if (tabela == null) {
      // A tabela foi apagada enquanto esta tela estava aberta.
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Esta tabela não existe mais')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tabela.nome)),
      body: SemanaCorpo(
        tabela: tabela,
        densidade: state.densidade,
        itemPorId: state.itemPorId,
        aoTocarDia: (dia) => _abrirDia(context, dia),
        aoEditarCelula: (dia, slot) =>
            abrirSeletorDeCelula(context, tabela: tabela, dia: dia, slot: slot),
      ),
    );
  }
}
