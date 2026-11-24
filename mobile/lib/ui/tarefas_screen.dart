import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../model/item.dart';
import '../state/app_state.dart';
import '../theme/color_density.dart';
import '../theme/tipo_evento_visual.dart';
import '../util/formato_data.dart';
import '../util/tarefas.dart';
import 'folha_evento.dart';
import 'tarefas_acoes.dart';
import 'widgets/evento_tile.dart';
import 'widgets/item_swatch.dart';

/// Filtro de período da página (opções de listagem).
enum PeriodoTarefas {
  todas('Todas'),
  hoje('Hoje'),
  semana('Esta semana'),
  atrasadas('Atrasadas'),
  semData('Sem data');

  const PeriodoTarefas(this.rotulo);
  final String rotulo;

  bool aceita(SecaoTarefa s) => switch (this) {
        PeriodoTarefas.todas => true,
        PeriodoTarefas.hoje => s == SecaoTarefa.hoje,
        PeriodoTarefas.semana => s == SecaoTarefa.hoje || s == SecaoTarefa.semana,
        PeriodoTarefas.atrasadas => s == SecaoTarefa.atrasadas,
        PeriodoTarefas.semData => s == SecaoTarefa.semData,
      };
}

/// De onde a tarefa vem: criada no app ou de uma agenda do Google com tipo
/// Tarefa (turma do Classroom).
enum OrigemTarefas {
  todas('Todas'),
  app('Do app'),
  google('Do Google');

  const OrigemTarefas(this.rotulo);
  final String rotulo;

  bool aceita(Evento e) => switch (this) {
        OrigemTarefas.todas => true,
        OrigemTarefas.app => !e.externo,
        OrigemTarefas.google => e.externo,
      };
}

/// Todas as tarefas, por seção (atrasadas, hoje, semana, mais tarde, sem
/// data, concluídas).
///
/// Gestos: caixinha conclui; arrastar → conclui, ← apaga (os dois com
/// Desfazer); tocar abre o card; segurar entra no modo de seleção
/// (concluir/apagar várias). Concluída fica riscada no lugar ~2s antes de
/// descer pra "Concluídas".
class TarefasScreen extends StatefulWidget {
  const TarefasScreen({super.key});

  @override
  State<TarefasScreen> createState() => _TarefasScreenState();
}

class _TarefasScreenState extends State<TarefasScreen> {
  static const _tempoRiscada = Duration(seconds: 2);

  PeriodoTarefas _periodo = PeriodoTarefas.todas;
  String? _itemId;
  OrigemTarefas _origem = OrigemTarefas.todas;
  /// Lembrado entre aberturas (preferência do aparelho).
  bool get _mostrarConcluidas => context.read<AppState>().concluidasVisiveis;
  set _mostrarConcluidas(bool v) => context.read<AppState>().definirConcluidasVisiveis(v);
  bool _buscando = false;
  final _busca = TextEditingController();

  /// Chave da linha → seção onde ela estava antes de concluir: fica ali,
  /// riscada, até o timer tirar.
  final Map<String, (LinhaTarefa, Timer)> _recentes = {};

  /// Ids de evento selecionados (modo de seleção).
  final Set<String> _selecionados = {};
  bool get _selecionando => _selecionados.isNotEmpty;

  @override
  void dispose() {
    for (final (_, t) in _recentes.values) {
      t.cancel();
    }
    _busca.dispose();
    super.dispose();
  }

  bool get _filtrando =>
      _periodo != PeriodoTarefas.todas || _itemId != null || _origem != OrigemTarefas.todas;

  // ----------------------------------------------------------- ações

  Future<void> _marcar(LinhaTarefa l, bool feita) async {
    if (feita) {
      final secao = secaoPelaData(l.ocorrencia, DateTime.now(), context.read<AppState>().primeiroDiaDaSemana);
      _recentes[l.chave]?.$2.cancel();
      _recentes[l.chave] = (
        LinhaTarefa(l.ocorrencia, secao),
        Timer(_tempoRiscada, () {
          if (mounted) setState(() => _recentes.remove(l.chave));
        }),
      );
    } else {
      _recentes.remove(l.chave)?.$2.cancel();
    }
    await marcarTarefa(context, l.ocorrencia, feita);
  }

