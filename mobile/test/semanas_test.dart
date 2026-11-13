import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/util/formato_data.dart';

void main() {
  group('rótulo da semana', () {
    final agora = DateTime(2026, 11, 12);

    test('mesmo mês, mês por extenso', () {
      expect(rotuloDaSemana(DateTime(2026, 11, 16), agora), '16 – 22 de novembro');
    });

    test('atravessando o mês, abreviado', () {
      expect(rotuloDaSemana(DateTime(2026, 11, 30), agora), '30 nov – 6 dez');
    });

    test('ano só quando não é o atual', () {
      expect(rotuloDaSemana(DateTime(2027, 1, 4), agora), '4 – 10 de janeiro de 2027');
      expect(rotuloDaSemana(DateTime(2026, 12, 28), agora), '28 dez 2026 – 3 jan 2027');
    });

    test('título relativo à semana de hoje', () {
      expect(tituloDaSemana(DateTime(2026, 11, 9), agora), 'Esta semana');
      expect(tituloDaSemana(DateTime(2026, 11, 16), agora), 'Semana que vem');
      expect(tituloDaSemana(DateTime(2026, 11, 2), agora), 'Semana passada');
      expect(tituloDaSemana(DateTime(2026, 11, 23), agora), 'Semana de 23/11');
    });
  });

  group('semana mostrada', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('anda, volta pra hoje e pede a tela só quando pedido', () async {
      final state = AppState();
      await state.carregar();
      final hoje = DateTime.now();
      final atual = DateTime(hoje.year, hoje.month, hoje.day - (hoje.weekday - 1));

      expect(state.segundaMostrada(), atual);
      expect(state.mostrandoSemanaAtual(), isTrue);

      state.andarSemanas(2);
      expect(state.segundaMostrada(), DateTime(atual.year, atual.month, atual.day + 14));
      expect(state.mostrandoSemanaAtual(), isFalse);
      expect(state.pedidosDeSemana, 0);

      // Qualquer dia da semana leva pra segunda dela.
      state.mostrarSemana(DateTime(2027, 3, 11), irPraTela: true);
      expect(state.segundaMostrada(), DateTime(2027, 3, 8));
      expect(state.pedidosDeSemana, 1);

      state.mostrarSemana(hoje);
      expect(state.mostrandoSemanaAtual(), isTrue);
    });
  });
}
