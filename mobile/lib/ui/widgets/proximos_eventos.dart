import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/evento.dart';
import '../../state/app_state.dart';
import '../../theme/tipo_evento_visual.dart';
import '../../util/formato_data.dart';
import '../calendario_screen.dart';
import '../tarefas_screen.dart';
import 'evento_tile.dart';

/// Quantas linhas o resumo abaixo da grade mostra, somando tarefas e
/// eventos. O resumo nunca cresce dentro da tela: o resto fica na folha
/// "Ver a semana toda". Provisório — o usuário está testando o tamanho.
const int kLinhasDoResumo = 6;

/// Quantas dessas linhas são de tarefas quando também há eventos. Sem
/// eventos, as tarefas ficam com o espaço todo (e vice-versa).
const int kTarefasNoResumo = 2;

/// O que a semana [segunda] tem pra mostrar: tarefas pendentes (atrasadas
/// primeiro) e eventos, cada um em ordem de início.
class _Semana {
  _Semana(AppState state, DateTime? segunda, this.agora) {
    hoje = inicioDoDia(agora);
    final segundaAtual = DateTime(hoje.year, hoje.month, hoje.day - (hoje.weekday - 1));
    inicio = segunda ?? segundaAtual;
    atual = inicio == segundaAtual;
    final fim = DateTime(inicio.year, inicio.month, inicio.day + 7);
    final ocorrencias = atual
        ? state.ocorrenciasEntre(hoje, fim).where((o) => _naoPassou(o, agora) && !o.feita).toList()
        : state.ocorrenciasEntre(inicio, fim);
    atrasadas = atual ? state.tarefasAtrasadas(agora) : const [];
    tarefas = [...atrasadas, ...ocorrencias.where((o) => o.evento.ehTarefa)];
    eventos = ocorrencias.where((o) => !o.evento.ehTarefa).toList();
    proximaSemana = atual && hoje.weekday >= DateTime.saturday
        ? state.ocorrenciasEntre(fim, fim.add(const Duration(days: 7))).length
        : 0;
  }

  final DateTime agora;
  late final DateTime hoje;
  late final DateTime inicio;
  late final bool atual;
  late final List<Ocorrencia> atrasadas;
  late final List<Ocorrencia> tarefas;
  late final List<Ocorrencia> eventos;
  late final int proximaSemana;

  int get total => tarefas.length + eventos.length;

  static bool _naoPassou(Ocorrencia o, DateTime agora) =>
      o.evento.diaInteiro ||
      (o.fim.isAfter(o.inicio) ? o.fim.isAfter(agora) : !o.inicio.isBefore(agora));

  /// "1 atrasada · 3 hoje · 2 na semana".
  String resumoDasTarefas() {
    final deHoje = tarefas
        .where((o) => !atrasadas.contains(o) && atual && inicioDoDia(o.inicio) == hoje)
        .length;
    final resto = tarefas.length - atrasadas.length - deHoje;
    return [
      if (atrasadas.isNotEmpty) '${atrasadas.length} ${atrasadas.length == 1 ? 'atrasada' : 'atrasadas'}',
      if (deHoje > 0) '$deHoje hoje',
      if (resto > 0) '$resto na semana',
    ].join(' · ');
  }
}

class ProximosEventos extends StatelessWidget {
  const ProximosEventos({super.key, this.segunda});

  final DateTime? segunda;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final semana = _Semana(state, segunda, DateTime.now());

    // Orçamento: tarefas pegam até kTarefasNoResumo, eventos o resto; o que
    // um lado não usa vai pro outro.
    var nTarefas = min(semana.tarefas.length, kTarefasNoResumo);
    final nEventos = min(semana.eventos.length, kLinhasDoResumo - nTarefas);
    nTarefas = min(semana.tarefas.length, kLinhasDoResumo - nEventos);
    final escondidos = semana.total - nTarefas - nEventos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
          child: Row(
            children: [
              Text(
                tituloDaSemana(semana.inicio, semana.agora),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface),
              ),
              if (semana.total > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${semana.total}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Com tarefas na semana, o cabeçalho do bloco já leva pra elas.
              if (semana.tarefas.isEmpty)
                TextButton.icon(
                  onPressed: () => _abrirTarefas(context),
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
        if (semana.total == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              semana.atual ? 'Nada até domingo.' : 'Nada nesta semana.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
        if (semana.tarefas.isNotEmpty) ...[
          _CabecalhoTarefas(texto: semana.resumoDasTarefas()),
          for (final o in semana.tarefas.take(nTarefas)) EventoTile(ocorrencia: o, colorido: true),
        ],
        ..._eventosPorDia(semana, semana.eventos.take(nEventos).toList(), scheme),
        if (escondidos > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _abrirSemanaToda(context, segunda),
              icon: const Icon(Icons.expand_less),
              label: Text('Ver a semana toda · +$escondidos'),
            ),
          ),
        if (semana.proximaSemana > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => state.andarSemanas(1),
              child: Text('Próxima semana · ${semana.proximaSemana}'),
            ),
          ),
      ],
    );
  }
}

void _abrirTarefas(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TarefasScreen()),
    );

/// Eventos agrupados por dia, com cabeçalho ("Hoje · 13 nov", "Sáb").
List<Widget> _eventosPorDia(_Semana semana, List<Ocorrencia> eventos, ColorScheme scheme) {
  final porDia = <DateTime, List<Ocorrencia>>{};
  final comeco = semana.atual ? semana.hoje : semana.inicio;
  for (final o in eventos) {
    final dia = inicioDoDia(o.inicio);
    (porDia[dia.isBefore(comeco) ? comeco : dia] ??= []).add(o);
  }
  final hoje = semana.hoje;
  return [
    for (final dia in porDia.entries) ...[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
        child: Text(
          dia.key == hoje || dia.key == hoje.add(const Duration(days: 1))
              ? '${rotuloDoDia(dia.key, semana.agora)} · ${diaMes(dia.key)}'
              : rotuloDoDia(dia.key, semana.agora),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: dia.key == hoje ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
      for (final o in dia.value) EventoTile(ocorrencia: o, mostrarData: false, colorido: true),
    ],
  ];
}

/// "Tarefas · 1 atrasada · 3 hoje  ›" — tocar abre a página de Tarefas.
class _CabecalhoTarefas extends StatelessWidget {
  const _CabecalhoTarefas({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cor = corDoTipo(TipoEvento.tarefa, scheme.brightness);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _abrirTarefas(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        child: Row(
          children: [
            Icon(Icons.task_alt, size: 16, color: cor),
            const SizedBox(width: 6),
            Text('Tarefas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cor)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// A semana inteira numa folha por cima da tela; a rolagem fica nela.
Future<void> _abrirSemanaToda(BuildContext context, DateTime? segunda) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controle) {
        final state = context.watch<AppState>();
        final scheme = Theme.of(context).colorScheme;
        final semana = _Semana(state, segunda, DateTime.now());
        return ListView(
          controller: controle,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              tituloDaSemana(semana.inicio, semana.agora),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (semana.tarefas.isNotEmpty) ...[
              _CabecalhoTarefas(texto: semana.resumoDasTarefas()),
              for (final o in semana.tarefas) EventoTile(ocorrencia: o, colorido: true),
            ],
            ..._eventosPorDia(semana, semana.eventos, scheme),
            if (semana.total == 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Nada nesta semana.', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
          ],
        );
      },
    ),
  );
}
