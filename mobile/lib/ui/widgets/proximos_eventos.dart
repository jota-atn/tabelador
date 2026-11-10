import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/evento.dart';
import '../../state/app_state.dart';
import '../../util/formato_data.dart';
import '../calendario_screen.dart';
import 'evento_tile.dart';

/// "Esta semana" abaixo da grade: de agora até domingo. Fechada, mostra
/// só o próximo evento, como linha normal da lista, e um botão "Ver mais N
/// eventos da semana" embaixo; aberta, tudo agrupado por dia e "Mostrar só
/// o próximo". O estado é lembrado. "Mês" no cabeçalho abre o calendário —
/// separado do abrir/fechar, que antes dividia a mesma linha e confundia.
class ProximosEventos extends StatelessWidget {
  const ProximosEventos({super.key});

  /// Evento que já acabou não é "próximo"; dia todo vale até o fim do dia.
  static bool _naoPassou(Ocorrencia o, DateTime agora) =>
      o.evento.diaInteiro ||
      (o.fim.isAfter(o.inicio) ? o.fim.isAfter(agora) : !o.inicio.isBefore(agora));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final hoje = inicioDoDia(agora);
    // Segunda que vem, meia-noite: fim de "esta semana".
    final fimDaSemana = DateTime(hoje.year, hoje.month, hoje.day + (8 - hoje.weekday));
    final ocorrencias = state
        .ocorrenciasEntre(hoje, fimDaSemana)
        .where((o) => _naoPassou(o, agora))
        .toList();
    final aberta = state.semanaAberta;

    // Sábado e domingo: a semana está acabando, então vale apontar a próxima.
    final fimDeSemana = hoje.weekday >= DateTime.saturday;
    final proximaSemana = fimDeSemana
        ? state
            .ocorrenciasEntre(fimDaSemana, fimDaSemana.add(const Duration(days: 7)))
            .length
        : 0;

    final porDia = <DateTime, List<Ocorrencia>>{};
    for (final o in ocorrencias) {
      (porDia[inicioDoDia(o.inicio)] ??= []).add(o);
    }

    final primeiro = ocorrencias.isEmpty ? null : ocorrencias.first;
    final escondidos = ocorrencias.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabeçalho: só título e o atalho pro mês. Não abre nem fecha nada
        // — isso fica no botão explícito embaixo da lista.
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
          child: Row(
            children: [
              Text(
                'Esta semana',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface),
              ),
              if (ocorrencias.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${ocorrencias.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CalendarioScreen()),
                ),
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text('Mês'),
              ),
            ],
          ),
        ),
        if (primeiro == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Nada até domingo.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          )
        // Fechada: só o próximo, como linha inteira da lista.
        else if (!aberta || escondidos == 0)
          EventoTile(ocorrencia: primeiro)
        // Aberta: tudo, agrupado por dia.
        else
          for (final dia in porDia.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                dia.key == hoje || dia.key == hoje.add(const Duration(days: 1))
                    ? '${rotuloDoDia(dia.key, agora)} · ${diaMes(dia.key)}'
                    : rotuloDoDia(dia.key, agora),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dia.key == hoje ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final o in dia.value) EventoTile(ocorrencia: o, mostrarData: false),
          ],
        if (escondidos > 0)
          TextButton.icon(
            onPressed: state.alternarSemanaAberta,
            icon: Icon(aberta ? Icons.expand_less : Icons.expand_more),
            label: Text(
              aberta
                  ? 'Mostrar só o próximo'
                  : escondidos == 1
                      ? 'Ver mais 1 evento da semana'
                      : 'Ver mais $escondidos eventos da semana',
            ),
          ),
        if (proximaSemana > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CalendarioScreen()),
              ),
              child: Text('Próxima semana · $proximaSemana'),
            ),
          ),
      ],
    );
  }
}
