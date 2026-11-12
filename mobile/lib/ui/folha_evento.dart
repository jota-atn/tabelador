import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../model/item.dart';
import '../model/tabela.dart';
import '../state/app_state.dart';
import '../util/eventos_na_grade.dart';
import '../util/formato_data.dart';
import '../util/id.dart';
import 'folha_evento_corpo.dart';

/// Abre a folha de criar/editar evento por cima da tela atual.
///
/// [itemId], [inicio] e [fim] pré-preenchem (toque longo numa célula, "+"
/// no item, dia do calendário). [tabelaId] diz de qual tabela vêm os chips
/// de item — a da célula; sem ela, a ativa.
Future<void> abrirFolhaDeEvento(
  BuildContext context, {
  Evento? original,
  String? itemId,
  DateTime? inicio,
  DateTime? fim,
  String? tabelaId,
  TipoEvento? tipo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // A padrão (250ms) é rápida demais pra uma folha alta: some antes do
    // olho acompanhar de onde ela veio.
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 420),
      reverseDuration: Duration(milliseconds: 260),
    ),
    builder: (_) => FolhaDeEvento(
      original: original,
      itemId: itemId,
      inicio: inicio,
      fim: fim,
      tabelaId: tabelaId,
      tipoInicial: tipo,
    ),
  );
}

class FolhaDeEvento extends StatefulWidget {
  const FolhaDeEvento({
    super.key,
    this.original,
    this.itemId,
    this.inicio,
    this.fim,
    this.tabelaId,
    this.tipoInicial,
  });

  /// Tipo já escolhido ao abrir ("Nova tarefa" na página de Tarefas).
  final TipoEvento? tipoInicial;

  final Evento? original;
  final String? itemId;
  final DateTime? inicio;
  final DateTime? fim;
  final String? tabelaId;

  @override
  State<FolhaDeEvento> createState() => FolhaDeEventoState();
}

/// Estado e regras da folha; o desenho fica em `folha_evento_corpo.dart`.
///
/// Regra geral dos automáticos: tipo e item preenchem duração, repetição,
/// local, data/hora e título — cada um **só enquanto o usuário não mexeu
/// nele**. Mexeu, é dele.
class FolhaDeEventoState extends State<FolhaDeEvento> {
  final titulo = TextEditingController();
  final local = TextEditingController();
  final notas = TextEditingController();

  TipoEvento? tipo;
  String? itemId;
  late DateTime data;
  late TimeOfDay horaInicio;
  bool diaTodo = false;

  /// Tarefa sem data (só Tarefa oferece).
  bool semData = false;

  /// Feriado que dá folga (só Feriado oferece). Desligado = data
  /// comemorativa, que não esmaece as aulas.
  bool folga = true;

  /// Hora do aviso quando é dia todo, em minutos desde a meia-noite.
  int avisoMin = kAvisoDiaTodoPadrao;

  /// 0 = prazo (um momento, sem faixa).
  int minutos = 60;
  Repeticao repeticao = Repeticao.nenhuma;
  String? destino;

  bool _tipoMexido = false;
  bool _localAuto = true;
  bool _quandoAuto = true;
  bool _duracaoAuto = true;
  bool _repeticaoAuto = true;
  bool _destinoMexido = false;

  bool get novo => widget.original == null;
  AppState get _state => context.read<AppState>();

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    final state = _state;
    if (o != null) {
      titulo.text = o.titulo;
      local.text = o.local ?? '';
      notas.text = o.notas ?? '';
      tipo = TipoEvento.doTexto(o.tipo);
      itemId = o.itemId;
      data = inicioDoDia(o.inicio);
      horaInicio = TimeOfDay.fromDateTime(o.inicio);
      diaTodo = o.diaInteiro;
      semData = o.semData;
      folga = !o.comemorativa;
      avisoMin = o.avisoMin ?? kAvisoDiaTodoPadrao;
      if (semData) data = inicioDoDia(DateTime.now());
      minutos = o.duracao.inMinutes;
      repeticao = o.repeticao;
      destino = o.agendaDestinoId;
      _localAuto = o.local == null;
      _quandoAuto = _duracaoAuto = _repeticaoAuto = false;
      return;
    }

