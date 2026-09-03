import 'package:flutter/material.dart';

/// Limita a largura de formulários e listas de opção, centralizando o
/// resto — sem isso, um campo de texto ou uma linha de opção esticaria feio
/// até a borda numa tela larga (tablet, celular deitado).
///
/// Não se aplica a grade nem editor do dia: esses se beneficiam da largura
/// extra (mais coluna, mais item por linha), só formulário não.
class LarguraMaxima extends StatelessWidget {
  const LarguraMaxima({super.key, required this.child, this.largura = 560});

  final Widget child;
  final double largura;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largura),
        child: child,
      ),
    );
  }
}
