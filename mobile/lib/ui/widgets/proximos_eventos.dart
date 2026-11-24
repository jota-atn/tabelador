import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/evento.dart';
import '../../state/app_state.dart';
import '../../util/formato_data.dart';
import '../calendario_screen.dart';
import '../tarefas_screen.dart';
import 'evento_tile.dart';

/// Quantos eventos o resumo abaixo da grade mostra. O resumo nunca cresce
/// dentro da tela: o resto fica na folha "Ver a semana toda". Provisório —
/// o usuário está testando o tamanho. Tarefas não entram (têm a página
/// delas, pelo botão "Tarefas").
const int kLinhasDoResumo = 6;

/// Abrir/fechar a lista de eventos do resumo.
const _kAnimacao = Duration(milliseconds: 300);

/// Os eventos que a semana [segunda] tem pra mostrar, em ordem de início
/// (tarefas ficam de fora).
class _Semana {
  _Semana(AppState state, DateTime? segunda, this.agora) {
    hoje = inicioDoDia(agora);
    final segundaAtual = DateTime(hoje.year, hoje.month, hoje.day - (hoje.weekday - 1));
    inicio = segunda ?? segundaAtual;
    atual = inicio == segundaAtual;
    final fim = DateTime(inicio.year, inicio.month, inicio.day + 7);
    final ocorrencias = atual
        ? state.ocorrenciasEntre(hoje, fim).where((o) => _naoPassou(o, agora))
        : state.ocorrenciasEntre(inicio, fim);
    eventos = ocorrencias.where((o) => !o.evento.ehTarefa).toList();
    proximaSemana = atual && hoje.weekday >= DateTime.saturday
        ? state
            .ocorrenciasEntre(fim, fim.add(const Duration(days: 7)))
            .where((o) => !o.evento.ehTarefa)
            .length
        : 0;
  }

  final DateTime agora;
  late final DateTime hoje;
  late final DateTime inicio;
  late final bool atual;
  late final List<Ocorrencia> eventos;
  late final int proximaSemana;

  int get total => eventos.length;

  static bool _naoPassou(Ocorrencia o, DateTime agora) =>
      o.evento.diaInteiro ||
      (o.fim.isAfter(o.inicio) ? o.fim.isAfter(agora) : !o.inicio.isBefore(agora));
}

class ProximosEventos extends StatelessWidget {
  const ProximosEventos({super.key, this.segunda});

  final DateTime? segunda;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final semana = _Semana(state, segunda, DateTime.now());

    final ocultos = state.eventosDoResumoOcultos && semana.eventos.isNotEmpty;
    final nEventos = ocultos ? 0 : min(semana.eventos.length, kLinhasDoResumo);
    final escondidos = ocultos ? 0 : semana.eventos.length - nEventos;

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
        if (semana.eventos.isNotEmpty)
          _CabecalhoEventos(
            // Chaves fixas: o que vem abaixo muda ao recolher ("Ver a semana
            // toda" some), e sem elas o Flutter recriaria os dois (e a
            // animação não rodaria).
            key: const ValueKey('cabecalho-eventos'),
            quantos: semana.eventos.length,
            ocultos: ocultos,
            aoTocar: () => state.definirEventosDoResumoOcultos(!ocultos),
          ),
        // Abre e fecha deslizando; recolhido, a lista some de vez.
        AnimatedSize(
          key: const ValueKey('lista-eventos'),
          duration: _kAnimacao,
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _eventosPorDia(semana, semana.eventos.take(nEventos).toList(), scheme),
          ),
        ),
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

/// "Eventos  5  (⌃)" — tocar recolhe e mostra os eventos do resumo; a
/// seta gira junto.
class _CabecalhoEventos extends StatelessWidget {
  const _CabecalhoEventos({super.key, required this.quantos, required this.ocultos, required this.aoTocar});

  final int quantos;
  final bool ocultos;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 0, 6),
          child: Row(
            children: [
              Icon(Icons.event, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Eventos',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface),
              ),
              const SizedBox(width: 8),
              Text(
                '$quantos',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
                child: AnimatedRotation(
                  turns: ocultos ? 0.5 : 0,
                  duration: _kAnimacao,
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.expand_less,
                    size: 24,
                    color: scheme.onSecondaryContainer,
                    semanticLabel: ocultos ? 'Mostrar eventos' : 'Ocultar eventos',
                  ),
                ),
              ),
            ],
          ),
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
