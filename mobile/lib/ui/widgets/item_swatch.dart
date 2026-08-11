import 'package:flutter/material.dart';

import '../../theme/color_density.dart';
import '../../theme/item_palette.dart';

/// Amostra de uma cor de item, renderizada na densidade escolhida.
///
/// Existe pra que lista, seletor de cor e grade mostrem a mesma coisa: se a
/// amostra do seletor não parecer a célula da tabela, escolher cor vira chute.
class ItemSwatch extends StatelessWidget {
  const ItemSwatch({
    super.key,
    required this.cor,
    required this.densidade,
    this.texto,
    this.largura = 44,
    this.altura = 34,
  });

  final ItemColor cor;
  final ColorDensity densidade;

  /// Sigla ou rótulo curto. Sem texto, a amostra é só a cor.
  final String? texto;

  final double largura;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final style = resolveCellStyle(
      cor: cor,
      densidade: densidade,
      esquema: Theme.of(context).colorScheme,
    );

    return Container(
      width: largura,
      height: altura,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (style.hasAccent)
            Container(width: style.accentWidth, color: style.accent),
          if (texto != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  texto!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: style.foreground,
                  ),
                ),
              ),
            ),
          if (texto != null && style.hasAccent)
            SizedBox(width: style.accentWidth),
        ],
      ),
    );
  }
}
