import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/item.dart';
import '../state/app_state.dart';
import 'item_editor.dart';
import 'widgets/item_swatch.dart';

/// A biblioteca de itens: disciplinas, treinos, compromissos, o que for.
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

  Future<void> _alternarArquivado(BuildContext context, Item item) {
    return context.read<AppState>().definirArquivado(item.id, !item.arquivado);
  }

  Widget _tile(BuildContext context, AppState state, Item item) {
    final usos = state.usosDoItem(item.id);

    final tile = ListTile(
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
          if (item.tabelaId != null)
            'só em ${state.tabelaPorId(item.tabelaId)?.nome ?? "tabela apagada"}',
          if (item.local != null) item.local!,
          if (usos > 0) '$usos ${usos == 1 ? 'horário' : 'horários'}',
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SiglaTag(sigla: item.sigla),
          PopupMenuButton<String>(
            onSelected: (opcao) => switch (opcao) {
              'arquivar' => _alternarArquivado(context, item),
              'apagar' => _confirmarExclusao(context, item),
              _ => null,
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'arquivar',
                child: Text(item.arquivado ? 'Desarquivar' : 'Arquivar'),
              ),
              const PopupMenuItem(value: 'apagar', child: Text('Apagar')),
            ],
          ),
        ],
      ),
      onTap: () => _abrirEditor(context, item: item),
    );

    // Arquivado esmaece pra ficar claro, num olhar, que ele não entra na
    // paleta de arrastar — sem precisar de um rótulo escrito em toda linha.
    return item.arquivado ? Opacity(opacity: 0.55, child: tile) : tile;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ativos = state.itens.where((i) => !i.arquivado).toList();
    final arquivados = state.itens.where((i) => i.arquivado).toList();

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
      body: state.itens.isEmpty
          ? const _Vazio()
          : ListView(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 88),
              children: [
                for (final item in ativos) _tile(context, state, item),
                if (arquivados.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'ARQUIVADOS',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final item in arquivados) _tile(context, state, item),
                ],
              ],
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
            Icon(Icons.label_outline, size: 32, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
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
              'Cadastre suas disciplinas, treinos e compromissos aqui. '
              'Depois é só encaixar num horário.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
