import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/item.dart';
import '../state/app_state.dart';
import 'item_editor.dart';
import 'widgets/item_swatch.dart';

/// A biblioteca de itens: disciplinas, monitorias, pausas.
///
/// Compartilhada entre tabelas — "Cálculo II" cadastrado uma vez serve pra
/// qualquer semestre.
class ItensScreen extends StatelessWidget {
  const ItensScreen({super.key});

  Future<void> _abrirEditor(BuildContext context, {Item? item}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ItemEditor(original: item)),
    );
  }

  Future<void> _confirmarExclusao(BuildContext context, Item item) async {
    final state = context.read<AppState>();
    final usos = state.usosDoItem(item.id);

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Apagar ${item.nome}?'),
        // Apagar em silêncio esvaziaria horários que o usuário não está vendo.
        content: Text(
          usos == 0
              ? 'Este item não está em nenhuma tabela.'
              : usos == 1
                  ? 'Ele está em 1 horário, que vai ficar vazio.'
                  : 'Ele está em $usos horários, que vão ficar vazios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmou ?? false) await state.removerItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final itens = state.itens;

    return Scaffold(
      appBar: AppBar(title: const Text('Itens')),
      floatingActionButton: FloatingActionButton(
        // As abas vivem juntas num IndexedStack, então os FABs coexistem e
        // precisam de tags de Hero distintas.
        heroTag: 'fab-itens',
        onPressed: () => _abrirEditor(context),
        tooltip: 'Novo item',
        child: const Icon(Icons.add),
      ),
      body: itens.isEmpty
          ? const _Vazio()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 88),
              itemCount: itens.length,
              itemBuilder: (context, i) {
                final item = itens[i];
                final usos = state.usosDoItem(item.id);

                return ListTile(
                  leading: ItemSwatch(
                    cor: item.cor,
                    densidade: state.densidade,
                    largura: 10,
                    altura: 38,
                  ),
                  title: Text(item.nome),
                  subtitle: Text(
                    [
                      if (item.tipo.isNotEmpty) item.tipo,
                      if (item.local != null) item.local!,
                      if (usos > 0) '$usos ${usos == 1 ? 'horário' : 'horários'}',
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SiglaTag(sigla: item.sigla),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Apagar',
                        onPressed: () => _confirmarExclusao(context, item),
                      ),
                    ],
                  ),
                  onTap: () => _abrirEditor(context, item: item),
                );
              },
            ),
    );
  }
}

class _SiglaTag extends StatelessWidget {
  const _SiglaTag({required this.sigla});

  final String sigla;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        sigla,
        style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();

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
              'Nenhum item ainda',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cadastre suas disciplinas e atividades aqui. '
              'Depois é só arrastar pra dentro da tabela.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
