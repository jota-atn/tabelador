import 'package:flutter/services.dart';

import '../model/evento.dart';
import 'link_reuniao.dart';

const kPacoteUber = 'com.ubercab';
const kPacote99 = 'com.taxis99';

const _canal = MethodChannel('tabelador/agenda');

/// Endereço pra chamar carro, ou null: só Consulta e Compromisso (reunião
/// pode ser online, aula não precisa), e o local não pode ser link de
/// videochamada.
String? enderecoPraCarro(Evento e, {String? localDoItem}) {
  final tipo = TipoEvento.doTexto(e.tipo);
  if (tipo != TipoEvento.consulta && tipo != TipoEvento.compromisso) return null;
  final local = (e.local ?? localDoItem)?.trim();
  if (local == null || local.isEmpty) return null;
  if (linkDeReuniao(Evento(id: '', titulo: '', inicio: e.inicio, local: local)) != null) return null;
  return local;
}

/// Link universal do Uber com o destino: coordenadas quando o endereço foi
/// achado (acerta o ponto), senão só o texto.
Uri linkDoUber(String endereco, {String? apelido, double? lat, double? lng}) => Uri.https('m.uber.com', '/ul/', {
      'action': 'setPickup',
      'pickup': 'my_location',
      if (lat != null && lng != null) ...{
        'dropoff[latitude]': '$lat',
        'dropoff[longitude]': '$lng',
      },
      'dropoff[nickname]': apelido ?? endereco,
      'dropoff[formatted_address]': endereco,
    });

/// Falso nos testes (sem lado nativo) — aí os botões nem aparecem.
Future<bool> appInstalado(String pacote) async {
  try {
    return await _canal.invokeMethod<bool>('appInstalado', {'pacote': pacote}) ?? false;
  } catch (_) {
    return false;
  }
}

Future<({double lat, double lng})?> geocodificar(String endereco) async {
  try {
    final r = await _canal.invokeMapMethod<String, double>('geocodificar', {'endereco': endereco});
    if (r == null || r['lat'] == null || r['lng'] == null) return null;
    return (lat: r['lat']!, lng: r['lng']!);
  } catch (_) {
    return null;
  }
}

/// Procura o endereço e abre o Uber com o destino.
Future<bool> chamarUber(String endereco, {String? apelido}) async {
  final ponto = await geocodificar(endereco);
  final link = linkDoUber(endereco, apelido: apelido, lat: ponto?.lat, lng: ponto?.lng);
  try {
    return await _canal.invokeMethod<bool>('abrirLink', {'url': '$link', 'pacote': kPacoteUber}) ?? false;
  } catch (_) {
    return false;
  }
}

/// A 99 não recebe destino por link: copia o endereço e abre o app.
Future<bool> chamar99(String endereco) async {
  await Clipboard.setData(ClipboardData(text: endereco));
  try {
    return await _canal.invokeMethod<bool>('abrirApp', {'pacote': kPacote99}) ?? false;
  } catch (_) {
    return false;
  }
}
