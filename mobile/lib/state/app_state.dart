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

  Tabela? tabelaPorId(String? id) {
    if (id == null) return null;
    for (final t in _tabelas) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// O que a bandeja de arrastar e o seletor por toque de [tabelaId] oferecem:
  /// os itens compartilhados (sem [Item.tabelaId]) mais os exclusivos dessa
  /// tabela, tirando os arquivados. Exclusivo de outra tabela nunca aparece
  /// aqui — é esse isolamento que resolve o item de um semestre vazando pra
  /// paleta de outro.
  List<Item> itensParaTabela(String tabelaId) => List.unmodifiable(
        _itens.where(
          (i) => !i.arquivado && (i.tabelaId == null || i.tabelaId == tabelaId),
        ),
      );

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

  Future<void> definirArquivado(String itemId, bool arquivado) async {
    _itens = [
      for (final i in _itens)
        i.id == itemId ? i.copyWith(arquivado: arquivado) : i,
    ];
    notifyListeners();
    await _store.salvarItens(_itens);
  }

  /// Arquiva vários itens de uma vez — usado pela revisão em lote de
  /// [itensExclusivosDe], que já filtrou quais o usuário confirmou.
  Future<void> arquivarItens(Iterable<String> itemIds) async {
    final ids = itemIds.toSet();
    if (ids.isEmpty) return;
    _itens = [
      for (final i in _itens) ids.contains(i.id) ? i.copyWith(arquivado: true) : i,
    ];
    notifyListeners();
    await _store.salvarItens(_itens);
  }

  /// Itens (ainda não arquivados) que só aparecem nas células de [tabelaId].
  ///
  /// É só um ponto de partida pra revisão em lote — item genérico e
  /// recorrente (Almoço, Academia) pode só coincidir de hoje ser exclusivo
  /// por ainda existir uma tabela só, sem deixar de fazer sentido em
  /// tabelas futuras. Quem decide de fato é o usuário, marcando/desmarcando
  /// na revisão antes de confirmar.
  List<Item> itensExclusivosDe(String tabelaId) {
    Tabela? tabela;
    for (final t in _tabelas) {
      if (t.id == tabelaId) tabela = t;
    }
    if (tabela == null) return const [];

    final usadosAqui = <String>{
      for (final dia in tabela.dias)
        for (final id in tabela.celulas[dia] ?? const []) ?id,
    };

    final resultado = <Item>[];
    for (final id in usadosAqui) {
      final usaEmOutra = _tabelas.any(
        (t) => t.id != tabelaId && t.usosDe(id) > 0,
      );
      if (usaEmOutra) continue;
      final item = itemPorId(id);
      if (item != null && !item.arquivado) resultado.add(item);
    }
    return resultado;
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

  /// Quantos itens só existem por causa de [tabelaId] (ver [Item.tabelaId]) —
  /// usado pra avisar antes de apagar a tabela, já que eles somem junto.
  int itensExclusivosContagem(String tabelaId) =>
      _itens.where((i) => i.tabelaId == tabelaId).length;

  Future<void> removerTabela(String tabelaId) async {
    _tabelas = [
      for (final t in _tabelas)
        if (t.id != tabelaId) t,
    ];
    // Item exclusivo de uma tabela não sobrevive a ela — ao contrário do
    // compartilhado, não tem pra onde apontar fora dali.
    _itens = [
      for (final i in _itens)
        if (i.tabelaId != tabelaId) i,
    ];
    if (_tabelaAtivaId == tabelaId) {
      _tabelaAtivaId = _tabelas.isEmpty ? null : _tabelas.first.id;
      await _store.salvarTabelaAtiva(_tabelaAtivaId);
    }
    notifyListeners();
    await _store.salvarTabelas(_tabelas);
    await _store.salvarItens(_itens);
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

  // ------------------------------------------------------------- backup

  /// Tudo que o app guarda, num mapa pronto pra virar JSON. Mesmo formato
  /// que [restaurarBackup] espera de volta.
  Map<String, dynamic> paraBackup() => {
        'versao': 1,
        'itens': [for (final i in _itens) i.toJson()],
        'tabelas': [for (final t in _tabelas) t.toJson()],
        'tabelaAtivaId': _tabelaAtivaId,
        'densidade': _densidade.key,
      };

  /// Substitui TUDO (itens, tabelas, tabela ativa, densidade) pelo conteúdo
  /// de [dados] — não mescla com o que já existe. Lança se o formato não
  /// bater; quem chama decide como avisar o usuário, já que só a UI sabe
  /// como isso deveria aparecer numa tela.
  Future<void> restaurarBackup(Map<String, dynamic> dados) async {
    final itensBrutos = dados['itens'];
    final tabelasBrutas = dados['tabelas'];
    if (itensBrutos is! List || tabelasBrutas is! List) {
      throw const FormatException('Backup não tem o formato esperado.');
    }

    final itens = [
      for (final e in itensBrutos) Item.fromJson(e as Map<String, dynamic>),
    ];
    final tabelas = [
      for (final e in tabelasBrutas) Tabela.fromJson(e as Map<String, dynamic>),
    ];
    final tabelaAtivaIdBruto = dados['tabelaAtivaId'] as String?;

    _itens = itens;
    _tabelas = tabelas;
    // Mesma regra tolerante do carregamento normal: id ativo que não bate
    // com nenhuma tabela do backup cai na primeira, ou em nada.
    _tabelaAtivaId = _tabelas.any((t) => t.id == tabelaAtivaIdBruto)
        ? tabelaAtivaIdBruto
        : (_tabelas.isEmpty ? null : _tabelas.first.id);
    _densidade = ColorDensity.fromKey(dados['densidade'] as String?);

    notifyListeners();
    await _store.salvarItens(_itens);
    await _store.salvarTabelas(_tabelas);
    await _store.salvarTabelaAtiva(_tabelaAtivaId);
    await _store.salvarDensidade(_densidade);
  }
}
