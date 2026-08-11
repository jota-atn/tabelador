import 'package:flutter/material.dart';

import '../../theme/color_density.dart';
import '../../theme/item_palette.dart';

/// Amostra de uma cor de item, renderizada na densidade escolhida.
///
/// Usada na lista, no seletor de cor, nas células da grade e nas miniaturas da
/// tela de aparência. É de propósito: se a amostra do seletor não parecer a
/// célula da tabela, escolher cor vira chute.
///
/// Sem [largura] ou [altura] a amostra ocupa o espaço que o pai der.
class ItemSwatch extends StatelessWidget {
  const ItemSwatch({
    super.key,
    required this.cor,
    required this.densidade,
    this.texto,
    this.largura,
    this.altura,
    this.tamanhoTexto = 10,
    this.raio = 6,
  });

  final ItemColor cor;
  final ColorDensity densidade;

  /// Sigla ou rótulo curto. Sem texto, a amostra é só a cor.
  final String? texto;

  final double? largura;
  final double? altura;
  final double tamanhoTexto;
  final double raio;

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
        borderRadius: BorderRadius.circular(raio),
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
                    fontSize: tamanhoTexto,
                    fontWeight: FontWeight.w600,
                    color: style.foreground,
                  ),
                ),
              ),
            ),
          // Espelha a largura do filete, pra sigla ficar centralizada na célula
          // inteira e não no espaço que sobrou dele.
          if (texto != null && style.hasAccent)
            SizedBox(width: style.accentWidth),
        ],
      ),
    );
  }
}
