import 'package:flutter/material.dart';

import '../../model/item.dart';
import '../../model/tabela.dart';
import '../../theme/color_density.dart';
import '../../util/eventos_na_grade.dart';
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
    this.rodape,
    this.eventos,
    this.cabecalho,
  });

  final Tabela tabela;
  final ColorDensity densidade;
  final Item? Function(String? id) itemPorId;
  final void Function(String dia)? aoTocarDia;
  final void Function(String dia, int slot)? aoEditarCelula;

  /// Conteúdo extra abaixo da dica — a lista "Próximos" na tela inicial.
  final Widget? rodape;

  /// Ver [GradeSemana.eventos].
  final EventosDaSemana? eventos;

  /// Acima da grade — a barra de semanas na tela inicial.
  final Widget? cabecalho;

  // Com rodapé (tela inicial) há um FAB por cima — o fundo extra impede que
  // ele cubra a última linha da lista.
  EdgeInsets get _padding => EdgeInsets.fromLTRB(10, 6, 10, rodape == null ? 24 : 88);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final conteudo = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cabecalho != null) ...[cabecalho!, const SizedBox(height: 4)],
        GradeSemana(
          tabela: tabela,
          densidade: densidade,
          itemPorId: itemPorId,
          aoTocarDia: aoTocarDia,
          aoEditarCelula: aoEditarCelula,
          eventos: eventos,
        ),
        // A dica só serve enquanto não há nada montado.
        if (tabela.celulas.values.every((l) => l.every((c) => c == null))) ...[
          const SizedBox(height: 18),
          Text(
            'Toque num dia pra montar o horário',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
        if (rodape != null) ...[
          const SizedBox(height: 24),
          rodape!,
        ],
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
            // Com a lista embaixo (tela inicial) a grade fica presa no topo:
            // centralizar faria ela pular a cada semana com mais ou menos
            // eventos. Sem lista, centraliza como antes.
            child: rodape == null
                ? Center(child: conteudo)
                : Align(alignment: Alignment.topCenter, child: conteudo),
          ),
        );
      },
    );
  }
}
