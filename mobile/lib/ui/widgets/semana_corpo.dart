import 'package:flutter/material.dart';

import '../../model/item.dart';
import '../../model/tabela.dart';
import '../../theme/color_density.dart';
import 'grade_semana.dart';

/// Corpo compartilhado por Semana e pela tela dedicada de uma tabela: a
/// grade mais o toque de instrução embaixo.
///
/// A grade fica no tamanho compacto de sempre (altura de linha fixa) — só a
/// posição muda: [Center] dentro de [ConstrainedBox] reparte o espaço sobrando
/// entre topo e base em vez de empilhar tudo em cima e deixar uma faixa vazia
/// enorme até o menu debaixo. Tabela com mais horários do que cabe continua
/// rolando normalmente a partir do topo.
class SemanaCorpo extends StatelessWidget {
  const SemanaCorpo({
    super.key,
    required this.tabela,
    required this.densidade,
    required this.itemPorId,
    this.aoTocarDia,
    this.aoEditarCelula,
  });

  final Tabela tabela;
  final ColorDensity densidade;
  final Item? Function(String? id) itemPorId;
  final void Function(String dia)? aoTocarDia;
  final void Function(String dia, int slot)? aoEditarCelula;

  static const _padding = EdgeInsets.fromLTRB(10, 6, 10, 24);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final conteudo = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradeSemana(
          tabela: tabela,
          densidade: densidade,
          itemPorId: itemPorId,
          aoTocarDia: aoTocarDia,
          aoEditarCelula: aoEditarCelula,
        ),
        const SizedBox(height: 18),
        Text(
          'Toque num dia pra montar o horário',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: _padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - _padding.vertical,
            ),
            child: Center(child: conteudo),
          ),
        );
      },
    );
  }
}