  void _alternarSelecao(String id) => setState(() {
        if (!_selecionados.remove(id)) _selecionados.add(id);
      });

  Future<void> _concluirSelecionadas(List<LinhaTarefa> linhas) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final alvo = [
      for (final l in linhas)
        if (_selecionados.contains(l.ocorrencia.evento.id) && !l.ocorrencia.feita) l.ocorrencia,
    ];
    setState(_selecionados.clear);
    for (final o in alvo) {
      await state.marcarFeita(o, true);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(alvo.length == 1 ? '1 tarefa concluída' : '${alvo.length} tarefas concluídas'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () async {
              for (final o in alvo) {
                final atual = state.eventoPorId(o.evento.id);
                if (atual != null) await state.marcarFeita(Ocorrencia(atual, o.inicio, o.fim), false);
              }
            },
          ),
        ),
      );
  }

  Future<void> _apagarSelecionadas() async {
    final state = context.read<AppState>();
    final eventos = [for (final id in _selecionados) ?state.eventoPorId(id)];
    setState(_selecionados.clear);
    await apagarTarefas(context, eventos);
  }

  Future<void> _abrirOpcoes(List<Item> itens, {required bool temExternas}) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void mudar(VoidCallback f) {
            setState(f);
            setSheet(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mostrar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in PeriodoTarefas.values)
                        ChoiceChip(
                          label: Text(p.rotulo),
                          selected: _periodo == p,
                          onSelected: (_) => mudar(() => _periodo = p),
                        ),
                    ],
                  ),
                  if (temExternas || _origem != OrigemTarefas.todas) ...[
                    const SizedBox(height: 16),
                    const Text('Origem', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final o in OrigemTarefas.values)
                          ChoiceChip(
                            label: Text(o.rotulo),
                            selected: _origem == o,
                            onSelected: (_) => mudar(() => _origem = o),
                          ),
                      ],
                    ),
                  ],
                  if (itens.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Item', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: _itemId == null,
                          onSelected: (_) => mudar(() => _itemId = null),
                        ),
                        for (final i in itens)
                          ChoiceChip(
                            label: Text(i.sigla),
                            avatar: CircleAvatar(
                              backgroundColor: resolveCellStyle(
                                cor: i.cor,
                                densidade: ColorDensity.solido,
                                esquema: Theme.of(ctx).colorScheme,
                              ).background,
                            ),
                            selected: _itemId == i.id,
                            onSelected: (_) => mudar(() => _itemId = _itemId == i.id ? null : i.id),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar concluídas'),
                    value: _mostrarConcluidas,
                    onChanged: (v) => mudar(() => _mostrarConcluidas = v),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------- desenho

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final tarefas = state.tarefas;

    final itensUsados = <Item>[
      for (final id in {for (final t in tarefas) ?t.itemId}) ?state.itemPorId(id),
    ];

    final termo = _busca.text.trim().toLowerCase();
    var todas = organizarTarefas(tarefas, agora, state.primeiroDiaDaSemana);
    // Recém-concluída fica riscada na seção de antes.
    todas = [
      for (final l in todas) _recentesPorEvento(l) ?? l,
    ];
    final concluidasTotal = todas.where((l) => l.secao == SecaoTarefa.concluidas).length;
    final hoje = inicioDoDia(agora);
    final deHoje = [
      for (final l in todas)
        if (!l.ocorrencia.evento.semData && inicioDoDia(l.ocorrencia.inicio) == hoje) l,
    ];
    final progresso = _Progresso(
      feitas: deHoje.where((l) => l.ocorrencia.feita).length,
      total: deHoje.length,
      atrasadas: todas.where((l) => l.secao == SecaoTarefa.atrasadas).length,
      semana: todas.where((l) => l.secao == SecaoTarefa.semana).length,
    );
    final linhas = [
      for (final l in todas)
        if ((l.secao != SecaoTarefa.concluidas || _mostrarConcluidas) &&
            (l.secao == SecaoTarefa.concluidas || _periodo.aceita(l.secao)) &&
            (_itemId == null || l.ocorrencia.evento.itemId == _itemId) &&
            _origem.aceita(l.ocorrencia.evento) &&
            (termo.isEmpty || l.ocorrencia.evento.titulo.toLowerCase().contains(termo)))
          l,
    ]..sort(compararLinhas);

    final porSecao = <SecaoTarefa, List<LinhaTarefa>>{};
    for (final l in linhas) {
      (porSecao[l.secao] ??= []).add(l);
    }

    return PopScope(
      canPop: !_selecionando && !_buscando,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          _selecionados.clear();
          _buscando = false;
          _busca.clear();
        });
      },
      child: Scaffold(
        appBar: _selecionando
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancelar seleção',
                  onPressed: () => setState(_selecionados.clear),
                ),
                title: Text('${_selecionados.length}'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.check),
                    tooltip: 'Concluir',
                    onPressed: () => _concluirSelecionadas(linhas),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Apagar',
                    onPressed: _apagarSelecionadas,
                  ),
                ],
              )
            : AppBar(
                title: _buscando
                    ? TextField(
                        controller: _busca,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Pesquisar tarefas',
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => setState(() {}),
                      )
                    : const Text('Tarefas'),
                actions: [
                  IconButton(
                    icon: Icon(_buscando ? Icons.close : Icons.search),
                    tooltip: _buscando ? 'Fechar pesquisa' : 'Pesquisar',
                    onPressed: () => setState(() {
                      _buscando = !_buscando;
                      if (!_buscando) _busca.clear();
                    }),
                  ),
                  IconButton(
                    icon: Badge(
                      isLabelVisible: _filtrando,
                      smallSize: 8,
                      child: const Icon(Icons.filter_list),
                    ),
                    tooltip: 'Opções de listagem',
                    onPressed: () => _abrirOpcoes(
                      itensUsados,
                      temExternas: tarefas.any((t) => t.externo),
                    ),
                  ),
                ],
              ),
        body: Column(
          children: [
            Expanded(child: _corpo(linhas, porSecao, tarefas, concluidasTotal, progresso, scheme)),
            if (!_selecionando) const _AdicionarRapido(),
          ],
        ),
      ),
    );
  }

  Widget _corpo(
    List<LinhaTarefa> linhas,
    Map<SecaoTarefa, List<LinhaTarefa>> porSecao,
    List<Evento> tarefas,
    int concluidasTotal,
    _Progresso progresso,
    ColorScheme scheme,
  ) {
    // Sem filtro, a lista vazia ainda mostra o topo ("Dia limpo"): o vazio
    // genérico fica pra quando não há tarefa nenhuma ou o filtro esconde.
    final vazioDeVerdade = linhas.isEmpty && (tarefas.isEmpty || _filtrando || _buscando);
    return vazioDeVerdade
            ? _Vazio(
                temTarefas: tarefas.isNotEmpty,
                concluidas: concluidasTotal,
                aoMostrarConcluidas: concluidasTotal > 0 && !_mostrarConcluidas
                    ? () => setState(() => _mostrarConcluidas = true)
                    : null,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                children: [
                  if (!_buscando && !_filtrando) _TopoDoDia(p: progresso),
                  for (final secao in porSecao.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 14, 8, 2),
                      child: Text(
                        '${secao.key.rotulo} · ${secao.value.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: secao.key == SecaoTarefa.atrasadas
                              ? scheme.error
                              : secao.key == SecaoTarefa.hoje
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final l in secao.value) _linha(l, scheme),
                  ],
                  if (!_mostrarConcluidas && concluidasTotal > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _mostrarConcluidas = true),
                        icon: const Icon(Icons.expand_more),
                        label: Text(
                          concluidasTotal == 1 ? 'Mostrar 1 concluída' : 'Mostrar $concluidasTotal concluídas',
                        ),
                      ),
                    ),
                ],
              );
  }

  /// Recém-concluída: enquanto o timer corre, a linha mostra a ocorrência
  /// concluída (relida do estado, pra vir riscada) na seção de antes. Em
  /// tarefa que repete a lista já andou pra próxima ocorrência — esta toma
  /// o lugar dela até o timer acabar.
  LinhaTarefa? _recentesPorEvento(LinhaTarefa l) {
    for (final r in _recentes.values) {
      if (r.$1.ocorrencia.evento.id == l.ocorrencia.evento.id) {
        final atual = context.read<AppState>().eventoPorId(l.ocorrencia.evento.id);
        if (atual == null) return null;
        final o = r.$1.ocorrencia;
        return LinhaTarefa(Ocorrencia(atual, o.inicio, o.fim), r.$1.secao);
      }
    }
    return null;
  }

  Widget _linha(LinhaTarefa l, ColorScheme scheme) {
    final e = l.ocorrencia.evento;
    final feita = l.ocorrencia.feita;
    final verde = corDoTipo(TipoEvento.tarefa, scheme.brightness);
    return Dismissible(
      key: ValueKey(l.chave),
      direction: _selecionando ? DismissDirection.none : DismissDirection.horizontal,
      background: _FundoDoArraste(
        cor: verde,
        icone: feita ? Icons.undo : Icons.check,
        texto: feita ? 'Reabrir' : 'Concluir',
        alinhamento: Alignment.centerLeft,
      ),
      secondaryBackground: _FundoDoArraste(
        cor: scheme.error,
        icone: e.externo ? Icons.visibility_off_outlined : Icons.delete_outline,
        texto: e.externo ? 'Esconder' : 'Apagar',
        alinhamento: Alignment.centerRight,
      ),
      confirmDismiss: (direcao) async {
        if (direcao == DismissDirection.startToEnd) {
          await _marcar(l, !feita);
          return false; // a linha fica (riscada) e desce sozinha
        }
        return true;
      },
      onDismissed: (_) => apagarTarefas(context, [e]),
      child: EventoTile(
        ocorrencia: l.ocorrencia,
        colorido: true,
        selecionado: _selecionados.contains(e.id),
        aoMarcar: (v) => _marcar(l, v),
        aoSegurar: () => _alternarSelecao(e.id),
        aoTocar: _selecionando ? () => _alternarSelecao(e.id) : null,
      ),
    );
  }
}

