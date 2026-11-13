import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../agenda/agendas_do_aparelho.dart';
import '../model/evento.dart';
import '../model/nota.dart';
import '../model/presente.dart';
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
    this.notificarEventos = true,
    this.agendas = const {},
    this.agendasConfiguradas = false,
    this.agendaDestino,
    this.semanaAberta = false,
    this.onboardingVisto,
    this.cartaoGooglePendente = false,
    this.feitasExternas = const {},
    this.ocultasExternas = const {},
    this.folgasExternas = const {},
    this.notasExternas = const {},
    this.presentesExternos = const {},
    this.ultimoMaximo = 10,
  });

  /// Ids de evento externo (tarefa do Classroom) marcados como feitos no
  /// app — o "entregue" não vem pela agenda.
  final Set<String> feitasExternas;

  /// Ids de evento externo escondidos do app (arrastar ← numa tarefa do
  /// Classroom: não dá pra apagar lá).
  final Set<String> ocultasExternas;

  /// Ids de feriado do Google que a pessoa marcou como folga (o Google
  /// mistura feriado de verdade com data comemorativa; por padrão nenhum
  /// esmaece aula).
  final Set<String> folgasExternas;

  /// Nota lançada em evento externo (prova do Google, atividade do
  /// Classroom), por id do evento — a agenda não guarda isso.
  final Map<String, Nota> notasExternas;

  /// Presente de aniversário externo (agenda de aniversários do Google), por
  /// id da ocorrência.
  final Map<String, Presente> presentesExternos;

  /// Máximo da última nota lançada — vem preenchido na próxima.
  final double ultimoMaximo;

  /// Nulo = chave nunca gravada (instalação nova, ou versão de antes do
  /// onboarding) — o AppState decide qual dos dois pelas tabelas.
  final bool? onboardingVisto;

  /// Cartão "Novo: conecte o Google Agenda" pra quem já usava o app antes
  /// do onboarding existir.
  final bool cartaoGooglePendente;

  final List<Item> itens;
  final List<Tabela> tabelas;
  final List<Evento> eventos;
  final String? tabelaAtivaId;
  final ColorDensity densidade;
  final bool notificacoesAtivas;
  final int antecedenciaMinutos;
  final bool notificarEventos;

  /// Agendas do aparelho escolhidas: id -> (nome, cor). Nome e cor ficam
  /// guardados pra mostrar evento externo sem consultar o Android de novo.
  final Map<String, AgendaEscolhida> agendas;

  /// Se o usuário já passou pela tela de agendas (e a seleção padrão já foi
  /// aplicada) — distingue "nunca configurou" de "desmarcou tudo".
  final bool agendasConfiguradas;

  /// Última agenda usada em "salvar também em".
  final String? agendaDestino;

  /// Acordeão "Esta semana" da tela inicial aberto ou recolhido.
  final bool semanaAberta;

  static const DadosSalvos vazio = DadosSalvos(
    itens: [],
    tabelas: [],
    tabelaAtivaId: null,
    densidade: ColorDensity.fallback,
    notificacoesAtivas: false,
    antecedenciaMinutos: 15,
  );
}

@immutable
class AgendaEscolhida {
  const AgendaEscolhida({
    required this.nome,
    this.cor,
    this.gravavel = false,
    this.conta = '',
    this.dono = '',
    this.tipo,
  });

  final String nome;
  final int? cor;

  /// Conta dona da agenda (o e-mail, no Google). Vazia em escolhas antigas
  /// até a próxima leitura das agendas preencher.
  final String conta;

  /// Dá pra gravar evento nela (dono/colaborador; feriados e turmas não).
  final bool gravavel;

  /// `OWNER_ACCOUNT` da agenda (ver [AgendaDoAparelho.dono]).
  final String dono;

  /// Tipo escolhido pelo usuário pros eventos dela. Nulo = o sugerido pelo
  /// dono ([tipoEfetivo]).
  final String? tipo;

  TipoEvento get tipoEfetivo => TipoEvento.doTexto(tipo ?? '') ?? tipoSugeridoPeloDono(dono);

  /// Escolha a partir da agenda lida do aparelho, mantendo o [tipo] que o
  /// usuário já tinha escolhido.
  factory AgendaEscolhida.de(AgendaDoAparelho a, {String? tipo}) => AgendaEscolhida(
        nome: a.nome,
        cor: a.cor,
        gravavel: !a.somenteLeitura,
        conta: a.conta,
        dono: a.dono,
        tipo: tipo,
      );

  AgendaEscolhida comTipo(String? tipo) =>
      AgendaEscolhida(nome: nome, cor: cor, gravavel: gravavel, conta: conta, dono: dono, tipo: tipo);

  Map<String, dynamic> toJson() => {
        'nome': nome,
        if (cor != null) 'cor': cor,
        if (gravavel) 'gravavel': true,
        if (conta.isNotEmpty) 'conta': conta,
        if (dono.isNotEmpty) 'dono': dono,
        if (tipo != null) 'tipo': tipo,
      };

