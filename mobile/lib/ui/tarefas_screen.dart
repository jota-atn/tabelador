import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../model/item.dart';
import '../state/app_state.dart';
import '../theme/color_density.dart';
import '../theme/tipo_evento_visual.dart';
import '../util/tarefas.dart';
import 'folha_evento.dart';
import 'tarefas_acoes.dart';
import 'widgets/evento_tile.dart';

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
  bool _mostrarConcluidas = false;
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

  bool get _filtrando => _periodo != PeriodoTarefas.todas || _itemId != null;

  // ----------------------------------------------------------- ações

  Future<void> _marcar(LinhaTarefa l, bool feita) async {
    if (feita) {
      final secao = secaoPelaData(l.ocorrencia, DateTime.now());
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

  Future<void> _abrirOpcoes(List<Item> itens) async {
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
    var todas = organizarTarefas(tarefas, agora);
    // Recém-concluída fica riscada na seção de antes.
    todas = [
      for (final l in todas) _recentesPorEvento(l) ?? l,
    ];
    final concluidasTotal = todas.where((l) => l.secao == SecaoTarefa.concluidas).length;
    final linhas = [
      for (final l in todas)
        if ((l.secao != SecaoTarefa.concluidas || _mostrarConcluidas) &&
            (l.secao == SecaoTarefa.concluidas || _periodo.aceita(l.secao)) &&
            (_itemId == null || l.ocorrencia.evento.itemId == _itemId) &&
            (termo.isEmpty || l.ocorrencia.evento.titulo.toLowerCase().contains(termo)))
          l,
    ]..sort((a, b) => a.secao.index.compareTo(b.secao.index));

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
                    onPressed: () => _abrirOpcoes(itensUsados),
                  ),
                ],
              ),
        floatingActionButton: _selecionando
            ? null
            : FloatingActionButton.extended(
                onPressed: () => abrirFolhaDeEvento(context, tipo: TipoEvento.tarefa),
                icon: const Icon(Icons.add_task),
                label: const Text('Nova tarefa'),
              ),
        body: linhas.isEmpty
            ? _Vazio(
                temTarefas: tarefas.isNotEmpty,
                concluidas: concluidasTotal,
                aoMostrarConcluidas: concluidasTotal > 0 && !_mostrarConcluidas
                    ? () => setState(() => _mostrarConcluidas = true)
                    : null,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                children: [
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
              ),
      ),
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
        icone: Icons.delete_outline,
        texto: 'Apagar',
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
