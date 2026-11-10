import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../util/formato_data.dart';
import '../calendario_screen.dart';
import 'evento_tile.dart';

/// Quantos dias à frente a lista "Próximos" alcança.
const int kDiasProximos = 14;

/// Lista "Próximos" abaixo da grade na tela inicial: tudo que acontece nos
/// próximos [kDiasProximos] dias, inclusive o que não tem lugar na grade
/// (fora do horário da tabela, dia que ela não tem).
class ProximosEventos extends StatelessWidget {
  const ProximosEventos({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final hoje = inicioDoDia(agora);
    final ocorrencias = state
        .ocorrenciasEntre(hoje, hoje.add(const Duration(days: kDiasProximos)))
        // Evento de hoje que já terminou não é mais "próximo". Dia inteiro
        // fica até o fim do dia.
        .where((o) =>
            o.evento.diaInteiro ||
            (o.fim.isAfter(o.inicio)
                ? o.fim.isAfter(agora)
                : !o.inicio.isBefore(agora)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Próximos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CalendarioScreen()),
                ),
                child: const Text('Ver mês'),
              ),
            ],
          ),
        ),
        if (ocorrencias.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Nada nos próximos $kDiasProximos dias.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          )
        else
          for (final o in ocorrencias) EventoTile(ocorrencia: o),
      ],
    );
  }
}