  factory AgendaEscolhida.fromJson(Map<String, dynamic> j) => AgendaEscolhida(
        nome: j['nome'] as String? ?? '',
        cor: j['cor'] as int?,
        gravavel: j['gravavel'] as bool? ?? false,
        conta: j['conta'] as String? ?? '',
        dono: j['dono'] as String? ?? '',
        tipo: j['tipo'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is AgendaEscolhida &&
      other.nome == nome &&
      other.cor == cor &&
      other.gravavel == gravavel &&
      other.conta == conta &&
      other.dono == dono &&
      other.tipo == tipo;

  @override
  int get hashCode => Object.hash(nome, cor, gravavel, conta, dono, tipo);
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
  static const _kNotificarEventos = 'notifications_events';
  static const _kAgendas = 'device_calendars_json';
  static const _kAgendaDestino = 'device_calendar_target';
  static const _kSemanaAberta = 'week_list_open';
  static const _kOnboarding = 'onboarding_seen';
  static const _kCartaoGoogle = 'google_card_pending';
  static const _kFeitasExternas = 'external_done_ids';
  static const _kOcultasExternas = 'external_hidden_ids';
  static const _kFolgasExternas = 'external_day_off_ids';
  static const _kNotasExternas = 'external_grades_json';
  static const _kPresentesExternos = 'external_gifts_json';
  static const _kUltimoMaximo = 'last_grade_max';

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
      notificarEventos: prefs.getBool(_kNotificarEventos) ?? true,
      agendas: _decodificarAgendas(prefs.getString(_kAgendas)),
      agendasConfiguradas: prefs.getString(_kAgendas) != null,
      agendaDestino: prefs.getString(_kAgendaDestino),
      semanaAberta: prefs.getBool(_kSemanaAberta) ?? false,
      onboardingVisto: prefs.getBool(_kOnboarding),
      cartaoGooglePendente: prefs.getBool(_kCartaoGoogle) ?? false,
      feitasExternas: {...?prefs.getStringList(_kFeitasExternas)},
      ocultasExternas: {...?prefs.getStringList(_kOcultasExternas)},
      folgasExternas: {...?prefs.getStringList(_kFolgasExternas)},
      notasExternas: decodificarNotasExternas(prefs.getString(_kNotasExternas)),
      presentesExternos: decodificarPresentesExternos(prefs.getString(_kPresentesExternos)),
      ultimoMaximo: prefs.getDouble(_kUltimoMaximo) ?? 10,
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

  Future<void> salvarNotificarEventos(bool ativo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificarEventos, ativo);
  }

  Future<void> salvarAgendas(Map<String, AgendaEscolhida> agendas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kAgendas,
      jsonEncode({for (final e in agendas.entries) e.key: e.value.toJson()}),
    );
  }

  Future<void> salvarOnboardingVisto(bool visto) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarding, visto);
  }

  Future<void> salvarCartaoGooglePendente(bool pendente) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCartaoGoogle, pendente);
  }

  Future<void> salvarFeitasExternas(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFeitasExternas, ids.toList()..sort());
  }

  Future<void> salvarNotasExternas(Map<String, Nota> notas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNotasExternas, jsonEncode(codificarNotasExternas(notas)));
  }

  Future<void> salvarPresentesExternos(Map<String, Presente> presentes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPresentesExternos, jsonEncode(codificarPresentesExternos(presentes)));
  }

  Future<void> salvarUltimoMaximo(double maximo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kUltimoMaximo, maximo);
  }

  Future<void> salvarFolgasExternas(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFolgasExternas, ids.toList()..sort());
  }

  Future<void> salvarOcultasExternas(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kOcultasExternas, ids.toList()..sort());
  }

  Future<void> salvarSemanaAberta(bool aberta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSemanaAberta, aberta);
  }

  Future<void> salvarAgendaDestino(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_kAgendaDestino);
    } else {
      await prefs.setString(_kAgendaDestino, id);
    }
  }

  static Map<String, AgendaEscolhida> _decodificarAgendas(String? bruto) {
    if (bruto == null || bruto.isEmpty) return const {};
    try {
      final mapa = jsonDecode(bruto) as Map<String, dynamic>;
      return {
        for (final e in mapa.entries)
          e.key: AgendaEscolhida.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (_) {
      return const {};
    }
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

Map<String, dynamic> codificarNotasExternas(Map<String, Nota> notas) => {
      for (final e in notas.entries) e.key: e.value.toJson(),
    };

/// Tolerante: JSON ausente ou estragado vira mapa vazio.
Map<String, Nota> decodificarNotasExternas(Object? bruto) {
  try {
    final mapa = bruto is String ? jsonDecode(bruto) : bruto;
    if (mapa is! Map) return {};
    return {
      for (final e in mapa.entries) e.key as String: ?Nota.fromJson(e.value),
    };
  } catch (_) {
    return {};
  }
}

Map<String, dynamic> codificarPresentesExternos(Map<String, Presente> presentes) => {
      for (final e in presentes.entries) e.key: e.value.toJson(),
    };

/// Tolerante: JSON ausente ou estragado vira mapa vazio.
Map<String, Presente> decodificarPresentesExternos(Object? bruto) {
  try {
    final mapa = bruto is String ? jsonDecode(bruto) : bruto;
    if (mapa is! Map) return {};
    return {
      for (final e in mapa.entries) e.key as String: ?Presente.fromJson(e.value),
    };
  } catch (_) {
    return {};
  }
}
