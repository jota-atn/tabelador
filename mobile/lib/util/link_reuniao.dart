import 'package:flutter/services.dart';

import '../model/evento.dart';

/// Domínios de videochamada. Outros links (suporte do Google, "tel.meet",
/// site qualquer) não viram "Entrar".
const _kDominios = [
  'meet.google.com',
  'zoom.us',
  'teams.microsoft.com',
  'teams.live.com',
  'meet.jit.si',
  'whereby.com',
];

final _kUrl = RegExp(r'(https?://)?([a-z0-9-]+\.)*([a-z0-9-]+\.[a-z]{2,})(/[^\s<>"]*)?', caseSensitive: false);

/// O primeiro link de videochamada no Local ou nas Notas de [e] (reunião
/// híbrida: sala no Local, link nas Notas), já com `https://`. Null se não
/// houver.
String? linkDeReuniao(Evento e) {
  for (final texto in [e.local, e.notas]) {
    if (texto == null) continue;
    for (final m in _kUrl.allMatches(texto)) {
      final bruto = m.group(0)!;
      final semEsquema = bruto.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
      final host = semEsquema.split('/').first.toLowerCase();
      final ehReuniao = _kDominios.any((d) => host == d || host.endsWith('.$d'));
      // Só o domínio (sem sala/código) não leva a reunião nenhuma.
      if (!ehReuniao || !semEsquema.contains('/')) continue;
      final limpo = semEsquema.replaceFirst(RegExp(r'[.,;:)]+$'), '');
      return 'https://$limpo';
    }
  }
  return null;
}

/// O Google cola na descrição um bloco de videochamada entre linhas
/// `-::~:~::~…`, com link, telefone e "Não edite esta seção." — tira ele
/// (o botão Entrar faz esse papel). Null se não sobrar nada.
String? notasSemBlocoDeChamada(String? notas) {
  if (notas == null) return null;
  final limpo = notas
      .replaceAll(RegExp(r'-::~[:~]*-[\s\S]*?-::~[:~]*-'), '')
      .trim();
  return limpo.isEmpty ? null : limpo;
}

/// De 10 min antes até o fim (evento pontual: até 1 h depois) — quando o
/// atalho de entrar aparece na lista.
bool horaDeEntrar(Ocorrencia o, DateTime agora) {
  final fim = o.fim.isAfter(o.inicio) ? o.fim : o.inicio.add(const Duration(hours: 1));
  return !agora.isBefore(o.inicio.subtract(const Duration(minutes: 10))) && agora.isBefore(fim);
}

const _canal = MethodChannel('tabelador/agenda');

/// Abre [url] no app de videochamada (ou no navegador). Falso se não deu —
/// sem app pra abrir, ou nos testes, onde não há lado nativo.
Future<bool> abrirLink(String url) async {
  try {
    return await _canal.invokeMethod<bool>('abrirLink', {'url': url}) ?? false;
  } catch (_) {
    return false;
  }
}
