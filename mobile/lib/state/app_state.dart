import 'package:flutter/foundation.dart';

import '../data/tabelador_store.dart';
import '../model/item.dart';
import '../model/tabela.dart';
import '../theme/color_density.dart';

/// Estado do app: a biblioteca de itens, as tabelas e as preferências.
///
/// Grava a cada mudança em vez de ter botão de salvar. São poucos kilobytes de
/// JSON e o usuário não deveria pensar em salvar um horário.
class AppState extends ChangeNotifier {
  AppState({TabeladorStore? store}) : _store = store ?? TabeladorStore();

  final TabeladorStore _store;

  List<Item> _itens = [];
  List<Tabela> _tabelas = [];
  String? _tabelaAtivaId;
  ColorDensity _densidade = ColorDensity.fallback;
  bool _carregado = false;

  List<Item> get itens => List.unmodifiable(_itens);
  List<Tabela> get tabelas => List.unmodifiable(_tabelas);
  ColorDensity get densidade => _densidade;
  bool get carregado => _carregado;

  String? get tabelaAtivaId => _tabelaAtivaId;

  Tabela? get tabelaAtiva {
    if (_tabelaAtivaId == null) return null;
    for (final t in _tabelas) {
      if (t.id == _tabelaAtivaId) return t;
    }
    return null;
  }

  /// Os tipos já usados, pro autocomplete do campo `tipo`. É o que substitui um
  /// enum fechado de categorias.
  List<String> get tiposConhecidos {
    final vistos = <String>{
      for (final i in _itens)
        if (i.tipo.trim().isNotEmpty) i.tipo.trim(),
    };
    return vistos.toList()..sort();
  }

  Item? itemPorId(String? id) {
    if (id == null) return null;
    for (final i in _itens) {
      if (i.id == id) return i;
    }
    return null;
  }

  Future<void> carregar() async {
    final dados = await _store.carregar();
    _itens = [...dados.itens];
    _tabelas = [...dados.tabelas];
    _densidade = dados.densidade;

    // Id ativo apontando pra tabela que não existe mais: cai na primeira, ou em
    // nada se não houver tabela nenhuma.
    _tabelaAtivaId = _tabelas.any((t) => t.id == dados.tabelaAtivaId)
        ? dados.tabelaAtivaId
        : (_tabelas.isEmpty ? null : _tabelas.first.id);

    _carregado = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------- itens

  Future<void> adicionarItem(Item item) async {
    _itens = [..._itens, item];
    notifyListeners();
    await _store.salvarItens(_itens);
  }

  Future<void> atualizarItem(Item item) async {
    _itens = [
      for (final i in _itens) i.id == item.id ? item : i,
    ];
    notifyListeners();
    await _store.salvarItens(_itens);
  }

  /// Em quantas células o item aparece, somando todas as tabelas.
  ///
  /// A tela mostra isso antes de confirmar a exclusão: apagar um item em
  /// silêncio esvaziaria horários que o usuário não está olhando.
  int usosDoItem(String itemId) =>
      _tabelas.fold(0, (soma, t) => soma + t.usosDe(itemId));

  /// Apaga o item e limpa toda célula que apontava pra ele.
  Future<void> removerItem(String itemId) async {
    _itens = [
      for (final i in _itens)
        if (i.id != itemId) i,
    ];
    _tabelas = [for (final t in _tabelas) t.semItem(itemId)];
    notifyListeners();
    await _store.salvarItens(_itens);
    await _store.salvarTabelas(_tabelas);
  }

  // -------------------------------------------------------------- tabelas

  Future<void> adicionarTabela(Tabela tabela) async {
    _tabelas = [..._tabelas, tabela];
    // Primeira tabela criada vira a ativa sozinha: não faz sentido ter uma
    // tabela só e nenhuma ativa.
    _tabelaAtivaId ??= tabela.id;
    notifyListeners();
    await _store.salvarTabelas(_tabelas);
    await _store.salvarTabelaAtiva(_tabelaAtivaId);
  }

  Future<void> atualizarTabela(Tabela tabela) async {
    _tabelas = [
      for (final t in _tabelas) t.id == tabela.id ? tabela : t,
    ];
    notifyListeners();
    await _store.salvarTabelas(_tabelas);
  }

  Future<void> removerTabela(String tabelaId) async {
    _tabelas = [
      for (final t in _tabelas)
        if (t.id != tabelaId) t,
    ];
    if (_tabelaAtivaId == tabelaId) {
      _tabelaAtivaId = _tabelas.isEmpty ? null : _tabelas.first.id;
      await _store.salvarTabelaAtiva(_tabelaAtivaId);
    }
    notifyListeners();
    await _store.salvarTabelas(_tabelas);
  }

  Future<void> definirTabelaAtiva(String? id) async {
    _tabelaAtivaId = id;
    notifyListeners();
    await _store.salvarTabelaAtiva(id);
  }

  /// Duplica uma tabela com a grade inteira. Útil no começo de semestre, quando
  /// metade do horário se repete.
  Future<Tabela?> duplicarTabela(String tabelaId, String novoNome) async {
    Tabela? origem;
    for (final t in _tabelas) {
      if (t.id == tabelaId) origem = t;
    }
    if (origem == null) return null;

    final copia = Tabela.nova(
      nome: novoNome,
      horaInicial: origem.horaInicial,
      intervalo: origem.intervalo,
      qtdHorarios: origem.qtdHorarios,
    ).copyWith(celulas: origem.celulas);

    await adicionarTabela(copia);
    return copia;
  }

  /// Põe (ou tira, com [itemId] nulo) um item num slot da tabela.
  Future<void> definirCelula(
    String tabelaId,
    String dia,
    int slot,
    String? itemId,
  ) async {
    _tabelas = [
      for (final t in _tabelas)
        t.id == tabelaId ? t.comCelula(dia, slot, itemId) : t,
    ];
    notifyListeners();
    await _store.salvarTabelas(_tabelas);
  }

  // --------------------------------------------------------- preferências

  Future<void> definirDensidade(ColorDensity densidade) async {
    if (_densidade == densidade) return;
    _densidade = densidade;
    notifyListeners();
    await _store.salvarDensidade(densidade);
  }
}
