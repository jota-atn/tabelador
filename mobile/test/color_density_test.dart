import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabelador/theme/color_density.dart';
import 'package:tabelador/theme/item_palette.dart';

/// Distância euclidiana em RGB. Grosseira perto de um deltaE de verdade, mas
/// suficiente pra pegar duas chaves colapsando uma na outra.
double _distance(Color a, Color b) {
  final dr = (a.r - b.r) * 255;
  final dg = (a.g - b.g) * 255;
  final db = (a.b - b.b) * 255;
  return math.sqrt(dr * dr + dg * dg + db * db);
}

/// Razão de contraste da WCAG entre duas cores opacas.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

ColorScheme _scheme(Brightness brightness) =>
    ColorScheme.fromSeed(seedColor: const Color(0xFF3C5F92), brightness: brightness);

void main() {
  group('ItemColor', () {
    test('chaves são únicas', () {
      final keys = ItemColor.values.map((c) => c.key).toSet();
      expect(keys.length, ItemColor.values.length);
    });

    test('chave desconhecida cai em grafite em vez de estourar', () {
      expect(ItemColor.fromKey('cor-que-nao-existe'), ItemColor.grafite);
      expect(ItemColor.fromKey(null), ItemColor.grafite);
    });

    test('ida e volta pela chave preserva a cor', () {
      for (final color in ItemColor.values) {
        expect(ItemColor.fromKey(color.key), color);
      }
    });

    /// Guarda de regressão pro problema que apareceu no aparelho: `oliva` e
    /// `salvia` ficaram próximas demais pra separar de relance. Mexer num matiz
    /// pra resolver um par pode aproximar outro sem ninguém perceber.
    test('nenhum par de cores fica próximo demais', () {
      // Piso de regressão, não meta de qualidade: é um pouco abaixo do pior par
      // medido hoje (esmeralda × turquesa, 26,1 no tom 40). Serve pra acusar se
      // alguém mexer num matiz e colapsar duas chaves — não pra afirmar que 25
      // basta. A distância euclidiana em RGB pune cores escuras, então no tom 40
      // ela subestima pares que na tela se separam bem.
      const minimo = 25.0;

      for (final tone in [40, 80]) {
        var pior = double.infinity;
        var piorPar = '';

        for (var i = 0; i < ItemColor.values.length; i++) {
          for (var j = i + 1; j < ItemColor.values.length; j++) {
            final a = ItemColor.values[i];
            final b = ItemColor.values[j];
            final d = _distance(a.tone(tone), b.tone(tone));
            if (d < pior) {
              pior = d;
              piorPar = '${a.key} × ${b.key}';
            }
          }
        }

        expect(
          pior,
          greaterThan(minimo),
          reason: 'no tom $tone, o par mais próximo é $piorPar '
              '(distância ${pior.toStringAsFixed(1)})',
        );
      }
    });

    test('a rampa vai do escuro ao claro', () {
      for (final color in ItemColor.values) {
        expect(
          color.tone(10).computeLuminance(),
          lessThan(color.tone(90).computeLuminance()),
          reason: '${color.key}: tom 10 deveria ser mais escuro que o 90',
        );
      }
    });
  });

  group('resolveCellStyle', () {
    test('discreto mantém o fundo neutro', () {
      final scheme = _scheme(Brightness.light);
      for (final color in ItemColor.values) {
        final style = resolveCellStyle(
          cor: color,
          densidade: ColorDensity.discreto,
          esquema: scheme,
        );
        expect(style.background, scheme.surfaceContainer);
        expect(style.accentWidth, 3);
        expect(style.hasAccent, isTrue);
      }
    });

    test('suave tinge o fundo e mantém o fio', () {
      final scheme = _scheme(Brightness.light);
      for (final color in ItemColor.values.where((c) => c != ItemColor.grafite)) {
        final style = resolveCellStyle(
          cor: color,
          densidade: ColorDensity.suave,
          esquema: scheme,
        );
        expect(style.background, isNot(scheme.surfaceContainer));
        expect(style.hasAccent, isTrue);
      }
    });

    test('sólido não tem fio', () {
      for (final brightness in Brightness.values) {
        final scheme = _scheme(brightness);
        for (final color in ItemColor.values) {
          final style = resolveCellStyle(
            cor: color,
            densidade: ColorDensity.solido,
            esquema: scheme,
          );
          expect(style.accentWidth, 0);
          expect(style.hasAccent, isFalse);
        }
      }
    });

    test('o tema escuro produz fundos mais escuros que o claro', () {
      final light = _scheme(Brightness.light);
      final dark = _scheme(Brightness.dark);
      for (final density in ColorDensity.values) {
        for (final color in ItemColor.values) {
          final l = resolveCellStyle(cor: color, densidade: density, esquema: light);
          final d = resolveCellStyle(cor: color, densidade: density, esquema: dark);
          expect(
            d.background.computeLuminance(),
            lessThan(l.background.computeLuminance()),
            reason: '${color.key} / ${density.key}',
          );
        }
      }
    });

    /// Esta é a promessa central da spec: o usuário escolhe uma chave de cor e
    /// uma densidade, nunca um par de cores — então nenhuma combinação
    /// alcançável pode ser ilegível.
    test('toda combinação alcançável passa no contraste AA', () {
      for (final brightness in Brightness.values) {
        final scheme = _scheme(brightness);
        for (final density in ColorDensity.values) {
          for (final color in ItemColor.values) {
            final style = resolveCellStyle(
              cor: color,
              densidade: density,
              esquema: scheme,
            );
            expect(
              _contrast(style.foreground, style.background),
              greaterThanOrEqualTo(4.5),
              reason: '${color.key} / ${density.key} / ${brightness.name}',
            );
          }
        }
      }
    });
  });

  group('ColorDensity', () {
    test('o padrão é suave', () {
      expect(ColorDensity.fallback, ColorDensity.suave);
      expect(ColorDensity.fromKey(null), ColorDensity.suave);
      expect(ColorDensity.fromKey('densidade-invalida'), ColorDensity.suave);
    });

    test('ida e volta pela chave preserva a densidade', () {
      for (final density in ColorDensity.values) {
        expect(ColorDensity.fromKey(density.key), density);
      }
    });
  });
}
