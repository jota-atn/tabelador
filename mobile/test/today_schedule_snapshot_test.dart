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
    test('sem tabela ativa: sem aulas, sem estourar', () {
      final json = jsonDecode(
        construirSnapshotJson(
          tabelaAtiva: null,
          itemPorId: _itemPorId,
          densidade: ColorDensity.suave,
          claro: _claro,
          escuro: _escuro,
          agora: DateTime(2026, 8, 10, 9), // segunda
        ),
      );

      expect(json['hasClassesToday'], isFalse);
      expect(json['slots'], isEmpty);
      expect(json['dayLabel'], 'SEGUNDA');
    });

    test('fim de semana: sem aulas mesmo com tabela cheia', () {
      final tabela = Tabela.nova(nome: '2026.1').comCelula('SEGUNDA', 0, 'calc');

      final json = jsonDecode(
        construirSnapshotJson(
          tabelaAtiva: tabela,
          itemPorId: _itemPorId,
          densidade: ColorDensity.suave,
          claro: _claro,
          escuro: _escuro,
          agora: DateTime(2026, 8, 15, 9), // sábado
        ),
      );

      expect(json['hasClassesToday'], isFalse);
      expect(json['slots'], isEmpty);
      expect(json['dayLabel'], 'SÁBADO');
    });

    test('dia de semana com aula ocupada: monta o slot com cores resolvidas', () {
      final tabela = Tabela.nova(nome: '2026.1').comCelula('SEGUNDA', 0, 'calc');

      final json = jsonDecode(
        construirSnapshotJson(
          tabelaAtiva: tabela,
          itemPorId: _itemPorId,
          densidade: ColorDensity.suave,
          claro: _claro,
          escuro: _escuro,
          agora: DateTime(2026, 8, 10, 9), // segunda
        ),
      );

      expect(json['tableName'], '2026.1');
      expect(json['dayLabel'], 'SEGUNDA');
      expect(json['hasClassesToday'], isTrue);
      expect(json['slots'], hasLength(1));

      final slot = json['slots'][0] as Map<String, dynamic>;
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
          agora: DateTime(2026, 8, 10, 9),
        ),
      );

      expect(json['slots'][0]['barWidthDp'], 0);
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
          agora: DateTime(2026, 8, 10, 9),
        ),
      );

      expect(json['hasClassesToday'], isFalse);
      expect(json['slots'], isEmpty);
    });
  });
}
