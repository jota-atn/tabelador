import 'dart:convert';

import 'package:flutter/material.dart';

import '../model/evento.dart';
import '../model/item.dart';
import '../model/tabela.dart';
import '../theme/color_density.dart';
import '../util/eventos_na_grade.dart';

/// Monta o JSON enviado ao widget nativo (`today_schedule_json`) a partir da
/// tabela ativa, densidade e os dois esquemas de cor (claro/escuro).
///
/// Pura de propósito: não toca em `AppState` nem no plugin `home_widget` —
/// quem manda pro nativo é [HomeWidgetSync]. Reaproveita [resolveCellStyle], o
/// mesmo ponto de reuso que a grade, o editor e a tela de aparência já usam,
/// pra que o widget nunca pareça estar numa densidade diferente do app.
///
/// Manda a **semana inteira**, não só "hoje": resolver qual dia é hoje fica
/// pro lado nativo (`TodayScheduleWidget.kt`), na hora de desenhar — se o
/// snapshot só carregasse o dia já resolvido, o widget ficaria preso nesse
/// dia até o Flutter rodar de novo (abrir o app, alguma mutação de estado).
/// Como o Android redesenha o widget sozinho a cada `updatePeriodMillis` sem
/// acionar o Flutter, um snapshot "de hoje" baked-in vira widget mostrando
/// terça-feira numa quinta se o app ficar dias sem abrir.
String construirSnapshotJson({
  required Tabela? tabelaAtiva,
  required Item? Function(String? id) itemPorId,
  required ColorDensity densidade,
  required ColorScheme claro,
  required ColorScheme escuro,
  List<Ocorrencia> ocorrencias = const [],
}) {
  final week = <String, dynamic>{};
  if (tabelaAtiva != null) {
    for (final dia in tabelaAtiva.dias) {
      final slots = <Map<String, dynamic>>[];
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
      week[dia] = slots;
    }
  }

  // Eventos vão com data absoluta (não por dia da semana, como os itens):
  // o nativo filtra pelos de hoje na hora de desenhar. O chamador manda uma
  // janela de alguns dias pra frente, pra o widget continuar certo mesmo
  // sem o app abrir por um tempo.
  final events = <Map<String, dynamic>>[
    for (final o in ocorrencias)
      if (tabelaAtiva == null || eventoVisivelNaTabela(tabelaAtiva, o.evento))
        _evento(o, itemPorId(o.evento.itemId), claro, escuro),
  ];

  return jsonEncode({
    'tableName': tabelaAtiva?.nome ?? '',
    'week': week,
    'events': events,
  });
}

String _doisDigitos(int n) => n.toString().padLeft(2, '0');

Map<String, dynamic> _evento(
  Ocorrencia o,
  Item? item,
  ColorScheme claro,
  ColorScheme escuro,
) {
  final i = o.inicio;
  final f = o.fim;
  return {
    'date': '${i.year}-${_doisDigitos(i.month)}-${_doisDigitos(i.day)}',
    'allDay': o.evento.diaInteiro,
    // Minutos desde meia-noite — o nativo ordena e compara com "agora" sem
    // precisar parsear hora.
    'startMin': i.hour * 60 + i.minute,
    'endMin': f.isAfter(i) ? f.hour * 60 + f.minute : i.hour * 60 + i.minute,
    'time': o.evento.diaInteiro
        ? 'Dia todo'
        : f.isAfter(i)
            ? '${_doisDigitos(i.hour)}:${_doisDigitos(i.minute)}–${_doisDigitos(f.hour)}:${_doisDigitos(f.minute)}'
            : '${_doisDigitos(i.hour)}:${_doisDigitos(i.minute)}',
    'title': o.evento.titulo,
    if (item != null) 'sigla': item.sigla,
    'local': ?(o.evento.local ?? item?.local),
    // Barra lateral: cor do item vinculado, ou neutra pra evento avulso.
    'barLight': _hex(item?.cor.tone(40) ?? _corExterna(o.evento) ?? claro.outline),
    'barDark': _hex(item?.cor.tone(80) ?? _corExterna(o.evento) ?? escuro.outline),
  };
}

/// Cor da agenda do Google de onde o evento veio, se for externo.
Color? _corExterna(Evento e) => e.corExterna == null ? null : Color(e.corExterna!);

/// [Color]'s `.r`/`.g`/`.b` são componentes de ponto flutuante em 0.0..1.0
/// (API de cor ampla do Flutter) — precisa escalar pra 0..255 antes de virar
/// hex.
String _hex(Color c) {
  final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b'.toUpperCase();
}
