import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../model/item.dart';
import '../model/tabela.dart';
import '../state/app_state.dart';
import '../theme/color_density.dart';
import 'item_editor.dart';
import 'widgets/celula_picker.dart';
import 'widgets/item_swatch.dart';

/// O que está sendo arrastado.
///
/// [origem] é o slot de onde saiu, ou null se veio da paleta. Precisa dessa
/// distinção pra saber se o slot de origem deve ser esvaziado ao soltar.
typedef _Carga = ({String itemId, int? origem});

/// Editor de um dia: os horários como linhas largas, com a paleta de itens
/// logo abaixo — tudo numa lista só, crescendo pra baixo.
///
/// A grade semanal tem células de ~55dp, alvo pequeno demais pro dedo. Aqui
/// cada alvo é a linha inteira. Preencher um horário tem dois caminhos que
/// convivem: arrastar um item da paleta, ou tocar nele pra "armar" (o chip
/// ganha um contorno) e depois tocar no horário — mais confiável que
/// arrastar em telas pequenas ou com o dedo maior.
class DiaEditor extends StatefulWidget {
  const DiaEditor({super.key, required this.diaInicial});

  final String diaInicial;

  @override
  State<DiaEditor> createState() => _DiaEditorState();
}

class _DiaEditorState extends State<DiaEditor> {
  late int _dia = kDias.indexOf(widget.diaInicial).clamp(0, kDias.length - 1);

  /// Item "armado" pra tocar num horário e encaixar, sem precisar arrastar.
  /// Fica armado entre horários e entre dias — útil pra encaixar o mesmo
  /// item várias vezes seguidas.
  String? _itemArmado;

  void _irPara(int delta) {
    setState(() => _dia = (_dia + delta) % kDias.length);
  }

  void _armar(String itemId) {
    setState(() => _itemArmado = _itemArmado == itemId ? null : itemId);
  }

  Future<void> _definir(Tabela tabela, int slot, String? itemId) {
    return context
        .read<AppState>()
        .definirCelula(tabela.id, kDias[_dia], slot, itemId);
  }

  /// Soltar num slot: grava o destino e, se veio de outro slot do mesmo dia
  /// (não da paleta), resolve a origem. Destino vazio: origem só esvazia —
  /// mover, não copiar. Destino ocupado: o que estava lá vai pra origem —
  /// **troca**, em vez de sumir sob o item que chegou.
  Future<void> _aoSoltar(Tabela tabela, int destino, _Carga carga) async {
    // Sem await: vibração é feedback, não deve atrasar a gravação.
    unawaited(HapticFeedback.selectionClick());
    final origem = carga.origem;
    if (origem != null && origem != destino) {
      final itemNoDestino = tabela.celula(kDias[_dia], destino);
      await _definir(tabela, origem, itemNoDestino);
    }
    await _definir(tabela, destino, carga.itemId);
  }

  /// Tocar num horário: com item armado, encaixa ele na hora — sem armado,
  /// abre a lista completa (também é como se limpa um horário preenchido).
  Future<void> _tocarSlot(Tabela tabela, int slot) async {
    final armado = _itemArmado;
    if (armado != null) {
      unawaited(HapticFeedback.selectionClick());
      await _definir(tabela, slot, armado);
      return;
    }
    await _escolherPorToque(tabela, slot);
  }

  Future<void> _escolherPorToque(Tabela tabela, int slot) =>
      abrirSeletorDeCelula(context, tabela: tabela, dia: kDias[_dia], slot: slot);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tabela = state.tabelaAtiva;

