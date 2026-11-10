import 'package:flutter/material.dart';

import 'chip_deslizavel.dart';

/// Uma opção da [GradeDeChips].
class OpcaoChip {
  const OpcaoChip({
    required this.rotulo,
    required this.selecionado,
    this.aoTocar,
    this.menu,
    this.icone,
    this.fundo,
    this.texto,
    this.borda,
  }) : assert(aoTocar != null || menu != null);

  final String rotulo;
  final bool selecionado;
  final VoidCallback? aoTocar;

  /// Com menu, tocar abre a lista flutuante acima do chip e segurar +
  /// arrastar escolhe direto (ver [MenuFlutuante]).
  final List<OpcaoMenu>? menu;
  final IconData? icone;

  /// Cores próprias (chip de item, na cor dele). Nulas = cores do tema.
  final Color? fundo;
  final Color? texto;
  final Color? borda;
}

/// Chips em linhas **justificadas**: empacota como um Wrap, mas cada linha
/// estica os chips proporcionalmente ao tamanho natural deles até ocupar a
/// largura toda — bordas esquerda e direita alinhadas em todas as linhas,
/// como texto justificado. Todos com a mesma altura, então nada fica "um
/// pouco abaixo" (o problema de misturar ChoiceChip, ActionChip e chip
/// próprio, cada um com uma altura).
class GradeDeChips extends StatelessWidget {
  const GradeDeChips({super.key, required this.opcoes});

  final List<OpcaoChip> opcoes;

  static const double altura = 38;
  static const double _espaco = 6;
  static const double _padH = 12;
  static const double _icone = 16;
  static const double _seta = 18;
  static const TextStyle _estilo = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600);

  /// Medir texto custa; a folha redesenha a cada toque. Os rótulos são
  /// poucos e se repetem, então guarda.
  static final Map<String, double> _medidas = {};

  double _larguraNatural(OpcaoChip o, TextScaler escala) {
    final chave = '${o.rotulo}|${o.icone != null}|${o.menu != null}|${escala.scale(100)}';
    return _medidas[chave] ??= _medir(o, escala);
  }

  double _medir(OpcaoChip o, TextScaler escala) {
    final tp = TextPainter(
      text: TextSpan(text: o.rotulo, style: _estilo),
      textDirection: TextDirection.ltr,
      textScaler: escala,
      maxLines: 1,
    )..layout();
    return tp.width +
        _padH * 2 +
        (o.icone == null ? 0 : _icone + 6) +
        (o.menu == null ? 0 : _seta + 2) +
        2;
  }

  static List<List<(OpcaoChip, double)>> _empacotar(
    List<(OpcaoChip, double)> itens,
    double limite,
  ) {
    final linhas = <List<(OpcaoChip, double)>>[];
    var atual = <(OpcaoChip, double)>[];
    var usado = 0.0;
    for (final item in itens) {
      final extra = atual.isEmpty ? item.$2 : item.$2 + _espaco;
      if (atual.isNotEmpty && usado + extra > limite) {
        linhas.add(atual);
        atual = [];
        usado = 0;
      }
      usado += atual.isEmpty ? item.$2 : item.$2 + _espaco;
      atual.add(item);
    }
    if (atual.isNotEmpty) linhas.add(atual);
    return linhas;
  }

  @override
  Widget build(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        final larguraTotal = c.maxWidth;
        final itens = [
          for (final o in opcoes) (o, _larguraNatural(o, escala).clamp(0.0, larguraTotal)),
        ];
        // Empacota com o menor limite que ainda dá o mesmo número de linhas
        // do empacotamento cheio: linhas equilibradas, sem um chip sozinho
        // esticado na última.
        final minimo = _empacotar(itens, larguraTotal).length;
        var lo = itens.fold(0.0, (a, i) => a > i.$2 ? a : i.$2);
        var hi = larguraTotal;
        for (var passo = 0; passo < 14 && hi - lo > 1; passo++) {
          final meio = (lo + hi) / 2;
          if (_empacotar(itens, meio).length <= minimo) {
            hi = meio;
          } else {
            lo = meio;
          }
        }
        final linhas = _empacotar(itens, hi);

        return Column(
          children: [
            for (var l = 0; l < linhas.length; l++)
              Padding(
                padding: EdgeInsets.only(top: l == 0 ? 0 : _espaco),
                child: Row(
                  children: [
                    for (var i = 0; i < linhas[l].length; i++) ...[
                      if (i > 0) const SizedBox(width: _espaco),
                      Expanded(
                        flex: (linhas[l][i].$2 * 10).round(),
                        child: _Chip(opcao: linhas[l][i].$1),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({required this.opcao});

  final OpcaoChip opcao;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  MenuFlutuante? _menu;

  @override
  void dispose() {
    _menu?.dispose();
    super.dispose();
  }

  void _abrirMenu({required bool arrastando}) {
    _menu?.dispose();
    _menu = MenuFlutuante(widget.opcao.menu!)..abrir(context, arrastando: arrastando);
  }

  @override
  Widget build(BuildContext context) {
    final temMenu = widget.opcao.menu != null;
    return GestureDetector(
      onLongPressStart: temMenu ? (_) => _abrirMenu(arrastando: true) : null,
      onLongPressMoveUpdate: temMenu ? (d) => _menu?.mover(d.globalPosition) : null,
      onLongPressEnd: temMenu ? (_) => _menu?.soltar() : null,
      child: _desenho(
        context,
        temMenu ? () => _abrirMenu(arrastando: false) : widget.opcao.aoTocar!,
      ),
    );
  }

  Widget _desenho(BuildContext context, VoidCallback aoTocar) {
    final scheme = Theme.of(context).colorScheme;
    final o = widget.opcao;
    final fundo = o.fundo ?? (o.selecionado ? scheme.secondaryContainer : scheme.surfaceContainerHighest);
    final texto = o.texto ?? (o.selecionado ? scheme.onSecondaryContainer : scheme.onSurfaceVariant);
    final borda = o.borda ?? (o.selecionado ? scheme.secondary : Colors.transparent);

    return Semantics(
      button: true,
      selected: o.selecionado,
      child: Material(
        color: fundo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borda, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: SizedBox(
            height: GradeDeChips.altura,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (o.icone != null) ...[
                    Icon(o.icone, size: 16, color: texto),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      o.rotulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GradeDeChips._estilo.copyWith(
                        color: texto,
                        fontWeight: o.selecionado ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (o.menu != null) ...[
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, size: GradeDeChips._seta, color: texto),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
