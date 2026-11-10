import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/evento.dart';
import '../model/item.dart';
import '../model/tabela.dart';
import '../theme/color_density.dart';

/// O que foi lido do disco de uma vez só.
class DadosSalvos {
  const DadosSalvos({
    required this.itens,
    required this.tabelas,
    this.eventos = const [],
    required this.tabelaAtivaId,
    required this.densidade,
    required this.notificacoesAtivas,
    required this.antecedenciaMinutos,
  });

  final List<Item> itens;
  final List<Tabela> tabelas;
  final List<Evento> eventos;
  final String? tabelaAtivaId;
  final ColorDensity densidade;
  final bool notificacoesAtivas;
  final int antecedenciaMinutos;

  static const DadosSalvos vazio = DadosSalvos(
    itens: [],
    tabelas: [],
    tabelaAtivaId: null,
    densidade: ColorDensity.fallback,
    notificacoesAtivas: false,
    antecedenciaMinutos: 15,
  );
}

/// Persistência em `SharedPreferences` + JSON.
///
/// A escala real é pequena — algumas dezenas de itens e poucas tabelas de ~30
/// slots — então banco de dados seria peso morto. Se um dia entrar histórico ou
/// sincronização, aí se reavalia.
class TabeladorStore {
  static const _kItens = 'items_json';
  static const _kTabelas = 'tables_json';
  static const _kEventos = 'events_json';
  static const _kAtiva = 'active_table_id';
  static const _kDensidade = 'color_density';
  static const _kNotificacoesAtivas = 'notifications_enabled';
  static const _kAntecedenciaMinutos = 'notifications_lead_minutes';

  Future<DadosSalvos> carregar() async {
    final prefs = await SharedPreferences.getInstance();

    return DadosSalvos(
      itens: _decodificarLista(prefs.getString(_kItens), Item.fromJson),
      tabelas: _decodificarLista(prefs.getString(_kTabelas), Tabela.fromJson),
      eventos: _decodificarLista(prefs.getString(_kEventos), Evento.fromJson),
      tabelaAtivaId: prefs.getString(_kAtiva),
      densidade: ColorDensity.fromKey(prefs.getString(_kDensidade)),
      notificacoesAtivas: prefs.getBool(_kNotificacoesAtivas) ?? false,
      antecedenciaMinutos: prefs.getInt(_kAntecedenciaMinutos) ?? 15,
    );
  }

  Future<void> salvarItens(List<Item> itens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kItens,
      jsonEncode([for (final i in itens) i.toJson()]),
    );
  }

  Future<void> salvarTabelas(List<Tabela> tabelas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kTabelas,
      jsonEncode([for (final t in tabelas) t.toJson()]),
    );
  }

  Future<void> salvarEventos(List<Evento> eventos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kEventos,
      jsonEncode([for (final e in eventos) e.toJson()]),
    );
  }

  Future<void> salvarTabelaAtiva(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_kAtiva);
    } else {
      await prefs.setString(_kAtiva, id);
    }
  }

  Future<void> salvarDensidade(ColorDensity densidade) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDensidade, densidade.key);
  }

  Future<void> salvarNotificacoesAtivas(bool ativas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificacoesAtivas, ativas);
  }

  Future<void> salvarAntecedenciaMinutos(int minutos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAntecedenciaMinutos, minutos);
  }

  /// JSON corrompido devolve lista vazia em vez de estourar.
  ///
  /// Perder os dados é ruim, mas um app que não abre é pior: sem isso, um
  /// registro malformado trancaria o usuário pra fora pra sempre, sem caminho
  /// de recuperação dentro do próprio app.
  static List<T> _decodificarLista<T>(
    String? bruto,
    T Function(Map<String, dynamic>) construtor,
  ) {
    if (bruto == null || bruto.isEmpty) return [];
    try {
      final lista = jsonDecode(bruto) as List<dynamic>;
      return [
        for (final entrada in lista)
          construtor(entrada as Map<String, dynamic>),
      ];
    } catch (_) {
      return [];
    }
  }
}
