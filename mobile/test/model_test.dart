import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabelador/model/item.dart';
import 'package:tabelador/model/tabela.dart';
import 'package:tabelador/theme/item_palette.dart';

void main() {
  group('Item', () {
    test('ida e volta pelo JSON preserva tudo', () {
      final original = Item(
        id: 'abc',
        nome: 'Cálculo Diferencial e Integral II',
        sigla: 'CÁLC II',
        tipo: 'Aula',
        cor: ItemColor.oceano,
        local: 'Bloco C, 204',
        notas: 'prova dia 12',
      );

      expect(Item.fromJson(jsonDecode(jsonEncode(original.toJson()))), original);
    });

    test('campos opcionais nulos não viram chave no JSON', () {
      final item = Item.novo(nome: 'Livre', sigla: 'LIVRE');
      final json = item.toJson();

      expect(json.containsKey('local'), isFalse);
      expect(json.containsKey('notas'), isFalse);
    });

    test('JSON de versão antiga não derruba a leitura', () {
      // Só o nome: sem sigla, sem tipo, sem cor.
      final item = Item.fromJson({'id': 'x', 'nome': 'Alguma coisa'});

      expect(item.nome, 'Alguma coisa');
      expect(item.sigla, '');
      expect(item.cor, ItemColor.grafite);
    });

    test('itens novos recebem ids distintos', () {
      final ids = {
        for (var i = 0; i < 200; i++) Item.novo(nome: 'x', sigla: 'x').id,
      };
      expect(ids.length, 200);
    });
  });

  group('Tabela', () {
    test('os horários seguem a mesma lógica do script Python', () {
      final t = Tabela.nova(nome: '2026.1');
      expect(t.horarios.first, '8:00-10:00');
      expect(t.horarios.last, '18:00-20:00');
      expect(t.horarios.length, 6);
    });

    test('hora inicial e intervalo customizados', () {
      final t = Tabela.nova(
        nome: 'Academia',
        horaInicial: 18,
        intervalo: 1,
        qtdHorarios: 3,
      );
      expect(t.horarios, ['18:00-19:00', '19:00-20:00', '20:00-21:00']);
    });

    test('a grade nasce completa, com todos os dias e slots', () {
      final t = Tabela.nova(nome: 'x', qtdHorarios: 4);
      expect(t.celulas.keys.toSet(), kDias.toSet());
      for (final dia in kDias) {
        expect(t.celulas[dia]!.length, 4);
        expect(t.celulas[dia]!.every((c) => c == null), isTrue);
      }
    });

    test('comCelula não altera a tabela original', () {
      final antes = Tabela.nova(nome: 'x');
      final depois = antes.comCelula('QUARTA', 2, 'item-1');

      expect(antes.celula('QUARTA', 2), isNull);
      expect(depois.celula('QUARTA', 2), 'item-1');
    });

    test('dia ou slot inválido é ignorado em vez de estourar', () {
      final t = Tabela.nova(nome: 'x');
      expect(t.comCelula('DOMINGO', 0, 'i'), same(t));
      expect(t.comCelula('QUARTA', 99, 'i'), same(t));
      expect(t.celula('DOMINGO', 0), isNull);
    });

    test('conta e remove usos de um item', () {
      var t = Tabela.nova(nome: 'x');
      t = t.comCelula('SEGUNDA', 0, 'a');
      t = t.comCelula('QUARTA', 0, 'a');
      t = t.comCelula('SEXTA', 1, 'b');

      expect(t.usosDe('a'), 2);
      expect(t.usosDe('b'), 1);

      final limpa = t.semItem('a');
      expect(limpa.usosDe('a'), 0);
      expect(limpa.usosDe('b'), 1);
    });

    test('aumentar a quantidade de horários preenche com vazio', () {
      var t = Tabela.nova(nome: 'x', qtdHorarios: 3);
      t = t.comCelula('SEGUNDA', 0, 'a');

      final maior = t.copyWith(qtdHorarios: 6);
      expect(maior.celulas['SEGUNDA']!.length, 6);
      expect(maior.celula('SEGUNDA', 0), 'a');
      expect(maior.celula('SEGUNDA', 5), isNull);
    });

    test('diminuir avisa quantas células seriam perdidas antes de truncar', () {
      var t = Tabela.nova(nome: 'x', qtdHorarios: 6);
      t = t.comCelula('SEGUNDA', 5, 'a');
      t = t.comCelula('TERÇA', 4, 'b');
      t = t.comCelula('QUARTA', 0, 'c');

      // Nada se perde acima do corte.
      expect(t.celulasPerdidasAo(6), 0);
      expect(t.celulasPerdidasAo(5), 1);
      expect(t.celulasPerdidasAo(4), 2);

      final menor = t.copyWith(qtdHorarios: 4);
      expect(menor.celulas['SEGUNDA']!.length, 4);
      expect(menor.celula('QUARTA', 0), 'c');
    });

    test('ida e volta pelo JSON preserva a grade', () {
      var original = Tabela.nova(nome: '2026.1');
      original = original.comCelula('QUINTA', 3, 'item-9');

      final voltou = Tabela.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(voltou.id, original.id);
      expect(voltou.nome, original.nome);
      expect(voltou.qtdHorarios, original.qtdHorarios);
      expect(voltou.celula('QUINTA', 3), 'item-9');
      expect(voltou.horarios, original.horarios);
    });

    test('JSON com grade incompleta é normalizado na leitura', () {
      final t = Tabela.fromJson({
        'id': 'x',
        'nome': 'Parcial',
        'qtdHorarios': 4,
        // Só um dia, e com menos slots do que deveria.
        'celulas': {'SEGUNDA': ['a', 'b']},
      });

      expect(t.celulas.keys.toSet(), kDias.toSet());
      expect(t.celulas['SEGUNDA']!.length, 4);
      expect(t.celula('SEGUNDA', 1), 'b');
      expect(t.celula('SEGUNDA', 3), isNull);
      expect(t.celulas['SEXTA']!.length, 4);
    });
  });
}
