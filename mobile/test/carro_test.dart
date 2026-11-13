import 'package:flutter_test/flutter_test.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/util/carro.dart';

Evento _ev(String tipo, {String? local}) =>
    Evento(id: 'x', titulo: 'Dentista', inicio: DateTime(2026, 11, 20, 14), tipo: tipo, local: local);

void main() {
  test('só Consulta e Compromisso com endereço', () {
    expect(enderecoPraCarro(_ev('Consulta', local: ' Rua X, 123 ')), 'Rua X, 123');
    expect(enderecoPraCarro(_ev('Compromisso', local: 'Shopping')), 'Shopping');
    expect(enderecoPraCarro(_ev('Reunião', local: 'Rua X, 123')), isNull);
    expect(enderecoPraCarro(_ev('Prova', local: 'Bloco C')), isNull);
    expect(enderecoPraCarro(_ev('Consulta')), isNull);
    expect(enderecoPraCarro(_ev('Consulta', local: '  ')), isNull);
    expect(enderecoPraCarro(_ev('Consulta'), localDoItem: 'Clínica'), 'Clínica');
  });

  test('consulta online (link no local) não chama carro', () {
    expect(enderecoPraCarro(_ev('Consulta', local: 'https://meet.google.com/abc-defg-hij')), isNull);
  });

  test('link do Uber leva destino, com coordenadas quando achou', () {
    final com = linkDoUber('Rua X, 123', apelido: 'Dentista', lat: -7.1, lng: -34.8);
    expect(com.host, 'm.uber.com');
    expect(com.queryParameters['dropoff[latitude]'], '-7.1');
    expect(com.queryParameters['dropoff[formatted_address]'], 'Rua X, 123');
    expect(com.queryParameters['dropoff[nickname]'], 'Dentista');
    expect(com.queryParameters['pickup'], 'my_location');
    final sem = linkDoUber('Rua X, 123');
    expect(sem.queryParameters.containsKey('dropoff[latitude]'), isFalse);
  });
}
