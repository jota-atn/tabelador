import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../model/evento.dart';

/// Ícone de cada tipo fixo — o mesmo na folha de criação, no card de
/// detalhes e nas listas.
IconData iconeDoTipo(TipoEvento t) => switch (t) {
      TipoEvento.tarefa => Icons.task_alt,
      TipoEvento.prova => Icons.quiz_outlined,
      TipoEvento.compromisso => Icons.handshake_outlined,
      TipoEvento.consulta => Symbols.stethoscope,
      TipoEvento.reuniao => Icons.groups_outlined,
      TipoEvento.viagem => Icons.flight_takeoff,
      TipoEvento.aniversario => Icons.cake_outlined,
      TipoEvento.feriado => Icons.celebration_outlined,
      TipoEvento.outro => Icons.event_outlined,
    };

/// Cor de cada tipo (paleta aprovada em 2026-11-11). No escuro, um tom mais
/// claro do mesmo matiz — o de dia some contra o fundo escuro.
Color corDoTipo(TipoEvento t, Brightness brilho) {
  final (claro, escuro) = switch (t) {
    TipoEvento.tarefa => (0xFF2E7D32, 0xFF81C784),
    TipoEvento.prova => (0xFFD84343, 0xFFF28B82),
    TipoEvento.compromisso => (0xFFEF6C00, 0xFFFFB74D),
    TipoEvento.consulta => (0xFF1E88E5, 0xFF64B5F6),
    TipoEvento.reuniao => (0xFF5E35B1, 0xFFB39DDB),
    TipoEvento.viagem => (0xFF00897B, 0xFF4DB6AC),
    TipoEvento.aniversario => (0xFFD81B60, 0xFFF48FB1),
    TipoEvento.feriado => (0xFFF9A825, 0xFFFFD54F),
    TipoEvento.outro => (0xFF607D8B, 0xFF90A4AE),
  };
  return Color(brilho == Brightness.dark ? escuro : claro);
}

/// Nome do tipo no plural, pra títulos ("Provas", "Reuniões").
String pluralDoTipo(TipoEvento t) => switch (t) {
      TipoEvento.tarefa => 'Tarefas',
      TipoEvento.prova => 'Provas',
      TipoEvento.compromisso => 'Compromissos',
      TipoEvento.consulta => 'Consultas',
      TipoEvento.reuniao => 'Reuniões',
      TipoEvento.viagem => 'Viagens',
      TipoEvento.aniversario => 'Aniversários',
      TipoEvento.feriado => 'Feriados',
      TipoEvento.outro => 'Outros',
    };
