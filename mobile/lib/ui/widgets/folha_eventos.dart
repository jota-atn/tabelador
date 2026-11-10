import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/evento.dart';
import '../../model/item.dart';
import '../../state/app_state.dart';
import 'evento_tile.dart';
import 'item_swatch.dart';

/// Folha que abre ao tocar numa célula (ou faixa) da grade que tem evento:
/// o item daquele horário, se houver, e os eventos dele — é o "tocar abre os
/// detalhes" da decisão de manter o item visível com um selo.
Future<void> abrirFolhaDeEventos(
  BuildContext context, {
  required String titulo,
  required List<Ocorrencia> ocorrencias,
  Item? item,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final state = sheetContext.watch<AppState>();
      final scheme = Theme.of(sheetContext).colorScheme;
      // Lê de novo do estado: editar/apagar um evento a partir da folha
      // precisa refletir aqui sem fechar e abrir de novo.
      final atuais = [
        for (final o in ocorrencias)
          if (state.eventoPorId(o.evento.id) case final e?)
            Ocorrencia(e, o.inicio, o.inicio.add(e.duracao)),
      ];

      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          children: [
            Text(
              titulo,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (item != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  ItemSwatch(
                    cor: item.cor,
                    densidade: state.densidade,
                    texto: item.sigla,
                    largura: 56,
                    altura: 34,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      [item.nome, if (item.local != null) item.local!].join(' · '),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (atuais.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nenhum evento aqui.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            for (final o in atuais) EventoTile(ocorrencia: o),
          ],
        ),
      );
    },
  );
}
