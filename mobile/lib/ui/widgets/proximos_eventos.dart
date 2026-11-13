import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/evento.dart';
import '../../state/app_state.dart';
import '../../util/formato_data.dart';
import '../calendario_screen.dart';
import '../tarefas_screen.dart';
import 'evento_tile.dart';

/// "Esta semana" abaixo da grade: de agora até domingo. Fechada, mostra
/// só o próximo evento, como linha normal da lista, e um botão "Ver mais N
/// eventos da semana" embaixo; aberta, tudo agrupado por dia e "Mostrar só
/// o próximo". O estado é lembrado. "Mês" no cabeçalho abre o calendário —
/// separado do abrir/fechar, que antes dividia a mesma linha e confundia.
///
/// Tarefas: as que vencem na semana entram como qualquer evento (com
/// caixinha); concluída sai; atrasadas ficam sempre no topo, mesmo fechada.
/// "Tarefas" no cabeçalho abre a página de tarefas.
///
/// Acompanha a semana da grade ([segunda]): noutra semana o título vira
/// "Semana que vem"/"Semana de 23/11" e a lista traz a semana inteira, sem
/// atrasadas (que são sobre hoje).
class ProximosEventos extends StatelessWidget {
  const ProximosEventos({super.key, this.segunda});

  /// Segunda da semana mostrada; nulo = a atual.
  final DateTime? segunda;

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
    final segundaAtual = DateTime(hoje.year, hoje.month, hoje.day - (hoje.weekday - 1));
    final inicio = segunda ?? segundaAtual;
    final atual = inicio == segundaAtual;
    // Segunda seguinte, meia-noite: fim da semana mostrada.
    final fimDaSemana = DateTime(inicio.year, inicio.month, inicio.day + 7);
    final ocorrencias = atual
        ? state
            .ocorrenciasEntre(hoje, fimDaSemana)
            .where((o) => _naoPassou(o, agora) && !o.feita)
            .toList()
        : state.ocorrenciasEntre(inicio, fimDaSemana);
    final atrasadas = atual ? state.tarefasAtrasadas(agora) : const <Ocorrencia>[];
    final aberta = state.semanaAberta;

    // Sábado e domingo: a semana está acabando, então vale apontar a próxima.
    final fimDeSemana = atual && hoje.weekday >= DateTime.saturday;
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
                tituloDaSemana(inicio, agora),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface),
              ),
              if (ocorrencias.isNotEmpty || atrasadas.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${ocorrencias.length + atrasadas.length}',
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
                  MaterialPageRoute<void>(builder: (_) => const TarefasScreen()),
                ),
                icon: const Icon(Icons.task_alt, size: 18),
                label: const Text('Tarefas'),
              ),
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
        if (atrasadas.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              atrasadas.length == 1 ? 'Atrasada' : 'Atrasadas',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.error),
            ),
          ),
          for (final o in atrasadas) EventoTile(ocorrencia: o),
        ],
        if (primeiro == null && atrasadas.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              atual ? 'Nada até domingo.' : 'Nada nesta semana.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          )
        else if (primeiro == null)
          const SizedBox.shrink()
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
              onPressed: () => state.andarSemanas(1),
              child: Text('Próxima semana · $proximaSemana'),
            ),
          ),
      ],
    );
  }
}
