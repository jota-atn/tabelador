import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/color_density.dart';
import '../theme/item_palette.dart';
import 'widgets/item_swatch.dart';

/// Escolha da densidade de cor.
///
/// A escolha é feita por miniatura da própria grade, não por lista de texto:
/// o ponto de ser opção é ver o resultado antes de aplicar.
class AparenciaScreen extends StatelessWidget {
  const AparenciaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Aparência')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'DENSIDADE DE COR',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final densidade in ColorDensity.values) ...[
            _Opcao(
              densidade: densidade,
              selecionada: densidade == state.densidade,
              aoEscolher: () => state.definirDensidade(densidade),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Text(
            'Vale pro app e pro widget. A cor sempre identifica o item — '
            'a sigla continua visível em qualquer densidade.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.densidade,
    required this.selecionada,
    required this.aoEscolher,
  });

  final ColorDensity densidade;
  final bool selecionada;
  final VoidCallback aoEscolher;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: aoEscolher,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selecionada ? scheme.surfaceContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selecionada ? scheme.primary : scheme.outlineVariant,
            width: selecionada ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            _Miniatura(densidade: densidade),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    densidade.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    densidade.description,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selecionada
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selecionada ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Uma semana em miniatura, com a repetição e os vazios que a grade real tem.
class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.densidade});

  final ColorDensity densidade;

  static const List<List<ItemColor?>> _amostra = [
    [
      ItemColor.oceano,
      ItemColor.oliva,
      ItemColor.oceano,
      ItemColor.oliva,
      null,
    ],
    [
      ItemColor.turquesa,
      null,
      ItemColor.turquesa,
      ItemColor.ametista,
      ItemColor.ametista,
    ],
    [
      ItemColor.ambar,
      ItemColor.ambar,
      ItemColor.ambar,
      ItemColor.ambar,
      ItemColor.ambar,
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final linha in _amostra)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  for (final cor in linha)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: SizedBox(
                          height: 10,
                          child: cor == null
                              ? const SizedBox.shrink()
                              : ItemSwatch(
                                  cor: cor,
                                  densidade: densidade,
                                  raio: 2,
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
