import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/item.dart';
import '../../model/tabela.dart';
import '../../theme/color_density.dart';
import '../../util/horario_atual.dart' as horario_atual;
import 'item_swatch.dart';

/// Abreviações dos dias na largura de uma coluna de grade.
const List<String> kDiasCurtos = ['SEG', 'TER', 'QUA', 'QUI', 'SEX'];

/// A grade 5×N em chrome neutro — a cara do projeto, o `fancy_grid` do script
/// virando UI.
///
/// Só leitura no sentido de não arrastar: tocar num dia chama [aoTocarDia],
/// que abre o editor daquele dia inteiro; toque longo numa célula chama
/// [aoEditarCelula], que edita só aquela — um atalho pra não precisar entrar
/// no dia inteiro só pra mudar um horário.
class GradeSemana extends StatelessWidget {
  const GradeSemana({
    super.key,
    required this.tabela,
    required this.densidade,
    required this.itemPorId,
    this.aoTocarDia,
    this.aoEditarCelula,
    this.alturaLinha = 46,
  });

  final Tabela tabela;
  final ColorDensity densidade;
  final Item? Function(String? id) itemPorId;

  /// Recebe o nome do dia (de [kDias]).
  final void Function(String dia)? aoTocarDia;

  /// Recebe o nome do dia e o índice do slot.
  final void Function(String dia, int slot)? aoEditarCelula;

  final double alturaLinha;

  static const double _larguraHora = 46;
  static const double _alturaCabecalho = 26;

  /// Segunda a sexta são 1..5 em DateTime.weekday. No fim de semana nenhuma
  /// coluna é destacada — não faz sentido apontar "hoje" para um dia que a
  /// grade não tem.
  static int indiceDeHoje([DateTime? agora]) => horario_atual.indiceDeHoje(agora);

  /// Em qual faixa de horário estamos agora, ou -1 fora do expediente da
  /// tabela.
  int _slotCorrente(DateTime agora) => horario_atual.slotCorrente(tabela, agora);

  /// Posição vertical da linha do "agora", relativa ao topo da grade (depois
  /// do cabeçalho) — proporcional ao quanto do expediente já passou. Null
  /// fora do expediente da tabela ou num dia sem coluna (fim de semana).
  double? _topoLinhaDoAgora(DateTime agora, int hoje) {
    if (hoje < 0) return null;
    final totalMinutos = tabela.qtdHorarios * tabela.intervalo * 60;
    if (totalMinutos <= 0) return null;

    final minutosDesdeInicio =
        (agora.hour * 60 + agora.minute) - tabela.horaInicial * 60;
    final fracao = minutosDesdeInicio / totalMinutos;
    if (fracao < 0 || fracao > 1) return null;

    return _alturaCabecalho + fracao * (tabela.qtdHorarios * alturaLinha);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final hoje = indiceDeHoje(agora);
    final slotAgora = _slotCorrente(agora);
    final topoLinhaDoAgora = _topoLinhaDoAgora(agora, hoje);

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _larguraHora,
              child: Column(
                children: [
                  const SizedBox(height: _alturaCabecalho),
                  for (var slot = 0; slot < tabela.qtdHorarios; slot++)
                    SizedBox(
                      height: alturaLinha,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        // O horário corrente se marca no próprio rótulo, em peso
                        // e cor. Um ponto ao lado disputaria largura com o texto
                        // e estouraria assim que a fonte do sistema aumentasse.
                        child: Text(
                          '${tabela.horaInicial + slot * tabela.intervalo}:00',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: slot == slotAgora
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: slot == slotAgora
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (var dia = 0; dia < kDias.length; dia++) ...[
              // Fio fininho só entre dias — discreto o bastante pra não virar
              // o `fancy_grid` 100%-borda do script original, mas o
              // suficiente pra separar dois dias com cores parecidas coladas.
              if (dia > 0) Container(width: 1, color: scheme.outlineVariant),
              Expanded(
                child: GestureDetector(
                  onTap: aoTocarDia == null ? null : () => aoTocarDia!(kDias[dia]),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    // Destaque de hoje: neutro de propósito, pra não competir com
                    // a cor dos itens em nenhuma das três densidades.
                    decoration: dia == hoje
                        ? BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    child: Column(
                      children: [
                        SizedBox(
                          height: _alturaCabecalho,
                          child: Center(
                            child: Text(
                              kDiasCurtos[dia],
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.6,
                                fontWeight: dia == hoje
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: dia == hoje
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        for (var slot = 0; slot < tabela.qtdHorarios; slot++)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: aoEditarCelula == null
                                ? null
                                : () {
                                    unawaited(HapticFeedback.selectionClick());
                                    aoEditarCelula!(kDias[dia], slot);
                                  },
                            child: SizedBox(
                              height: alturaLinha,
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: _Celula(
                                  item: itemPorId(tabela.celula(kDias[dia], slot)),
                                  densidade: densidade,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (topoLinhaDoAgora != null)
          Positioned(
            top: topoLinhaDoAgora,
            left: _larguraHora,
            right: 0,
            child: IgnorePointer(
              child: Container(height: 2, color: scheme.primary.withValues(alpha: 0.7)),
            ),
          ),
      ],
    );
  }
}

class _Celula extends StatelessWidget {
  const _Celula({required this.item, required this.densidade});

  final Item? item;
  final ColorDensity densidade;

  @override
  Widget build(BuildContext context) {
    final i = item;
    // Slot vazio é espaço em branco, não card cinza.
    if (i == null) return const SizedBox.shrink();

    return ItemSwatch(
      cor: i.cor,
      densidade: densidade,
      texto: i.sigla,
      tamanhoTexto: 9.5,
      raio: 5,
    );
  }
}
