import 'dart:async';

import 'package:flutter/foundation.dart';

import '../agenda/agendas_do_aparelho.dart';
import '../data/tabelador_store.dart';
import '../model/evento.dart';
import '../model/item.dart';
import '../model/tabela.dart';
import '../theme/color_density.dart';

/// Estado do app: a biblioteca de itens, as tabelas e as preferências.
///
/// Grava a cada mudança em vez de ter botão de salvar. São poucos kilobytes de
/// JSON e o usuário não deveria pensar em salvar um horário.
class AppState extends ChangeNotifier {
  AppState({TabeladorStore? store, FonteDeEventosExternos? fonteExterna})
      : _store = store ?? TabeladorStore(),
        // ignore: prefer_initializing_formals
        _fonteExterna = fonteExterna;

  final TabeladorStore _store;

  /// Nula nos testes (sem canal de plataforma): o app funciona só com os
  /// eventos locais.
  final FonteDeEventosExternos? _fonteExterna;

  List<Item> _itens = [];
  List<Tabela> _tabelas = [];
  List<Evento> _eventos = [];
  List<Evento> _externos = [];
  Map<String, AgendaEscolhida> _agendas = {};
  bool _agendasConfiguradas = false;
  String? _tabelaAtivaId;
  ColorDensity _densidade = ColorDensity.fallback;
  bool _notificacoesAtivas = false;
  int _antecedenciaMinutos = 15;
  bool _notificarEventos = true;
  bool _carregado = false;

  List<Item> get itens => List.unmodifiable(_itens);
  List<Tabela> get tabelas => List.unmodifiable(_tabelas);
  /// Só os criados no app. Os do Google ficam em [eventosExternos].
  List<Evento> get eventos => List.unmodifiable(_eventos);
  List<Evento> get eventosExternos => List.unmodifiable(_externos);
  Map<String, AgendaEscolhida> get agendas => Map.unmodifiable(_agendas);
  bool get agendasConfiguradas => _agendasConfiguradas;
  ColorDensity get densidade => _densidade;
  bool get notificacoesAtivas => _notificacoesAtivas;
  int get antecedenciaMinutos => _antecedenciaMinutos;
  bool get notificarEventos => _notificarEventos;
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
    _eventos = _migrar(dados.eventos);
    if (!identical(_eventos, dados.eventos) &&
        !listEquals(_eventos, dados.eventos)) {
      unawaited(_store.salvarEventos(_eventos));
    }
    _densidade = dados.densidade;
    _notificacoesAtivas = dados.notificacoesAtivas;
    _antecedenciaMinutos = dados.antecedenciaMinutos;
    _notificarEventos = dados.notificarEventos;
    _agendas = {...dados.agendas};
    _agendasConfiguradas = dados.agendasConfiguradas;
    _agendaDestinoPadrao = dados.agendaDestino;
    _semanaAberta = dados.semanaAberta;
    _cartaoGoogle = dados.cartaoGooglePendente;
    if (dados.onboardingVisto != null) {
      _onboardingVisto = dados.onboardingVisto!;
    } else if (_tabelas.isNotEmpty) {
      // Já usava o app antes do onboarding existir: nada de boas-vindas,
      // só o cartão avisando do Google (se ainda não conectou).
      _onboardingVisto = true;
      _cartaoGoogle = !dados.agendasConfiguradas;
      unawaited(_store.salvarOnboardingVisto(true));
      unawaited(_store.salvarCartaoGooglePendente(_cartaoGoogle));
    } else {
      _onboardingVisto = false;
    }

    // Id ativo apontando pra tabela que não existe mais: cai na primeira, ou em
    // nada se não houver tabela nenhuma.
    _tabelaAtivaId = _tabelas.any((t) => t.id == dados.tabelaAtivaId)
        ? dados.tabelaAtivaId
        : (_tabelas.isEmpty ? null : _tabelas.first.id);