    if (tabela == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Nenhuma tabela ativa')),
      );
    }

    final itens = state.itensParaTabela(tabela.id);
    final armado = _itemArmado != null ? state.itemPorId(_itemArmado) : null;

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
          if (armado != null)
            _BannerArmado(item: armado, aoCancelar: () => _armar(armado.id)),
          Expanded(
            child: GestureDetector(
              // Swipe horizontal troca de dia, como o carrossel que a grade
              // semanal sugere.
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -200) _irPara(1);
                if (v > 200) _irPara(-1);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                children: [
                  for (var slot = 0; slot < tabela.qtdHorarios; slot++)
                    _LinhaSlot(
                      rotulo: tabela.horarios[slot],
                      item: state.itemPorId(tabela.celula(kDias[_dia], slot)),
                      densidade: state.densidade,
                      slot: slot,
                      itemArmado: armado != null,
                      aoSoltar: (carga) => _aoSoltar(tabela, slot, carga),
                      aoTocar: () => _tocarSlot(tabela, slot),
                      aoLimpar: () => limparComDesfazer(
                        context,
                        state,
                        tabela.id,
                        kDias[_dia],
                        slot,
                      ),
                    ),
                  const SizedBox(height: 20),
                  _Paleta(
                    itens: itens,
                    densidade: state.densidade,
                    tabelaId: tabela.id,
                    itemArmadoId: _itemArmado,
                    aoArmar: _armar,
                  ),
                  if (itens.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                      child: Text(
                        'Toque em "item" ali em cima pra cadastrar o primeiro.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra fixa no topo enquanto um item está armado — sem ela, tocar num chip
/// e nada acontecer na hora pareceria tão quebrado quanto o arrastar que não
/// pegou.
class _BannerArmado extends StatelessWidget {
  const _BannerArmado({required this.item, required this.aoCancelar});

  final Item item;
  final VoidCallback aoCancelar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Toque num horário pra colocar "${item.sigla}"',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
            IconButton(
              onPressed: aoCancelar,
              icon: Icon(Icons.close, size: 18, color: scheme.onSecondaryContainer),
              visualDensity: VisualDensity.compact,
              tooltip: 'Cancelar seleção',
            ),
          ],
        ),
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
    required this.itemArmado,
    required this.aoSoltar,
    required this.aoTocar,
    required this.aoLimpar,
  });

  final String rotulo;
  final Item? item;
  final ColorDensity densidade;
  final int slot;
  final bool itemArmado;
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
                  itemArmado: itemArmado,
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
    required this.itemArmado,
    required this.aoTocar,
    required this.aoLimpar,
  });

  final Item? item;
  final ColorDensity densidade;
  final int slot;
  final bool destacado;
  final bool itemArmado;
  final VoidCallback aoTocar;
  final VoidCallback aoLimpar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final i = item;

    if (i == null) {
      final corBorda = destacado
          ? scheme.primary
          : (itemArmado ? scheme.primary.withValues(alpha: 0.4) : scheme.outlineVariant);

      return GestureDetector(
        onTap: aoTocar,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: destacado ? scheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: corBorda),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!destacado) ...[
                Icon(Icons.add, size: 13, color: corBorda),
                const SizedBox(width: 6),
              ],
              Text(
                destacado ? 'solte aqui' : (itemArmado ? 'toque pra colocar' : 'vazio'),
                style: TextStyle(
                  fontSize: 11,
                  color: destacado ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
                ),
              ),
            ],
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
        delay: const Duration(milliseconds: 300),
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(
            scale: 1.05,
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

/// A paleta de itens: flui e cresce pra baixo em vez de rolar de lado, com o
/// atalho de criar item sempre por último.
class _Paleta extends StatelessWidget {
  const _Paleta({
    required this.itens,
    required this.densidade,
    required this.tabelaId,
    required this.itemArmadoId,
    required this.aoArmar,
  });

  final List<Item> itens;
  final ColorDensity densidade;
  final String tabelaId;
  final String? itemArmadoId;
  final ValueChanged<String> aoArmar;

  Future<void> _criarItem(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ItemEditor(tabelaId: tabelaId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ITENS — TOQUE PRA ARMAR OU ARRASTE',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in itens)
              _ChipItem(
                item: item,
                densidade: densidade,
                armado: item.id == itemArmadoId,
                onTap: () => aoArmar(item.id),
              ),
            _BotaoNovoItem(onTap: () => _criarItem(context)),
          ],
        ),
      ],
    );
  }
}

class _ChipItem extends StatelessWidget {
  const _ChipItem({
    required this.item,
    required this.densidade,
    required this.armado,
    required this.onTap,
  });

  final Item item;
  final ColorDensity densidade;
  final bool armado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = ItemSwatch(
      cor: item.cor,
      densidade: densidade,
      texto: item.sigla,
      largura: 78,
      altura: 34,
      raio: 17,
    );

    // Contorno sempre reservado (transparente quando não armado) pra armar
    // não mudar o tamanho do chip nem empurrar os vizinhos no Wrap.
    final comAro = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: armado ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: chip,
    );

    // Toque arma (encaixa no próximo toque num horário); long-press arrasta.
    // Os dois caminhos convivem — nenhum invalida o outro.
    return LongPressDraggable<_Carga>(
      data: (itemId: item.id, origem: null),
      delay: const Duration(milliseconds: 300),
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.08,
          child: Transform.rotate(angle: -0.04, child: chip),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: comAro),
      onDragStarted: HapticFeedback.selectionClick,
      child: GestureDetector(onTap: onTap, child: comAro),
    );
  }
}

/// Atalho de criar item sem sair do editor do dia — nasce exclusivo desta
/// tabela (ver [Item.tabelaId]), pro caso comum de algo que só existe neste
/// semestre.
class _BotaoNovoItem extends StatelessWidget {
  const _BotaoNovoItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        // +4 pra bater com o aro reservado (2 de cada lado) dos chips ao lado.
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: scheme.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              'item',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
