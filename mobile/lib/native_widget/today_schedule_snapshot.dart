import 'dart:convert';

import 'package:flutter/material.dart';

import '../model/item.dart';
import '../model/tabela.dart';
import '../theme/color_density.dart';
import '../util/horario_atual.dart';

/// Nome completo do dia pelo `DateTime.weekday` (1=segunda .. 7=domingo).
///
/// Cobre o fim de semana também, ao contrário de [kDias]: o widget precisa de
/// um rótulo mesmo nos dias em que a grade não tem coluna.
const List<String> kNomesDiasCompletos = [
  'SEGUNDA',
  'TERÇA',
  'QUARTA',
  'QUINTA',
  'SEXTA',
  'SÁBADO',
  'DOMINGO',
];

/// Monta o JSON enviado ao widget nativo (`today_schedule_json`) a partir da
/// tabela ativa, densidade e os dois esquemas de cor (claro/escuro).
///
/// Pura de propósito: não toca em `AppState` nem no plugin `home_widget` —
/// quem manda pro nativo é [HomeWidgetSync]. Reaproveita [resolveCellStyle], o
/// mesmo ponto de reuso que a grade, o editor e a tela de aparência já usam,
/// pra que o widget nunca pareça estar numa densidade diferente do app.
String construirSnapshotJson({
  required Tabela? tabelaAtiva,
  required Item? Function(String? id) itemPorId,
  required ColorDensity densidade,
  required ColorScheme claro,
  required ColorScheme escuro,
  DateTime? agora,
}) {
  final momento = agora ?? DateTime.now();
  final dayLabel = kNomesDiasCompletos[momento.weekday - 1];
  final hoje = indiceDeHoje(momento);

  final slots = <Map<String, dynamic>>[];
  if (tabelaAtiva != null && hoje >= 0) {
    final dia = kDias[hoje];
    for (var slot = 0; slot < tabelaAtiva.qtdHorarios; slot++) {
      final item = itemPorId(tabelaAtiva.celula(dia, slot));
      if (item == null) continue;

      final estiloClaro = resolveCellStyle(
        cor: item.cor,
        densidade: densidade,
        esquema: claro,
      );
      final estiloEscuro = resolveCellStyle(
        cor: item.cor,
        densidade: densidade,
        esquema: escuro,
      );

      slots.add({
        'time': tabelaAtiva.horarios[slot],
        'sigla': item.sigla,
        'tipo': item.tipo,
        if (item.local != null) 'local': item.local,
        'bgLight': _hex(estiloClaro.background),
        'bgDark': _hex(estiloEscuro.background),
        'fgLight': _hex(estiloClaro.foreground),
        'fgDark': _hex(estiloEscuro.foreground),
        'barLight': _hex(estiloClaro.accent),
        'barDark': _hex(estiloEscuro.accent),
        'barWidthDp': estiloClaro.accentWidth.round(),
      });
    }
  }

  return jsonEncode({
    'tableName': tabelaAtiva?.nome ?? '',
    'dayLabel': dayLabel,
    'hasClassesToday': slots.isNotEmpty,
    'slots': slots,
  });
}

/// [Color]'s `.r`/`.g`/`.b` são componentes de ponto flutuante em 0.0..1.0
/// (API de cor ampla do Flutter) — precisa escalar pra 0..255 antes de virar
/// hex.
String _hex(Color c) {
  final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b'.toUpperCase();
}
