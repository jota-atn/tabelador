import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/color_density.dart';
import '../theme/item_palette.dart';

/// Tela provisória da fase 2: renderiza uma semana de exemplo nas três
/// densidades pra validar a paleta no aparelho.
///
/// Não usa o modelo de dados real — ele só chega na fase 3. O que essa tela
/// prova é que `resolveCellStyle` produz combinações legíveis nos dois temas,
/// e que as 12 cores continuam distinguíveis numa célula de ~55dp.
class DensityLab extends StatelessWidget {
  const DensityLab({
    super.key,
    required this.onToggleBrightness,
    required this.monetDisponivel,
  });

  final VoidCallback onToggleBrightness;

  /// Se o sistema entregou um esquema de cores dinâmico. Falso significa que o
  /// tema está saindo da semente de fallback.
  final bool monetDisponivel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paleta e densidade'),
        actions: [
          IconButton(
            onPressed: onToggleBrightness,
            icon: Icon(
              scheme.brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: 'Alternar tema',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          _MonetProbe(disponivel: monetDisponivel),
          const SizedBox(height: 16),
          SegmentedButton<ColorDensity>(
            segments: [
              for (final d in ColorDensity.values)
                ButtonSegment(value: d, label: Text(d.label)),
            ],
            selected: {state.densidade},
            // Grava direto na preferência: fechar e reabrir o app tem que
            // lembrar da escolha.
            onSelectionChanged: (s) => state.definirDensidade(s.first),
          ),
          const SizedBox(height: 20),
          _WeekGrid(density: state.densidade),
          const SizedBox(height: 28),
          Text(
            'AS 12 CHAVES',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _PaletteStrip(density: state.densidade),
        ],
      ),
    );
  }
}

/// Mostra se o Monet chegou e qual acento o app está usando.
///
/// Existe porque "parece que não mudou nada" não distingue entre o sistema não
/// entregar cor dinâmica e a mudança ser sutil demais pra notar num container.
class _MonetProbe extends StatelessWidget {
  const _MonetProbe({required this.disponivel});

  final bool disponivel;

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                disponivel ? Icons.check_circle_outline : Icons.info_outline,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  disponivel
                      ? 'Cor dinâmica ativa'
                      : 'Cor dinâmica indisponível — usando a semente',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (nome, cor) in [
                ('primary', scheme.primary),
                ('secondary', scheme.secondary),
                ('tertiary', scheme.tertiary),
              ])
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 34,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: cor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nome,
                        style: TextStyle(
                          fontSize: 9,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _hex(cor),
                        style: TextStyle(
                          fontSize: 9,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Uma aula qualquer na grade de exemplo.
typedef _Slot = ({String sigla, ItemColor color});

_Slot _s(String sigla, ItemColor color) => (sigla: sigla, color: color);

const List<String> _dias = ['SEG', 'TER', 'QUA', 'QUI', 'SEX'];

/// Semana de exemplo. Repete ALMOÇO nos cinco dias de propósito: é a linha que
/// mostra como cada densidade se comporta quando um item ocupa a semana toda.
final List<(String, List<_Slot?>)> _semana = [
  ('08:00', [
    _s('CÁLC', ItemColor.oceano),
    _s('EDA', ItemColor.oliva),
    _s('CÁLC', ItemColor.oceano),
    _s('EDA', ItemColor.oliva),
    null,
  ]),
  ('10:00', [
    _s('FÍS I', ItemColor.turquesa),
    null,
    _s('FÍS I', ItemColor.turquesa),
    _s('BD', ItemColor.ametista),
    _s('BD', ItemColor.ametista),
  ]),
  ('12:00', [
    _s('ALM', ItemColor.ambar),
    _s('ALM', ItemColor.ambar),
    _s('ALM', ItemColor.ambar),
    _s('ALM', ItemColor.ambar),
    _s('ALM', ItemColor.ambar),
  ]),
  ('14:00', [
    _s('EDA', ItemColor.oliva),
    _s('IHC', ItemColor.framboesa),
    null,
    _s('IHC', ItemColor.framboesa),
    _s('MONIT', ItemColor.tomate),
  ]),
  ('16:00', [
    _s('MONIT', ItemColor.tomate),
    _s('P.O.O', ItemColor.indigo),
    _s('LIVRE', ItemColor.salvia),
    null,
    _s('LIVRE', ItemColor.salvia),
  ]),
  ('18:00', [
    null,
    null,
    _s('P.O.O', ItemColor.indigo),
    _s('CÁLC', ItemColor.oceano),
    null,
  ]),
];

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.density});

  final ColorDensity density;

  static const double _rowHeight = 46;
  static const double _timeWidth = 44;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Segunda a sexta são 1..5 em DateTime.weekday; fim de semana não destaca
    // coluna nenhuma.
    final weekday = DateTime.now().weekday;
    final todayIndex = weekday <= 5 ? weekday - 1 : -1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _timeWidth,
          child: Column(
            children: [
              const SizedBox(height: 24),
              for (final (hora, _) in _semana)
                SizedBox(
                  height: _rowHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      hora,
                      style: TextStyle(
                        fontSize: 10,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (var dia = 0; dia < _dias.length; dia++)
          Expanded(
            child: Container(
              decoration: dia == todayIndex
                  ? BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: Column(
                children: [
                  SizedBox(
                    height: 24,
                    child: Center(
                      child: Text(
                        _dias[dia],
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.6,
                          fontWeight: dia == todayIndex
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: dia == todayIndex
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  for (final (_, slots) in _semana)
                    SizedBox(
                      height: _rowHeight,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: _Cell(slot: slots[dia], density: density),
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

class _Cell extends StatelessWidget {
  const _Cell({required this.slot, required this.density});

  final _Slot? slot;
  final ColorDensity density;

  @override
  Widget build(BuildContext context) {
    final s = slot;
    // Slot vazio é espaço em branco, não card cinza.
    if (s == null) return const SizedBox.shrink();

    final style = resolveCellStyle(
      cor: s.color,
      densidade: density,
      esquema: Theme.of(context).colorScheme,
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (style.hasAccent)
            Container(width: style.accentWidth, color: style.accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                s.sigla,
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
          // Espelha a largura do filete do outro lado, pra sigla ficar
          // centralizada na célula inteira e não no espaço que sobrou dele.
          if (style.hasAccent) SizedBox(width: style.accentWidth),
        ],
      ),
    );
  }
}

class _PaletteStrip extends StatelessWidget {
  const _PaletteStrip({required this.density});

  final ColorDensity density;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in ItemColor.values)
          Builder(builder: (context) {
            final style = resolveCellStyle(
              cor: color,
              densidade: density,
              esquema: scheme,
            );
            return Container(
              width: 104,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (style.hasAccent)
                    Container(
                      width: style.accentWidth,
                      height: 38,
                      color: style.accent,
                    )
                  else
                    const SizedBox(width: 6, height: 38),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        color.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: style.foreground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