    _carregado = true;
    notifyListeners();
    unawaited(recarregarEventosExternos());
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
    // Evento vinculado não some junto: a prova continua existindo, só deixa
    // de apontar pra disciplina.
    final tinhaEvento = _eventos.any((e) => e.itemId == itemId);
    if (tinhaEvento) {
      _eventos = [
        for (final e in _eventos) e.itemId == itemId ? e.semItem() : e,
      ];
    }
    notifyListeners();
    await _store.salvarItens(_itens);
    await _store.salvarTabelas(_tabelas);
    if (tinhaEvento) await _store.salvarEventos(_eventos);
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
    ).copyWith(celulas: origem.celulas, mostrarEventos: origem.mostrarEventos);

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

  // -------------------------------------------------------------- eventos

  Evento? eventoPorId(String? id) {
    if (id == null) return null;
    for (final e in _eventos) {
      if (e.id == id) return e;
    }
    for (final e in _externos) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Todas as ocorrências que começam em `[de, ate)`, de todos os eventos,
  /// em ordem cronológica.
  List<Ocorrencia> ocorrenciasEntre(DateTime de, DateTime ate) {
    // Evento do app gravado no Google volta na leitura como externo — fica
    // só a versão do app, que tem vínculo com item e é editável.
    final espelhados = {
      for (final e in _eventos)
        if (e.idNoAparelho != null) e.idNoAparelho,
    };
    final todas = [
      for (final e in _eventos) ...e.ocorrenciasEntre(de, ate),
      for (final e in _externos)
        if (!espelhados.contains(e.idNoAparelho)) ...e.ocorrenciasEntre(de, ate),
    ]..sort((a, b) => a.inicio.compareTo(b.inicio));
    return todas;
  }

  List<Evento> eventosDoItem(String itemId) =>
      List.unmodifiable(_eventos.where((e) => e.itemId == itemId));

  /// Tipos que saíram da lista viram os novos (ver [Evento.migrado]).
  static List<Evento> _migrar(List<Evento> eventos) {
    final agora = DateTime.now();
    return [for (final e in eventos) e.migrado(agora)];
  }

  // -------------------------------------------------------------- tarefas

  /// Tarefas do app (com e sem data), na ordem em que foram salvas.
  List<Evento> get tarefas => List.unmodifiable(_eventos.where((e) => e.ehTarefa));

  /// Tarefas atrasadas: não concluídas, com data, e com o prazo já
  /// passado (sem hora: o dia acabou). Só as que não repetem — ocorrência
  /// antiga de tarefa recorrente não se acumula como atraso.
  List<Ocorrencia> tarefasAtrasadas(DateTime agora) {
    final hoje = DateTime(agora.year, agora.month, agora.day);
    return [
      for (final e in _eventos)
        if (e.ehTarefa &&
            !e.semData &&
            !e.feito &&
            e.repeticao == Repeticao.nenhuma &&
            (e.diaInteiro ? e.inicio.isBefore(hoje) : e.inicio.isBefore(agora)))
          Ocorrencia(e, e.inicio, e.inicio.add(e.duracao)),
    ]..sort((a, b) => a.inicio.compareTo(b.inicio));
  }

  /// Conclui (ou reabre) a ocorrência [o] — em tarefa que repete, só ela.
  Future<void> marcarFeita(Ocorrencia o, bool feita) async {
    final e = o.evento;
    if (e.externo) return;
    final novo = e.marcandoFeita(o.inicio, feita);
    if (novo == e) return;
    _eventos = [for (final x in _eventos) x.id == e.id ? novo : x];
    notifyListeners();
    await _store.salvarEventos(_eventos);
  }

  /// Desfaz um [removerEvento]: o evento volta igual, e a cópia no Google
  /// (que foi apagada lá) é recriada na mesma agenda.
  Future<bool> restaurarEvento(Evento evento) async {
    final destino = evento.agendaDestinoId;
    return adicionarEvento(
      evento.comEspelho(null, null),
      salvarEm: destino != null && _agendas[destino]?.gravavel == true ? destino : null,
    );
  }

  /// Salva [evento] e, com [salvarEm] (id de agenda do aparelho), grava
  /// uma cópia lá — que o Android sobe pro Google. Devolve false se a cópia
  /// falhou: o evento fica salvo no app mesmo assim, só não no Google, e
  /// quem chama avisa.
  Future<bool> adicionarEvento(Evento evento, {String? salvarEm}) async {
    // Tarefa sem data não tem o que pôr numa agenda.
    if (evento.semData) salvarEm = null;
    var salvo = evento;
    var ok = true;
    if (salvarEm != null) {
      final r = await _espelhar(evento, salvarEm);
      ok = r != null;
      if (r != null) salvo = r;
    }
    _eventos = [..._eventos, salvo];
    notifyListeners();
    await _store.salvarEventos(_eventos);
    if (salvarEm != null) await _lembrarDestino(salvarEm);
    return ok;
  }

  /// Como [adicionarEvento], resolvendo a cópia no aparelho conforme
  /// mudou: mesma agenda atualiza; outra agenda apaga lá e cria cá; nenhuma
  /// ("só no app") apaga a cópia.
  Future<bool> atualizarEvento(Evento evento, {String? salvarEm}) async {
    if (evento.semData) salvarEm = null;
    final anterior = eventoPorId(evento.id);
    // O formulário não sabe do espelho; herda do que estava salvo.
    var salvo = evento.comEspelho(anterior?.idNoAparelho, anterior?.agendaDestinoId);
    var ok = true;
    final fonte = _fonteExterna;

    if (fonte != null) {
      try {
        if (salvo.idNoAparelho != null && salvo.agendaDestinoId != salvarEm) {
          await fonte.apagarEvento(salvo.idNoAparelho!);
          salvo = salvo.comEspelho(null, null);
        }
        if (salvarEm != null) {
          final r = await _espelhar(salvo, salvarEm, idNoAparelho: salvo.idNoAparelho);
          ok = r != null;
          if (r != null) salvo = r;
        }
      } catch (_) {
        ok = false;
      }
    }

    _eventos = [
      for (final e in _eventos) e.id == evento.id ? salvo : e,
    ];
    notifyListeners();
    await _store.salvarEventos(_eventos);
    if (salvarEm != null) await _lembrarDestino(salvarEm);
    return ok;
  }

  /// Apaga do app e, se houver, a cópia na agenda do aparelho (e do Google).
  Future<void> removerEvento(String eventoId) async {
    final evento = eventoPorId(eventoId);
    _eventos = [
      for (final e in _eventos)
        if (e.id != eventoId) e,
    ];
    notifyListeners();
    await _store.salvarEventos(_eventos);
    final idLa = evento?.gravadoNoGoogle == true ? evento!.idNoAparelho : null;
    if (idLa != null) {
      try {
        await _fonteExterna?.apagarEvento(idLa);
      } catch (_) {
        // Já sumiu de lá (apagado pelo Google Agenda): nada a fazer.
      }
      unawaited(recarregarEventosExternos());
    }
  }

  Future<Evento?> _espelhar(Evento evento, String agendaId, {String? idNoAparelho}) async {
    final fonte = _fonteExterna;
    if (fonte == null) return null;
    try {
      final id = await fonte.gravarEvento(evento, agendaId, idNoAparelho: idNoAparelho);
      unawaited(recarregarEventosExternos());
      return evento.comEspelho(id, agendaId);
    } catch (_) {
      return null;
    }
  }

  /// Última agenda escolhida em "salvar também em" — vira o padrão do
  /// próximo evento, pra decidir isso uma vez só.
  String? _agendaDestinoPadrao;
  String? get agendaDestinoPadrao =>
      _agendas[_agendaDestinoPadrao]?.gravavel == true ? _agendaDestinoPadrao : null;

  Future<void> _lembrarDestino(String agendaId) async {
    if (_agendaDestinoPadrao == agendaId) return;
    _agendaDestinoPadrao = agendaId;
    await _store.salvarAgendaDestino(agendaId);
  }

  /// "Só no app" escolhido explicitamente também vira o padrão.
  Future<void> esquecerDestino() async {
    if (_agendaDestinoPadrao == null) return;
    _agendaDestinoPadrao = null;
    await _store.salvarAgendaDestino(null);
  }

  /// Agendas onde dá pra gravar: escolhidas e não somente-leitura.
  Map<String, AgendaEscolhida> get agendasGravaveis => {
        for (final e in _agendas.entries)
          if (e.value.gravavel) e.key: e.value,
      };

  // ------------------------------------------------- agendas do aparelho

  /// Quanto pra trás e pra frente os eventos externos são lidos. Cobre a
  /// grade, "Próximos", widget, avisos e alguns meses de calendário; o
  /// calendário além disso mostra só os eventos do app.
  static const _janelaPassado = Duration(days: 62);
  static const _janelaFuturo = Duration(days: 400);

  bool _recarregando = false;
  bool _recarregarDeNovo = false;

  /// Relê os eventos das agendas escolhidas. Chamada ao carregar, ao voltar
  /// pro app (o Android pode ter sincronizado algo novo) e ao mudar a
  /// seleção. Sem permissão, sem fonte ou sem agenda escolhida: lista vazia,
  /// nunca erro — o app continua funcionando só com os eventos locais.
  Future<void> recarregarEventosExternos() async {
    final fonte = _fonteExterna;
    if (fonte == null) return;
    if (_recarregando) {
      _recarregarDeNovo = true;
      return;
    }
    _recarregando = true;
    try {
      do {
        _recarregarDeNovo = false;
        var novos = const <Evento>[];
        if (_agendas.isNotEmpty && await fonte.temPermissao()) {
          await _atualizarMetadadosDasAgendas(fonte);
          final agora = DateTime.now();
          try {
            novos = await fonte.lerEventos(
              _agendas.keys.toSet(),
              agora.subtract(_janelaPassado),
              agora.add(_janelaFuturo),
              cores: {for (final e in _agendas.entries) e.key: e.value.cor},
            );
          } catch (_) {
            novos = const [];
          }
        }
        if (!listEquals(novos, _externos)) {
          _externos = novos;
          notifyListeners();
        }
      } while (_recarregarDeNovo);
    } finally {
      _recarregando = false;
    }
  }

  /// Nome, cor e "dá pra gravar" das agendas escolhidas podem mudar no
  /// Google (ou vir de uma versão do app que não guardava "gravável").
  /// Agenda que sumiu do aparelho sai da escolha.
  Future<void> _atualizarMetadadosDasAgendas(FonteDeEventosExternos fonte) async {
    try {
      final lista = await fonte.listar();
      final atualizado = {
        for (final a in lista)
          if (_agendas.containsKey(a.id))
            a.id: AgendaEscolhida(nome: a.nome, cor: a.cor, gravavel: !a.somenteLeitura, conta: a.conta),
      };
      final igual = atualizado.length == _agendas.length &&
          atualizado.entries.every((e) => _agendas[e.key] == e.value);
      if (!igual) {
        _agendas = atualizado;
        notifyListeners();
        await _store.salvarAgendas(_agendas);
      }
    } catch (_) {
      // Sem conseguir listar, segue com o que já estava salvo.
    }
  }

  Future<void> definirAgendas(Map<String, AgendaEscolhida> agendas) async {
    _agendas = {...agendas};
    _agendasConfiguradas = true;
    notifyListeners();
    await _store.salvarAgendas(_agendas);
    await recarregarEventosExternos();
  }

  bool _semanaAberta = false;
  bool get semanaAberta => _semanaAberta;

  // ------------------------------------------------------------ onboarding

  bool _onboardingVisto = true;

  /// Flag gravada, não inferida de "não tem tabela": quem apagou todas as
  /// tabelas não vê as boas-vindas de novo.
  bool get onboardingVisto => _onboardingVisto;

  Future<void> concluirOnboarding() async {
    _onboardingVisto = true;
    notifyListeners();
    await _store.salvarOnboardingVisto(true);
  }

  /// "Rever a introdução" em Aparência.
  Future<void> reverOnboarding() async {
    _onboardingVisto = false;
    notifyListeners();
    await _store.salvarOnboardingVisto(false);
  }

  bool _cartaoGoogle = false;

  /// Cartão "Novo: conecte o Google Agenda": só pra quem já usava o app,
  /// some ao fechar ou ao conectar e não volta.
  bool get mostrarCartaoGoogle => _cartaoGoogle && !_agendasConfiguradas;

  Future<void> fecharCartaoGoogle() async {
    if (!_cartaoGoogle) return;
    _cartaoGoogle = false;
    notifyListeners();
    await _store.salvarCartaoGooglePendente(false);
  }

  /// Onde eventos novos são salvos por padrão (nulo = só no app).
  Future<void> definirAgendaDestinoPadrao(String? agendaId) async {
    if (agendaId == null) {
      await esquecerDestino();
    } else {
      await _lembrarDestino(agendaId);
    }
    notifyListeners();
  }

  Future<void> alternarSemanaAberta() async {
    _semanaAberta = !_semanaAberta;
    notifyListeners();
    await _store.salvarSemanaAberta(_semanaAberta);
  }

  // --------------------------------------------------------- preferências

  Future<void> definirDensidade(ColorDensity densidade) async {
    if (_densidade == densidade) return;
    _densidade = densidade;
    notifyListeners();
    await _store.salvarDensidade(densidade);
  }

  Future<void> definirNotificacoesAtivas(bool ativas) async {
    if (_notificacoesAtivas == ativas) return;
    _notificacoesAtivas = ativas;
    notifyListeners();
    await _store.salvarNotificacoesAtivas(ativas);
  }

  Future<void> definirAntecedenciaMinutos(int minutos) async {
    if (_antecedenciaMinutos == minutos) return;
    _antecedenciaMinutos = minutos;
    notifyListeners();
    await _store.salvarAntecedenciaMinutos(minutos);
  }

  Future<void> definirNotificarEventos(bool ativo) async {
    if (_notificarEventos == ativo) return;
    _notificarEventos = ativo;
    notifyListeners();
    await _store.salvarNotificarEventos(ativo);
  }

  // ------------------------------------------------------------- backup

  /// Tudo que o app guarda, num mapa pronto pra virar JSON. Mesmo formato
  /// que [restaurarBackup] espera de volta.
  Map<String, dynamic> paraBackup() => {
        'versao': 1,
        'itens': [for (final i in _itens) i.toJson()],
        'tabelas': [for (final t in _tabelas) t.toJson()],
        'eventos': [for (final e in _eventos) e.toJson()],
        'tabelaAtivaId': _tabelaAtivaId,
        'densidade': _densidade.key,
        'notificacoesAtivas': _notificacoesAtivas,
        'antecedenciaMinutos': _antecedenciaMinutos,
        'notificarEventos': _notificarEventos,
      };

  /// Substitui TUDO (itens, tabelas, eventos, tabela ativa, densidade) pelo conteúdo
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
    // Backup de antes dos eventos não tem a chave — vira lista vazia, não erro.
    final eventosBrutos = dados['eventos'];
    final eventos = [
      if (eventosBrutos is List)
        for (final e in eventosBrutos) Evento.fromJson(e as Map<String, dynamic>),
    ];
    final tabelaAtivaIdBruto = dados['tabelaAtivaId'] as String?;

    _itens = itens;
    _tabelas = tabelas;
    _eventos = _migrar(eventos);
    // Mesma regra tolerante do carregamento normal: id ativo que não bate
    // com nenhuma tabela do backup cai na primeira, ou em nada.
    _tabelaAtivaId = _tabelas.any((t) => t.id == tabelaAtivaIdBruto)
        ? tabelaAtivaIdBruto
        : (_tabelas.isEmpty ? null : _tabelas.first.id);
    _densidade = ColorDensity.fromKey(dados['densidade'] as String?);
    _notificacoesAtivas = dados['notificacoesAtivas'] as bool? ?? false;
    _antecedenciaMinutos = dados['antecedenciaMinutos'] as int? ?? 15;
    _notificarEventos = dados['notificarEventos'] as bool? ?? true;

    notifyListeners();
    await _store.salvarItens(_itens);
    await _store.salvarTabelas(_tabelas);
    await _store.salvarEventos(_eventos);
    await _store.salvarTabelaAtiva(_tabelaAtivaId);
    await _store.salvarDensidade(_densidade);
    await _store.salvarNotificacoesAtivas(_notificacoesAtivas);
    await _store.salvarAntecedenciaMinutos(_antecedenciaMinutos);
    await _store.salvarNotificarEventos(_notificarEventos);
  }
}
