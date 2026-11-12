import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../state/app_state.dart';

/// Conclui (ou reabre) e mostra o "Desfazer" — o mesmo gesto em todo lugar
/// onde há caixinha de tarefa.
Future<void> marcarTarefa(BuildContext context, Ocorrencia o, bool feita) async {
  final state = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  await state.marcarFeita(o, feita);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(feita ? '${o.evento.titulo} concluída' : '${o.evento.titulo} reaberta'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () {
            final atual = state.eventoPorId(o.evento.id);
            if (atual != null) {
              state.marcarFeita(Ocorrencia(atual, o.inicio, o.fim), !feita);
            }
          },
        ),
      ),
    );
}

/// Apaga e oferece "Desfazer" (que restaura igual, inclusive a cópia no
/// Google).
Future<void> apagarTarefas(BuildContext context, List<Evento> eventos) async {
  if (eventos.isEmpty) return;
  final state = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  for (final e in eventos) {
    await state.removerEvento(e.id);
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          eventos.length == 1 ? '${eventos.first.titulo} apagada' : '${eventos.length} tarefas apagadas',
        ),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () async {
            for (final e in eventos) {
              await state.restaurarEvento(e);
            }
          },
        ),
      ),
    );
}
