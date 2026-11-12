import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/evento.dart';
import '../../model/item.dart';
import '../../model/tabela.dart';
import '../../theme/color_density.dart';
import '../../util/eventos_na_grade.dart';
import '../../util/formato_data.dart';
import '../../util/horario_atual.dart' as horario_atual;
import 'folha_eventos.dart';
import 'item_swatch.dart';

/// A grade N×M em chrome neutro — a cara do projeto, o `fancy_grid` do script
/// virando UI. N colunas de acordo com [Tabela.dias], não fixo em 5.
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
    this.eventos,
    this.alturaLinha = 46,
  });

  final Tabela tabela;
  final ColorDensity densidade;
  final Item? Function(String? id) itemPorId;

  /// Recebe o nome do dia (de [Tabela.dias]).
  final void Function(String dia)? aoTocarDia;

  /// Recebe o nome do dia e o índice do slot.
  final void Function(String dia, int slot)? aoEditarCelula;

  /// Eventos da semana mostrada. Nulo = grade de molde puro (sem datas),
  /// como na tela de montar uma tabela; não-nulo = "esta semana", com data
  /// no cabeçalho e eventos por cima.
  final EventosDaSemana? eventos;

  final double alturaLinha;

  static const double _larguraHora = 46;
  static const double _alturaFaixa = 24;

  double get _alturaCabecalho => eventos == null ? 26 : 36;
  bool get _temFaixaDiaTodo => eventos?.temDiaTodo ?? false;
  bool get _temFaixaFora => eventos?.temForaDoHorario ?? false;

  /// Índice de hoje dentro de [dias], ou -1 se hoje não é um dos dias da
  /// tabela — não faz sentido apontar "hoje" pra uma coluna que não existe.
  static int indiceDeHoje(List<String> dias, [DateTime? agora]) =>
      horario_atual.indiceDeHoje(dias, agora);

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

    return _alturaCabecalho +
        (_temFaixaDiaTodo ? _alturaFaixa : 0) +
        fracao * (tabela.qtdHorarios * alturaLinha);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    // Hoje e "agora" só existem na semana atual (ou na grade de molde, sem
    // datas); noutra semana nenhuma coluna é hoje.
    final semanaAtual = eventos == null || eventos!.segunda == segundaDaSemana(agora);
    final hoje = semanaAtual ? indiceDeHoje(tabela.dias, agora) : -1;
    final slotAgora = semanaAtual ? _slotCorrente(agora) : -1;
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
                  SizedBox(height: _alturaCabecalho),
                  if (_temFaixaDiaTodo) _RotuloFaixa('dia todo', _alturaFaixa),
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
                  if (_temFaixaFora) _RotuloFaixa('outros', _alturaFaixa),
                ],
              ),
            ),
            for (var dia = 0; dia < tabela.dias.length; dia++) ...[
              // Fio fininho só entre dias — discreto o bastante pra não virar
              // o `fancy_grid` 100%-borda do script original, mas o
              // suficiente pra separar dois dias com cores parecidas coladas.
              if (dia > 0) Container(width: 1, color: scheme.outlineVariant),
              Expanded(
                child: GestureDetector(
                  onTap: aoTocarDia == null
                      ? null
                      : () => aoTocarDia!(tabela.dias[dia]),
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  kDiaAbreviado[tabela.dias[dia]]!,
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
                                if (eventos != null)
                                  Text(
                                    '${eventos!.dataDe(tabela.dias[dia]).day}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: dia == hoje
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: dia == hoje
                                          ? scheme.primary
                                          : scheme.onSurface,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (_temFaixaDiaTodo)
                          _Faixa(
                            ocorrencias: eventos!.diaTodo(tabela.dias[dia]),
                            altura: _alturaFaixa,
                            titulo:
                                'Dia todo · ${rotuloDoDia(eventos!.dataDe(tabela.dias[dia]), agora)}',
                          ),
                        for (var slot = 0; slot < tabela.qtdHorarios; slot++)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: aoEditarCelula == null
                                ? null
                                : () {
                                    unawaited(HapticFeedback.selectionClick());
                                    aoEditarCelula!(tabela.dias[dia], slot);
                                  },
                            onTap: _aoTocarCelula(
                              context,
                              tabela.dias[dia],
                              slot,
                              agora,
                            ),
                            child: SizedBox(
                              height: alturaLinha,
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                // Feriado de folga: as aulas do dia ficam
                                // esmaecidas — estão lá, mas não acontecem.
                                child: Opacity(
                                  opacity: eventos?.folga(tabela.dias[dia]) == null ? 1 : 0.3,
                                  child: _Celula(
                                    item: itemPorId(
                                      tabela.celula(tabela.dias[dia], slot),
                                    ),
                                    densidade: densidade,
                                    ocorrencias: eventos?.naCelula(
                                          tabela.dias[dia],
                                          slot,
                                        ) ??
                                        const [],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_temFaixaFora)
                          _Faixa(
                            ocorrencias: eventos!.foraDoHorario(tabela.dias[dia]),
                            altura: _alturaFaixa,
                            titulo:
                                'Fora do horário · ${rotuloDoDia(eventos!.dataDe(tabela.dias[dia]), agora)}',
                            mostrarHora: true,
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

extension on GradeSemana {
  /// Célula com evento: tocar abre a folha com item + eventos daquele
  /// horário. Sem evento, devolve null e o toque sobe pro dia inteiro, como
  /// sempre foi.
  VoidCallback? _aoTocarCelula(
    BuildContext context,
    String dia,
    int slot,
    DateTime agora,
  ) {
    final lista = eventos?.naCelula(dia, slot) ?? const <Ocorrencia>[];
    if (lista.isEmpty) return null;
    final data = eventos!.dataDe(dia);
    return () => abrirFolhaDeEventos(
          context,
          titulo: '${rotuloDoDia(data, agora)} · ${tabela.horarios[slot]}',
          ocorrencias: lista,
          item: itemPorId(tabela.celula(dia, slot)),
        );
  }
}

class _RotuloFaixa extends StatelessWidget {
  const _RotuloFaixa(this.texto, this.altura);

  final String texto;
  final double altura;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: altura,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 8.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Faixa fina de uma coluna — "dia todo" em cima, "fora do horário"
/// embaixo. Só existe na semana que tem evento assim (quem decide é
/// [GradeSemana]); coluna sem nada nela fica em branco.
class _Faixa extends StatelessWidget {
  const _Faixa({
    required this.ocorrencias,
    required this.altura,
    required this.titulo,
    this.mostrarHora = false,
  });

  final List<Ocorrencia> ocorrencias;
  final double altura;
  final String titulo;
  final bool mostrarHora;

  @override
  Widget build(BuildContext context) {
    if (ocorrencias.isEmpty) return SizedBox(height: altura);
    final primeiro = ocorrencias.first;
    final texto = ocorrencias.length > 1
        ? '${ocorrencias.length} eventos'
        : mostrarHora
            ? '${primeiro.inicio.hour}h ${primeiro.evento.titulo}'
            : primeiro.evento.titulo;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => abrirFolhaDeEventos(
        context,
        titulo: titulo,
        ocorrencias: ocorrencias,
      ),
      child: SizedBox(
        height: altura,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: _Fantasma(texto: texto),
        ),
      ),
    );
  }
}

class _Celula extends StatelessWidget {
  const _Celula({
    required this.item,
    required this.densidade,
    this.ocorrencias = const [],
  });

  final Item? item;
  final ColorDensity densidade;
  final List<Ocorrencia> ocorrencias;

  @override
  Widget build(BuildContext context) {
    final i = item;
    if (i == null) {
      // Slot vazio é espaço em branco, não card cinza — a não ser que tenha
      // evento, aí vira o "fantasma" tracejado.
      if (ocorrencias.isEmpty) return const SizedBox.shrink();
      return _Fantasma(
        texto: ocorrencias.length > 1
            ? '${ocorrencias.first.evento.titulo} +${ocorrencias.length - 1}'
            : ocorrencias.first.evento.titulo,
        linhas: 2,
      );
    }

    final swatch = ItemSwatch(
      cor: i.cor,
      densidade: densidade,
      texto: i.sigla,
      tamanhoTexto: 9.5,
      raio: 5,
    );
    if (ocorrencias.isEmpty) return swatch;

    // Item continua inteiro; o evento vira selo no canto. Vinculado a este
    // item (a prova de SO no horário de SO) ganha o "!", que diz "isto é
    // sobre esta aula"; qualquer outro é só um ponto.
    final estilo = resolveCellStyle(
      cor: i.cor,
      densidade: densidade,
      esquema: Theme.of(context).colorScheme,
    );
    final vinculado = ocorrencias.any((o) => o.evento.itemId == i.id);

    return Stack(
      fit: StackFit.expand,
      children: [
        swatch,
        Positioned(
          top: 2,
          right: 2,
          child: vinculado
              ? Container(
                  width: 13,
                  height: 13,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: estilo.foreground,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '!',
                    style: TextStyle(
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: estilo.background,
                    ),
                  ),
                )
              : Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: estilo.foreground,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Evento sem item embaixo: contorno tracejado e texto curto. Distingue de
/// item (que é preenchido) sem trazer cor nova pra grade.
class _Fantasma extends StatelessWidget {
  const _Fantasma({required this.texto, this.linhas = 1});

  final String texto;
  final int linhas;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _ContornoTracejado(scheme.outline),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            texto,
            maxLines: linhas,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8.5,
              height: 1.15,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContornoTracejado extends CustomPainter {
  _ContornoTracejado(this.cor);

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final caminho = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
          const Radius.circular(5),
        ),
      );
    for (final metrica in caminho.computeMetrics()) {
      var d = 0.0;
      while (d < metrica.length) {
        canvas.drawPath(metrica.extractPath(d, d + 3), paint);
        d += 6;
      }
    }
  }

  @override
  bool shouldRepaint(_ContornoTracejado old) => old.cor != cor;
}
