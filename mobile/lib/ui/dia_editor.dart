import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../model/item.dart';
import '../model/tabela.dart';
import '../state/app_state.dart';
import '../theme/color_density.dart';
import 'widgets/item_swatch.dart';

/// O que está sendo arrastado.
///
/// [origem] é o slot de onde saiu, ou null se veio da bandeja. Precisa dessa
/// distinção pra saber se o slot de origem deve ser esvaziado ao soltar.
typedef _Carga = ({String itemId, int? origem});

/// Editor de um dia: os horários como linhas largas, com a bandeja de itens
/// fixa embaixo.
///
/// A grade semanal tem células de ~55dp, alvo pequeno demais pro dedo. Aqui
/// cada alvo é a linha inteira.
class DiaEditor extends StatefulWidget {
  const DiaEditor({super.key, required this.diaInicial});

  final String diaInicial;

  @override
  State<DiaEditor> createState() => _DiaEditorState();
}

class _DiaEditorState extends State<DiaEditor> {
  late int _dia = kDias.indexOf(widget.diaInicial).clamp(0, kDias.length - 1);

  void _irPara(int delta) {
    setState(() => _dia = (_dia + delta) % kDias.length);
  }

  Future<void> _definir(Tabela tabela, int slot, String? itemId) {
    return context
        .read<AppState>()
        .definirCelula(tabela.id, kDias[_dia], slot, itemId);
  }

  /// Soltar num slot: grava o destino e, se veio de outro slot do mesmo dia,
  /// esvazia a origem — arrastar entre slots move, não copia.
  Future<void> _aoSoltar(Tabela tabela, int destino, _Carga carga) async {
    // Sem await: vibração é feedback, não deve atrasar a gravação.
    unawaited(HapticFeedback.selectionClick());
    if (carga.origem != null && carga.origem != destino) {
      await _definir(tabela, carga.origem!, null);
    }
    await _definir(tabela, destino, carga.itemId);
  }

  /// Caminho alternativo ao arrastar. Existe pra acessibilidade e pra dedo
  /// grande: arrastar é o gesto principal, mas nunca o único.
  Future<void> _escolherPorToque(Tabela tabela, int slot) async {
    final state = context.read<AppState>();
    final ocupado = tabela.celula(kDias[_dia], slot) != null;

    final escolha = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _SeletorDeItem(
        itens: state.itens,
        densidade: state.densidade,
        permitirLimpar: ocupado,
      ),
    );

    if (escolha == null || !mounted) return;
    await _definir(tabela, slot, escolha.isEmpty ? null : escolha);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final tabela = state.tabelaAtiva;

