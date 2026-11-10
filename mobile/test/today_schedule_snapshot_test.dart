import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabelador/model/item.dart';
import 'package:tabelador/model/tabela.dart';
import 'package:tabelador/native_widget/today_schedule_snapshot.dart';
import 'package:tabelador/theme/color_density.dart';
import 'package:tabelador/theme/item_palette.dart';

ColorScheme _scheme(Brightness brightness) => ColorScheme.fromSeed(
      seedColor: const Color(0xFF3C5F92),
      brightness: brightness,
    );

final _claro = _scheme(Brightness.light);
final _escuro = _scheme(Brightness.dark);

final _calc = Item(
  id: 'calc',
  nome: 'Cálculo II',
  sigla: 'CALC',
  tipo: 'Aula',
  cor: ItemColor.oceano,
  local: 'Bloco C',
);

Item? _itemPorId(String? id) => id == 'calc' ? _calc : null;

void main() {
  group('construirSnapshotJson', () {
    test('sem tabela ativa: semana vazia, sem estourar', () {
      final json = jsonDecode(
        construirSnapshotJson(
          tabelaAtiva: null,
          itemPorId: _itemPorId,
          densidade: ColorDensity.suave,
          claro: _claro,
          escuro: _escuro,
        ),
      );

      expect(json['tableName'], '');
      expect(json['week'], isEmpty);
    });

    test('manda todos os dias da tabela, não só um', () {
      final tabela = Tabela.nova(nome: '2026.1').comCelula('SEGUNDA', 0, 'calc');

      final json = jsonDecode(
        construirSnapshotJson(
          tabelaAtiva: tabela,
          itemPorId: _itemPorId,
          densidade: ColorDensity.suave,
          claro: _claro,
          escuro: _escuro,
        ),
      );

      expect(json['tableName'], '2026.1');
      final week = json['week'] as Map<String, dynamic>;
      expect(week.keys.toSet(), tabela.dias.toSet());
      // Dias sem nada ocupado continuam presentes, só que vazios — quem
      // resolve "hoje" é o lado nativo, então todo dia da tabela precisa
      // estar no mapa mesmo sem aula.
      expect(week['TERÇA'], isEmpty);
    });

    test('dia com aula ocupada: monta o slot com cores resolvidas', () {
      final tabela = Tabela.nova(nome: '2026.1').comCelula('SEGUNDA', 0, 'calc');

      final json = jsonDecode(
        construirSnapshotJson(
          tabelaAtiva: tabela,
          itemPorId: _itemPorId,
          densidade: ColorDensity.suave,
          claro: _claro,
          escuro: _escuro,
        ),
      );

      final slots = json['week']['SEGUNDA'] as List<dynamic>;
      expect(slots, hasLength(1));

      final slot = slots[0] as Map<String, dynamic>;
      expect(slot['sigla'], 'CALC');
      expect(slot['tipo'], 'Aula');
      expect(slot['local'], 'Bloco C');
      expect(slot['time'], tabela.horarios[0]);
      for (final chave in [
        'bgLight',
        'bgDark',
        'fgLight',
        'fgDark',
        'barLight',
        'barDark',
      ]) {
        expect(slot[chave], matches(RegExp(r'^#[0-9A-F]{6}$')), reason: chave);
      }
      expect(slot['barWidthDp'], greaterThan(0)); // suave sempre tem fio
    });

    test('densidade sólido não manda filete', () {
      final tabela = Tabela.nova(nome: '2026.1').comCelula('SEGUNDA', 0, 'calc');

      final json = jsonDecode(
        construirSnapshotJson(
          tabelaAtiva: tabela,
          itemPorId: _itemPorId,
          densidade: ColorDensity.solido,
          claro: _claro,
          escuro: _escuro,
        ),
      );

      expect(json['week']['SEGUNDA'][0]['barWidthDp'], 0);
    });

    test('slot vazio não vira entrada no JSON', () {
      final tabela = Tabela.nova(nome: '2026.1'); // ninguém ocupou nada

      final json = jsonDecode(
        construirSnapshotJson(
          tabelaAtiva: tabela,
          itemPorId: _itemPorId,
          densidade: ColorDensity.suave,
          claro: _claro,
          escuro: _escuro,
        ),
      );

      for (final dia in tabela.dias) {
        expect(json['week'][dia], isEmpty);
      }
    });
  });
}