class _FundoDoArraste extends StatelessWidget {
  const _FundoDoArraste({
    required this.cor,
    required this.icone,
    required this.texto,
    required this.alinhamento,
  });

  final Color cor;
  final IconData icone;
  final String texto;
  final Alignment alinhamento;

  @override
  Widget build(BuildContext context) {
    final sobre = ThemeData.estimateBrightnessForColor(cor) == Brightness.dark ? Colors.white : Colors.black;
    final conteudo = [
      Icon(icone, color: sobre),
      const SizedBox(width: 8),
      Text(texto, style: TextStyle(color: sobre, fontWeight: FontWeight.w600)),
    ];
    return Container(
      decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alinhamento,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alinhamento == Alignment.centerLeft ? conteudo : conteudo.reversed.toList(),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.temTarefas, required this.concluidas, this.aoMostrarConcluidas});

  final bool temTarefas;
  final int concluidas;
  final VoidCallback? aoMostrarConcluidas;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              temTarefas ? 'Nada pendente aqui.' : 'Nenhuma tarefa ainda.',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              temTarefas
                  ? 'Mude as opções de listagem pra ver outras.'
                  : 'Toque em "Nova tarefa". Pode ser sem data — só pra não esquecer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (aoMostrarConcluidas != null)
              TextButton(
                onPressed: aoMostrarConcluidas,
                child: Text(concluidas == 1 ? 'Mostrar 1 concluída' : 'Mostrar $concluidas concluídas'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Números do topo: as de hoje (feitas e total), atrasadas e o resto da
/// semana.
class _Progresso {
  const _Progresso({required this.feitas, required this.total, required this.atrasadas, required this.semana});

  final int feitas;
  final int total;
  final int atrasadas;
  final int semana;
}

/// Anel que enche com as de hoje ("Hoje: 2 de 5"; todas feitas = "Dia
/// limpo") e uma linha com atrasadas e o resto da semana. Sem nada hoje,
/// vira uma frase.
class _TopoDoDia extends StatelessWidget {
  const _TopoDoDia({required this.p});

  final _Progresso p;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final verde = corDoTipo(TipoEvento.tarefa, scheme.brightness);
    final limpo = p.total > 0 && p.feitas == p.total;
    final titulo = p.total == 0
        ? 'Nada pra hoje'
        : limpo
            ? 'Dia limpo'
            : 'Hoje: ${p.feitas} de ${p.total}';
    final resto = [
      if (p.atrasadas > 0) p.atrasadas == 1 ? '1 atrasada' : '${p.atrasadas} atrasadas',
      if (p.semana > 0) '${p.semana} no resto da semana',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          if (p.total > 0) ...[
            SizedBox.square(
              dimension: 52,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: p.feitas / p.total),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: v,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      color: verde,
                      backgroundColor: verde.withValues(alpha: 0.18),
                    ),
                    Center(
                      child: limpo
                          ? Icon(Icons.check, color: verde, size: 26)
                          : Text(
                              '${p.total - p.feitas}',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: scheme.onSurface),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    titulo,
                    key: ValueKey(titulo),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                if (resto.isNotEmpty)
                  Text(
                    resto.join(' · '),
                    style: TextStyle(
                      fontSize: 13,
                      color: p.atrasadas > 0 ? scheme.error : scheme.onSurfaceVariant,
                      fontWeight: p.atrasadas > 0 ? FontWeight.w600 : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo "Nova tarefa…" fixo embaixo. Ao digitar aparecem chips (Hoje,
/// Amanhã, data, item, prioridade); Enter cria sem abrir folha (sem chip
/// de dia = sem data). "Mais opções" (ao lado do campo) leva o que foi
/// escrito pra folha.
class _AdicionarRapido extends StatefulWidget {
  const _AdicionarRapido();

  @override
  State<_AdicionarRapido> createState() => _AdicionarRapidoState();
}

class _AdicionarRapidoState extends State<_AdicionarRapido> {
  final _texto = TextEditingController();
  final _foco = FocusNode();
  DateTime? _data;
  String? _itemId;
  Prioridade _prioridade = Prioridade.normal;

  @override
  void initState() {
    super.initState();
    _texto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  bool get _escrevendo => _texto.text.trim().isNotEmpty;

  void _limpar() {
    _texto.clear();
    setState(() {
      _data = null;
      _itemId = null;
      _prioridade = Prioridade.normal;
    });
  }

  Future<void> _criar() async {
    final titulo = _texto.text.trim();
    if (titulo.isEmpty) return;
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final evento = Evento.novo(
      titulo: titulo,
      inicio: _data ?? inicioDoDia(DateTime.now()),
      diaInteiro: true,
      semData: _data == null,
      tipo: TipoEvento.tarefa.rotulo,
      itemId: _itemId,
      prioridade: _prioridade,
    );
    _limpar();
    _foco.requestFocus(); // pronto pra próxima
    final ok = await state.adicionarEvento(evento, salvarEm: state.agendaDestinoPadrao);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Salvo no app, mas não deu pra gravar no Google Agenda.')),
      );
    }
  }

  Future<void> _maisOpcoes() async {
    final rascunho = (titulo: _texto.text.trim(), data: _data, prioridade: _prioridade);
    final itemId = _itemId;
    _limpar();
    _foco.unfocus();
    await abrirFolhaDeEvento(context, tipo: TipoEvento.tarefa, itemId: itemId, rascunho: rascunho);
  }

  Future<void> _escolherData() async {
    final hoje = inicioDoDia(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: _data ?? hoje,
      firstDate: hoje.subtract(const Duration(days: 365)),
      lastDate: hoje.add(const Duration(days: 365 * 3)),
    );
    if (d != null) setState(() => _data = inicioDoDia(d));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final hoje = inicioDoDia(DateTime.now());
    final amanha = hoje.add(const Duration(days: 1));
    final outroDia = _data != null && _data != hoje && _data != amanha;
    final itens = [for (final i in state.itens) if (!i.arquivado) i];
    final item = state.itemPorId(_itemId);

    void dia(DateTime d) => setState(() => _data = _data == d ? null : d);

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.bottomCenter,
                child: !_escrevendo
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('Hoje'),
                                selected: _data == hoje,
                                onSelected: (_) => dia(hoje),
                              ),
                              const SizedBox(width: 6),
                              FilterChip(
                                label: const Text('Amanhã'),
                                selected: _data == amanha,
                                onSelected: (_) => dia(amanha),
                              ),
                              const SizedBox(width: 6),
                              FilterChip(
                                avatar: outroDia ? null : const Icon(Icons.event, size: 18),
                                label: Text(outroDia ? '${diaAbreviado(_data!)} ${diaMes(_data!)}' : 'Data'),
                                selected: outroDia,
                                onSelected: (_) => _escolherData(),
                              ),
                              if (itens.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                PopupMenuButton<String?>(
                                  tooltip: 'Item',
                                  onSelected: (id) => setState(() => _itemId = id == '' ? null : id),
                                  itemBuilder: (_) => [
                                    if (_itemId != null) const PopupMenuItem(value: '', child: Text('Nenhum')),
                                    for (final i in itens)
                                      PopupMenuItem(
                                        value: i.id,
                                        child: Row(
                                          children: [
                                            ItemSwatch(
                                              cor: i.cor,
                                              densidade: state.densidade,
                                              texto: i.sigla,
                                              altura: 22,
                                              tamanhoTexto: 11,
                                              raio: 5,
                                            ),
                                            const SizedBox(width: 10),
                                            Flexible(child: Text(i.nome, overflow: TextOverflow.ellipsis)),
                                          ],
                                        ),
                                      ),
                                  ],
                                  child: IgnorePointer(
                                    child: FilterChip(
                                      avatar: item == null ? const Icon(Icons.label_outline, size: 18) : null,
                                      label: Text(item?.sigla ?? 'Item'),
                                      selected: item != null,
                                      onSelected: (_) {},
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              PopupMenuButton<Prioridade>(
                                tooltip: 'Prioridade',
                                initialValue: _prioridade,
                                onSelected: (p) => setState(() => _prioridade = p),
                                itemBuilder: (_) => [
                                  for (final p in Prioridade.values)
                                    PopupMenuItem(value: p, child: Text(p.rotulo)),
                                ],
                                child: IgnorePointer(
                                  child: FilterChip(
                                    avatar: Icon(
                                      iconeDaPrioridade(_prioridade) ?? Icons.flag_outlined,
                                      size: 18,
                                      color: _prioridade == Prioridade.alta ? scheme.error : null,
                                    ),
                                    label: Text(_prioridade == Prioridade.normal ? 'Prioridade' : _prioridade.rotulo),
                                    selected: _prioridade != Prioridade.normal,
                                    onSelected: (_) {},
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _texto,
                      focusNode: _foco,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _criar(),
                      decoration: InputDecoration(
                        hintText: 'Nova tarefa…',
                        prefixIcon: const Icon(Icons.add_task),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: _escrevendo
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Fora da fila de chips, que rola: sempre à vista.
                              IconButton(
                                onPressed: _maisOpcoes,
                                tooltip: 'Mais opções',
                                icon: const Icon(Icons.tune),
                              ),
                              IconButton.filled(
                                onPressed: _criar,
                                tooltip: 'Criar',
                                icon: const Icon(Icons.arrow_upward),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
