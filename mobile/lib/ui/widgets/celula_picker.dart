import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/tabela.dart';
import '../../state/app_state.dart';
import '../../theme/color_density.dart';
import '../item_editor.dart';
import 'item_swatch.dart';

/// Abre o seletor de item pra uma célula específica (dia+slot) de [tabela] e
/// aplica a escolha — usado tanto pelo toque num horário vazio no editor do
/// dia quanto pelo toque longo direto numa célula da grade da semana. Os dois
/// lugares precisam do mesmo comportamento: mesma lista, mesma limpeza com
/// desfazer.
Future<void> abrirSeletorDeCelula(
  BuildContext context, {
  required Tabela tabela,
  required String dia,
  required int slot,
}) async {
  final state = context.read<AppState>();
  final ocupado = tabela.celula(dia, slot) != null;

  final escolha = await showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SeletorDeItem(
      tabelaId: tabela.id,
      densidade: state.densidade,
      permitirLimpar: ocupado,
    ),
  );

  if (escolha == null || !context.mounted) return;
  if (escolha.isEmpty) {
    await limparComDesfazer(context, state, tabela.id, dia, slot);
  } else {
    await state.definirCelula(tabela.id, dia, slot, escolha);
  }
}

/// Limpa uma célula e mostra um snackbar com "Desfazer" se havia algo nela.
///
/// Só pra ações explícitas de limpar (deslizar a célula, "Deixar vazio") —
/// mover um item arrastando não passa por aqui: a origem não foi "apagada",
/// só mudou de lugar, e avisar "removido" ali seria enganoso.
Future<void> limparComDesfazer(
  BuildContext context,
  AppState state,
  String tabelaId,
  String dia,
  int slot,
) async {
  final anteriorId = state.tabelaPorId(tabelaId)?.celula(dia, slot);
  await state.definirCelula(tabelaId, dia, slot, null);
  if (anteriorId == null || !context.mounted) return;

  final anterior = state.itemPorId(anteriorId);
  if (anterior == null) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('"${anterior.sigla}" removido'),
      action: SnackBarAction(
        label: 'Desfazer',
        onPressed: () => state.definirCelula(tabelaId, dia, slot, anterior.id),
      ),
    ),
  );
}

/// Lista de itens pra escolher por toque, com opção de limpar o slot.
///
/// Devolve o id escolhido, string vazia pra limpar, ou null se cancelou. Lê a
/// paleta ao vivo do [AppState] (em vez de receber uma lista pronta) pra que
/// criar um item pelo atalho abaixo e voltar já mostre ele na hora.
class SeletorDeItem extends StatelessWidget {
  const SeletorDeItem({
    super.key,
    required this.tabelaId,
    required this.densidade,
    required this.permitirLimpar,
  });

  final String tabelaId;
  final ColorDensity densidade;
  final bool permitirLimpar;

  Future<void> _criarItem(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ItemEditor(tabelaId: tabelaId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itens = context.watch<AppState>().itensParaTabela(tabelaId);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          if (permitirLimpar)
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Deixar vazio'),
              onTap: () => Navigator.of(context).pop(''),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Criar item só pra esta tabela'),
            onTap: () => _criarItem(context),
          ),
          for (final item in itens)
            ListTile(
              leading: ItemSwatch(
                cor: item.cor,
                densidade: densidade,
                largura: 10,
                altura: 34,
              ),
              title: Text(item.nome),
              subtitle: item.tipo.isEmpty ? null : Text(item.tipo),
              onTap: () => Navigator.of(context).pop(item.id),
            ),
        ],
      ),
    );
  }
}