    if (tabela == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Nenhuma tabela ativa')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              onPressed: () => _irPara(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Dia anterior',
            ),
            Expanded(
              child: Text(
                kDias[_dia],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _irPara(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Próximo dia',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              // Swipe horizontal troca de dia, como o carrossel que a grade
              // semanal sugere.
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -200) _irPara(1);
                if (v > 200) _irPara(-1);
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                itemCount: tabela.qtdHorarios,
                itemBuilder: (context, slot) => _LinhaSlot(
                  rotulo: tabela.horarios[slot],
                  item: state.itemPorId(tabela.celula(kDias[_dia], slot)),
                  densidade: state.densidade,
                  slot: slot,
                  aoSoltar: (carga) => _aoSoltar(tabela, slot, carga),
                  aoTocar: () => _escolherPorToque(tabela, slot),
                  aoLimpar: () => _definir(tabela, slot, null),
                ),
              ),
            ),
          ),
          _Bandeja(itens: state.itens, densidade: state.densidade),
          if (state.itens.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Cadastre itens na aba Itens pra poder montar o horário.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinhaSlot extends StatelessWidget {
  const _LinhaSlot({
    required this.rotulo,
    required this.item,
    required this.densidade,
    required this.slot,
    required this.aoSoltar,
    required this.aoTocar,
    required this.aoLimpar,
  });

  final String rotulo;
  final Item? item;
  final ColorDensity densidade;
  final int slot;
  final void Function(_Carga) aoSoltar;
  final VoidCallback aoTocar;
  final VoidCallback aoLimpar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              rotulo.split('-').first,
              style: TextStyle(
                fontSize: 10,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: DragTarget<_Carga>(
              onAcceptWithDetails: (d) => aoSoltar(d.data),
              builder: (context, candidatos, _) {
                final ativo = candidatos.isNotEmpty;
                return _Corpo(
                  item: item,
                  densidade: densidade,
                  slot: slot,
                  destacado: ativo,
                  aoTocar: aoTocar,
                  aoLimpar: aoLimpar,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Corpo extends StatelessWidget {
  const _Corpo({
    required this.item,
    required this.densidade,
    required this.slot,
    required this.destacado,
    required this.aoTocar,
    required this.aoLimpar,
  });

  final Item? item;
  final ColorDensity densidade;
  final int slot;
  final bool destacado;
  final VoidCallback aoTocar;
  final VoidCallback aoLimpar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final i = item;

    if (i == null) {
      return GestureDetector(
        onTap: aoTocar,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: destacado ? scheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: destacado ? scheme.primary : scheme.outlineVariant,
              style: BorderStyle.solid,
            ),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            destacado ? 'solte aqui' : 'vazio',
            style: TextStyle(
              fontSize: 11,
              color: destacado
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final conteudo = Container(
      height: 54,
      decoration: destacado
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.primary, width: 2),
            )
          : null,
      child: _Preenchido(item: i, densidade: densidade),
    );

    return Dismissible(
      key: ValueKey('slot-$slot-${i.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => aoLimpar(),
      background: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Icon(Icons.close, size: 18, color: scheme.onSurfaceVariant),
        ),
      ),
      child: LongPressDraggable<_Carga>(
        data: (itemId: i.id, origem: slot),
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.92,
            child: SizedBox(
              width: 200,
              height: 54,
              child: _Preenchido(item: i, densidade: densidade),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: conteudo),
        onDragStarted: HapticFeedback.selectionClick,
        child: GestureDetector(onTap: aoTocar, child: conteudo),
      ),
    );
  }
}

class _Preenchido extends StatelessWidget {
  const _Preenchido({required this.item, required this.densidade});

  final Item item;
  final ColorDensity densidade;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: ItemSwatch(cor: item.cor, densidade: densidade, raio: 8),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.tipo.isNotEmpty || item.local != null)
                  Text(
                    [
                      if (item.tipo.isNotEmpty) item.tipo,
                      if (item.local != null) item.local!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A bandeja de itens no rodapé, de onde se arrasta.
class _Bandeja extends StatelessWidget {
  const _Bandeja({required this.itens, required this.densidade});

  final List<Item> itens;
  final ColorDensity densidade;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (itens.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ARRASTE PRA UM HORÁRIO',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: itens.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final item = itens[i];
                final chip = ItemSwatch(
                  cor: item.cor,
                  densidade: densidade,
                  texto: item.sigla,
                  largura: 78,
                  altura: 34,
                  raio: 17,
                );

                // Long-press, não arrasto direto: a bandeja rola na
                // horizontal, e um Draggable comum roubaria o gesto de
                // rolagem — não daria pra percorrer a lista de itens.
                return LongPressDraggable<_Carga>(
                  data: (itemId: item.id, origem: null),
                  feedback: Material(
                    color: Colors.transparent,
                    child: Transform.rotate(angle: -0.04, child: chip),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: chip),
                  onDragStarted: HapticFeedback.selectionClick,
                  child: chip,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista de itens pra escolher por toque, com opção de limpar o slot.
///
/// Devolve o id escolhido, string vazia pra limpar, ou null se cancelou.
class _SeletorDeItem extends StatelessWidget {
  const _SeletorDeItem({
    required this.itens,
    required this.densidade,
    required this.permitirLimpar,
  });

  final List<Item> itens;
  final ColorDensity densidade;
  final bool permitirLimpar;

  @override
  Widget build(BuildContext context) {
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