    final agora = DateTime.now();
    final inicio = widget.inicio ?? DateTime(agora.year, agora.month, agora.day, agora.hour + 1);
    data = inicioDoDia(inicio);
    horaInicio = TimeOfDay.fromDateTime(inicio);
    destino = state.agendaDestinoPadrao;
    if (widget.inicio != null) _quandoAuto = false;
    if (widget.fim != null) {
      minutos = widget.fim!.difference(inicio).inMinutes;
      _duracaoAuto = false;
    }
    if (widget.tipoInicial != null) escolherTipo(widget.tipoInicial);
    if (widget.itemId != null) escolherItem(widget.itemId);
  }

  @override
  void dispose() {
    for (final c in [titulo, local, notas]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ derivados

  /// Tabela dos chips de item: a da célula, senão a ativa.
  Tabela? get tabela => _state.tabelaPorId(widget.tabelaId) ?? _state.tabelaAtiva;

  /// Itens que aparecem nas células da [tabela], na ordem da semana — mais
  /// o escolhido, se veio de outra tabela, pra ele continuar visível.
  List<Item> get itensDaTabela {
    final ids = <String>[];
    final t = tabela;
    if (t != null) {
      for (var slot = 0; slot < t.qtdHorarios; slot++) {
        for (final dia in t.dias) {
          final id = t.celula(dia, slot);
          if (id != null && !ids.contains(id)) ids.add(id);
        }
      }
    }
    if (itemId != null && !ids.contains(itemId)) ids.insert(0, itemId!);
    return [for (final id in ids) ?_state.itemPorId(id)];
  }

  Item? get item => _state.itemPorId(itemId);

  bool get ehTarefa => tipo == TipoEvento.tarefa;

  /// Próximo horário do item: na tabela da folha primeiro, depois nas outras.
  ({DateTime inicio, DateTime fim})? get proximoDoItem {
    final id = itemId;
    if (id == null) return null;
    final agora = DateTime.now();
    final t = tabela;
    for (final tab in [?t, ..._state.tabelas.where((x) => x.id != t?.id)]) {
      final p = proximoHorarioDoItem(tab, id, agora);
      if (p != null) return p;
    }
    return null;
  }

  /// Duração do bloco do item na tabela, pro chip "Horário de SO".
  int? get minutosDoItem {
    final p = proximoDoItem;
    return p?.fim.difference(p.inicio).inMinutes;
  }

  /// O que vira título se o campo ficar vazio: "Prova · Sistemas
  /// Operacionais". "Outro" não entra — não diz nada.
  String get tituloAutomatico => [
        if (tipo != null && tipo != TipoEvento.outro) tipo!.rotulo,
        ?item?.nome,
      ].join(' · ');

  /// Inícios sugeridos: o começo de cada horário da tabela (é onde as
  /// coisas costumam cair). Sem tabela, uns horários redondos. O horário
  /// atual entra se não estiver na lista, pra continuar visível.
  List<TimeOfDay> get sugestoesDeHorario {
    final t = tabela;
    final horas = t == null
        ? const [8, 10, 14, 19]
        : [
            for (var i = 0; i < t.qtdHorarios; i++)
              if (t.horaInicial + i * t.intervalo < 24) t.horaInicial + i * t.intervalo,
          ];
    final lista = [for (final h in horas) TimeOfDay(hour: h, minute: 0)];
    if (!lista.contains(horaInicio)) {
      lista
        ..add(horaInicio)
        ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    }
    return lista;
  }

  /// Sigla do item vinculado se ele ocupa o horário [h] no dia escolhido,
  /// na tabela da folha — "10:00 · SO" ajuda a achar o horário da aula.
  /// Sem item vinculado, nada: marcar o horário de outra matéria só
  /// confunde.
  String? siglaNoHorario(TimeOfDay h) {
    final t = tabela;
    final id = itemId;
    if (t == null || id == null || h.minute != 0) return null;
    final slot = (h.hour - t.horaInicial) ~/ t.intervalo;
    if ((h.hour - t.horaInicial) % t.intervalo != 0 || slot < 0 || slot >= t.qtdHorarios) return null;
    final dia = kTodosDias[data.weekday - 1];
    if (!t.dias.contains(dia)) return null;
    return t.celula(dia, slot) == id ? item?.sigla : null;
  }

  /// Locais pra escolher sem digitar: o do item escolhido primeiro, depois
  /// os dos outros itens da tabela.
  List<String> get locaisSugeridos {
    final vistos = <String>{};
    return [
      for (final l in [?item?.local, for (final i in itensDaTabela) ?i.local])
        if (l.trim().isNotEmpty && vistos.add(l.trim())) l.trim(),
    ].take(5).toList();
  }

  // --------------------------------------------------------------- ações

  void escolherTipo(TipoEvento? t) => setState(() {
        tipo = tipo == t ? null : t;
        _tipoMexido = true;
        if (!ehTarefa) semData = false;
        final atual = tipo;
        if (atual == null) return;
        if (_duracaoAuto) _aplicarDuracao(atual.duracao);
        if (_repeticaoAuto) repeticao = atual.repeticao;
      });

  void _aplicarDuracao(DuracaoPadrao d) {
    switch (d) {
      case DuracaoPadrao.diaTodo:
        diaTodo = true;
      case DuracaoPadrao.prazo:
        diaTodo = false;
        minutos = 0;
      case DuracaoPadrao.umaHora:
        diaTodo = false;
        minutos = 60;
      case DuracaoPadrao.horarioDoItem:
        diaTodo = false;
        minutos = minutosDoItem ?? 120;
    }
  }

  void escolherItem(String? id) => setState(() {
        itemId = itemId == id ? null : id;
        final i = item;
        if (_localAuto) local.text = i?.local ?? '';
        final p = proximoDoItem;
        if (_quandoAuto && p != null) {
          data = inicioDoDia(p.inicio);
          horaInicio = TimeOfDay.fromDateTime(p.inicio);
        }
        if (_duracaoAuto && i != null &&
            (tipo == null || tipo!.duracao == DuracaoPadrao.horarioDoItem)) {
          _aplicarDuracao(DuracaoPadrao.horarioDoItem);
        }
      });

  void usarProximoDoItem() => setState(() {
        final p = proximoDoItem!;
        data = inicioDoDia(p.inicio);
        horaInicio = TimeOfDay.fromDateTime(p.inicio);
        _quandoAuto = false;
      });

  void escolherData(DateTime d) => setState(() {
        data = inicioDoDia(d);
        semData = false;
        _quandoAuto = false;
      });

  void escolherSemData() => setState(() {
        semData = true;
        _quandoAuto = false;
      });

  /// Tarefa: "Sem hora" (vale o dia, aviso de manhã) ou uma hora-prazo.
  void escolherSemHora() => setState(() {
        diaTodo = true;
        _duracaoAuto = false;
      });

  void escolherAviso(int min) => setState(() => avisoMin = min);

  Future<void> escolherAvisoOutro() async {
    final h = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: avisoMin ~/ 60, minute: avisoMin % 60),
      helpText: 'Avisar a que horas?',
    );
    if (h != null) escolherAviso(h.hour * 60 + h.minute);
  }

  Future<void> escolherDataNoCalendario() async {
    final d = await showDatePicker(
      context: context,
      initialDate: data,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) escolherData(d);
  }

  void escolherHora(TimeOfDay h) => setState(() {
        horaInicio = h;
        _quandoAuto = false;
        // Tarefa não tem duração: hora escolhida é o prazo.
        if (ehTarefa) {
          diaTodo = false;
          minutos = 0;
          _duracaoAuto = false;
        }
      });

  Future<void> escolherHoraInicio() async {
    final h = await showTimePicker(context: context, initialTime: horaInicio);
    if (h != null) escolherHora(h);
  }

  void escolherDuracao({bool diaInteiro = false, int? min}) => setState(() {
        diaTodo = diaInteiro;
        if (min != null) minutos = min;
        _duracaoAuto = false;
      });

  /// "Outra…": pergunta até que horas, a partir do início.
  Future<void> escolherDuracaoOutra() async {
    final ate = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (horaInicio.hour + 1) % 24,
        minute: horaInicio.minute,
      ),
      helpText: 'Até que horas?',
    );
    if (ate == null) return;
    final m = (ate.hour * 60 + ate.minute) - (horaInicio.hour * 60 + horaInicio.minute);
    if (m > 0) escolherDuracao(min: m);
  }

  void alternarFolga() => setState(() => folga = !folga);

  void escolherRepeticao(Repeticao r) => setState(() {
        repeticao = r;
        _repeticaoAuto = false;
      });

  void escolherDestino(String? id) => setState(() {
        destino = id;
        _destinoMexido = true;
      });

  /// Escolheu um local (ou nenhum): deixa de acompanhar o item.
  void escolherLocal(String? l) => setState(() {
        local.text = l ?? '';
        _localAuto = false;
      });

  /// "Digitar…" no menu do local: caixinha com o texto atual.
  Future<void> digitarLocal() async {
    final c = TextEditingController(text: local.text);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Local'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Sala, endereço, link...'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('OK')),
        ],
      ),
    );
    // Sem dispose aqui: o diálogo ainda anima a saída usando o controller.
    if (r != null) escolherLocal(r.trim());
  }

  Future<void> salvar() async {
    final messenger = ScaffoldMessenger.of(context);
    final tituloFinal = titulo.text.trim().isNotEmpty ? titulo.text.trim() : tituloAutomatico;
    if (tituloFinal.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Escolha um tipo, um item ou dê um título.')),
      );
      return;
    }

    final semDataFinal = ehTarefa && semData;
    final diaTodoFinal = diaTodo || semDataFinal;
    final inicio = semDataFinal
        ? (widget.original?.inicio ?? inicioDoDia(DateTime.now()))
        : diaTodo
        ? data
        : DateTime(data.year, data.month, data.day, horaInicio.hour, horaInicio.minute);
    String? opcional(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    // Tipo antigo em texto livre que não bate com a lista: se não mexeu, o
    // texto original fica (não vira "Outro" em silêncio).
    final tipoTexto = !_tipoMexido && widget.original != null && tipo == TipoEvento.outro
        ? widget.original!.tipo
        : (tipo?.rotulo ?? '');

    final evento = Evento(
      id: widget.original?.id ?? gerarId(),
      titulo: tituloFinal,
      inicio: inicio,
      fim: diaTodoFinal ? null : inicio.add(Duration(minutes: minutos)),
      diaInteiro: diaTodoFinal,
      tipo: tipoTexto,
      repeticao: semDataFinal ? Repeticao.nenhuma : repeticao,
      itemId: itemId,
      local: opcional(local),
      notas: opcional(notas),
      semData: semDataFinal,
      // O formulário não mexe em "feito": herda do que estava salvo.
      feito: widget.original?.feito ?? false,
      feitas: widget.original?.feitas ?? const {},
      avisoMin: diaTodoFinal && !semDataFinal && avisoMin != kAvisoDiaTodoPadrao ? avisoMin : null,
      comemorativa: tipo == TipoEvento.feriado && !folga,
    );

    final state = _state;
    final navigator = Navigator.of(context);
    final ok = novo
        ? await state.adicionarEvento(evento, salvarEm: destino)
        : await state.atualizarEvento(evento, salvarEm: destino);
    if (destino == null && _destinoMexido) await state.esquecerDestino();
    navigator.pop();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Salvo no app, mas não deu pra gravar no Google Agenda.')),
      );
    }
  }

  Future<void> apagar() async {
    final o = widget.original!;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Apagar ${o.titulo}?'),
        content: Text(
          o.repeticao == Repeticao.nenhuma
              ? 'O evento vai sumir de todas as telas.'
              : 'Todas as repetições deste evento vão sumir.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Apagar')),
        ],
      ),
    );
    if (!(confirmou ?? false) || !mounted) return;
    final navigator = Navigator.of(context);
    await _state.removerEvento(o.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    return _AcompanhaTeclado(child: CorpoDaFolha(f: this));
  }
}

/// Sobe a folha junto com o teclado. Separado de propósito: o teclado muda
/// o MediaQuery a cada quadro da animação, e só este padding precisa
/// redesenhar — o corpo (o mesmo widget) fica quieto. Antes a folha toda
/// era refeita a cada quadro, e o teclado engasgava.
class _AcompanhaTeclado extends StatelessWidget {
  const _AcompanhaTeclado({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: child);
}
