import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/tabela.dart';
import '../state/app_state.dart';
import 'tabela_editor_screen.dart';
import 'widgets/largura_maxima.dart';

/// Lista de tabelas: criar, renomear, duplicar, configurar, apagar e escolher
/// qual está ativa.
class TabelasScreen extends StatelessWidget {
  const TabelasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tabelas = state.tabelas;

    return Scaffold(
      appBar: AppBar(title: const Text('Tabelas')),
      floatingActionButton: FloatingActionButton(
        // As abas vivem juntas num IndexedStack, então os FABs coexistem e
        // precisam de tags de Hero distintas.
        heroTag: 'fab-tabelas',
        onPressed: () => _abrirConfig(context),
        tooltip: 'Nova tabela',
        child: const Icon(Icons.add),
      ),
      body: tabelas.isEmpty
          ? const _Vazio()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
              itemCount: tabelas.length,
              itemBuilder: (context, i) {
                final tabela = tabelas[i];
                return _CartaoTabela(
                  tabela: tabela,
                  ativa: tabela.id == state.tabelaAtivaId,
                );
              },
            ),
    );
  }
}

Future<void> _abrirConfig(BuildContext context, {Tabela? original}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ConfigTabela(original: original),
  );
}

/// Ativa [tabela] e empurra a tela de edição dela — a mesma grade + editor
/// de dia que a aba Semana usa, só que amarrada a esta tabela específica em
/// vez de "a que estiver ativa".
void _abrirTabela(BuildContext context, Tabela tabela) {
  context.read<AppState>().definirTabelaAtiva(tabela.id);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TabelaEditorScreen(tabelaId: tabela.id),
    ),
  );
}

class _CartaoTabela extends StatelessWidget {
  const _CartaoTabela({required this.tabela, required this.ativa});

  final Tabela tabela;
  final bool ativa;

  int get _preenchidas => tabela.celulas.values
      .expand((l) => l)
      .where((id) => id != null)
      .length;

  Future<void> _renomear(BuildContext context) async {
    final controller = TextEditingController(text: tabela.nome);
    final novo = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renomear tabela'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (novo != null && novo.isNotEmpty && context.mounted) {
      await context.read<AppState>().atualizarTabela(
            tabela.copyWith(nome: novo),
          );
    }
  }

  Future<void> _duplicar(BuildContext context) async {
    await context.read<AppState>().duplicarTabela(
          tabela.id,
          '${tabela.nome} (cópia)',
        );
  }

  Future<void> _apagar(BuildContext context) async {
    final state = context.read<AppState>();
    final itensExclusivos = state.itensExclusivosContagem(tabela.id);

    final partes = <String>[];
    if (_preenchidas > 0) {
      partes.add('Os $_preenchidas horários preenchidos vão junto.');
    }
    if (itensExclusivos > 0) {
      partes.add(
        itensExclusivos == 1
            ? '1 item que só existe nesta tabela também será apagado.'
            : '$itensExclusivos itens que só existem nesta tabela '
                'também serão apagados.',
      );
    }
    if (partes.isEmpty) {
      partes.add('A tabela está vazia.');
    } else if (_preenchidas > 0) {
      partes.add('Os demais itens continuam cadastrados.');
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Apagar ${tabela.nome}?'),
        content: Text(partes.join(' ')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmou ?? false) await state.removerTabela(tabela.id);
  }

  Future<void> _arquivarExclusivos(BuildContext context) async {
    final state = context.read<AppState>();
    final candidatos = state.itensExclusivosDe(tabela.id);

    if (candidatos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum item aparece só nesta tabela.')),
      );
      return;
    }

    final marcados = {for (final i in candidatos) i.id: true};

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final scheme = Theme.of(dialogContext).colorScheme;
          return AlertDialog(
            title: Text('Arquivar itens de ${tabela.nome}?'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Só aparecem nesta tabela. Desmarque os que você quer '
                      'manter na paleta pra reaproveitar depois.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    for (final item in candidatos)
                      CheckboxListTile(
                        value: marcados[item.id],
                        onChanged: (v) => setDialogState(
                          () => marcados[item.id] = v ?? false,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.nome),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Arquivar'),
              ),
            ],
          );
        },
      ),
    );

    if ((confirmou ?? false) && context.mounted) {
      final ids = marcados.entries.where((e) => e.value).map((e) => e.key);
      await state.arquivarItens(ids);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: ativa ? scheme.surfaceContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: ativa
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirTabela(context, tabela),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tabela.nome,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (ativa) ...[
                          const SizedBox(width: 8),
                          _Badge(scheme: scheme),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${tabela.qtdHorarios} horários · '
                      '${tabela.horarios.first.split('-').first}–'
                      '${tabela.horarios.last.split('-').last} · '
                      'intervalo de ${tabela.intervalo}h',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _preenchidas == 0
                          ? 'nenhum horário preenchido'
                          : '$_preenchidas preenchidos',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (opcao) => switch (opcao) {
                  'renomear' => _renomear(context),
                  'configurar' => _abrirConfig(context, original: tabela),
                  'duplicar' => _duplicar(context),
                  'arquivar_exclusivos' => _arquivarExclusivos(context),
                  'apagar' => _apagar(context),
                  _ => null,
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'renomear', child: Text('Renomear')),
                  PopupMenuItem(value: 'configurar', child: Text('Horários')),
                  PopupMenuItem(value: 'duplicar', child: Text('Duplicar')),
                  PopupMenuItem(
                    value: 'arquivar_exclusivos',
                    child: Text('Arquivar itens exclusivos'),
                  ),
                  PopupMenuItem(value: 'apagar', child: Text('Apagar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'ATIVA',
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Criação e configuração da grade: nome, hora inicial, intervalo, quantidade.
class ConfigTabela extends StatefulWidget {
  const ConfigTabela({super.key, this.original, this.aoCriar});

  final Tabela? original;

  /// Embutido (onboarding): em vez de fechar a folha e abrir a tabela, avisa
  /// quem embutiu. Sem título nem "Cancelar" — a tela de fora cuida disso.
  final ValueChanged<Tabela>? aoCriar;

  bool get embutido => aoCriar != null;

  @override
  State<ConfigTabela> createState() => ConfigTabelaState();
}

class ConfigTabelaState extends State<ConfigTabela> {
  late final TextEditingController _nome;
  late int _horaInicial;
  late int _intervalo;
  late int _qtdHorarios;
  late Set<String> _dias;
  late bool _mostrarEventos;
  late bool _pontoFacultativoFolga;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _nome = TextEditingController(text: o?.nome ?? '');
    _horaInicial = o?.horaInicial ?? 8;
    _intervalo = o?.intervalo ?? 2;
    _qtdHorarios = o?.qtdHorarios ?? 6;
    _dias = (o?.dias ?? kDiasPadrao).toSet();
    _mostrarEventos = o?.mostrarEventos ?? true;
    _pontoFacultativoFolga = o?.pontoFacultativoFolga ?? true;
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  List<String> get _diasSelecionados => ordenarDias(_dias);

  /// Quantas células o usuário perde se confirmar — soma o que se perde
  /// encolhendo a quantidade de horários com o que se perde tirando um dia
  /// que tinha célula preenchida. Zero quando a tabela só cresce, ou é nova.
  int get _perdidas =>
      (widget.original?.celulasPerdidasAo(_qtdHorarios) ?? 0) +
      (widget.original?.celulasPerdidasAoMudarDias(_diasSelecionados) ?? 0);

  List<String> get _previaHorarios => [
        for (var i = 0; i < _qtdHorarios; i++)
          '${_horaInicial + i * _intervalo}:00',
      ];

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) return;

    final state = context.read<AppState>();
    final navigator = Navigator.of(context);
    final original = widget.original;

    if (original == null) {
      final nova = Tabela.nova(
        nome: nome,
        horaInicial: _horaInicial,
        intervalo: _intervalo,
        qtdHorarios: _qtdHorarios,
        dias: _diasSelecionados,
      ).copyWith(
        mostrarEventos: _mostrarEventos,
        pontoFacultativoFolga: _pontoFacultativoFolga,
      );
      await state.adicionarTabela(nova);
      // Tabela recém-criada vira a ativa mesmo já havendo outra — é a que
      // acabou de virar o foco. `adicionarTabela` só ativa sozinha quando é
      // a primeira de todas.
      await state.definirTabelaAtiva(nova.id);
      if (widget.aoCriar != null) {
        widget.aoCriar!(nova);
        return;
      }
      navigator.pop();
      // Cria e já entra: é pra montar o horário dela que a pessoa acabou de
      // criar a tabela, não pra olhar de novo a lista.
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => TabelaEditorScreen(tabelaId: nova.id),
        ),
      );
      return;
    }

    await state.atualizarTabela(
      original.copyWith(
        nome: nome,
        horaInicial: _horaInicial,
        intervalo: _intervalo,
        qtdHorarios: _qtdHorarios,
        dias: _diasSelecionados,
        mostrarEventos: _mostrarEventos,
        pontoFacultativoFolga: _pontoFacultativoFolga,
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final novo = widget.original == null;

    return LarguraMaxima(
      child: Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: widget.embutido ? 0 : 20,
        bottom: (widget.embutido ? 0 : MediaQuery.viewInsetsOf(context).bottom) + 24,
      ),
      // Rolável: dias configuráveis somaram uma seção a mais, e o conteúdo
      // já não cabe sempre inteiro na altura disponível (tela menor, ou
      // teclado aberto).
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.embutido) ...[
            Text(
              novo ? 'Nova tabela' : 'Horários de ${widget.original!.nome}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _nome,
            autofocus: novo && !widget.embutido,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Trabalho, Academia, Rotina de setembro...',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Dias',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final dia in kTodosDias)
                FilterChip(
                  label: Text(kDiaAbreviado[dia]!),
                  selected: _dias.contains(dia),
                  onSelected: (marcado) => setState(() {
                    if (marcado) {
                      _dias.add(dia);
                    } else if (_dias.length > 1) {
                      // Nunca deixa zerar — uma tabela sem nenhum dia não
                      // tem coluna nenhuma pra mostrar.
                      _dias.remove(dia);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _Stepper(
            rotulo: 'Começa às',
            valor: '$_horaInicial:00',
            aoMudar: (d) => setState(
              () => _horaInicial = (_horaInicial + d).clamp(0, 22),
            ),
          ),
          _Stepper(
            rotulo: 'Duração de cada horário',
            valor: '${_intervalo}h',
            aoMudar: (d) => setState(
              () => _intervalo = (_intervalo + d).clamp(1, 6),
            ),
          ),
          _Stepper(
            rotulo: 'Quantos horários',
            valor: '$_qtdHorarios',
            aoMudar: (d) => setState(
              () => _qtdHorarios = (_qtdHorarios + d).clamp(1, 12),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _previaHorarios.join('   '),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar eventos avulsos'),
            subtitle: Text(
              'Eventos de itens desta tabela aparecem sempre.',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            value: _mostrarEventos,
            onChanged: (v) => setState(() => _mostrarEventos = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ponto facultativo é folga'),
            subtitle: Text(
              'Carnaval e Corpus Christi esmaecem as aulas, como feriado.',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            value: _pontoFacultativoFolga,
            onChanged: (v) => setState(() => _pontoFacultativoFolga = v),
          ),
          if (_perdidas > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _perdidas == 1
                          ? '1 horário preenchido será apagado.'
                          : '$_perdidas horários preenchidos serão apagados.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!widget.embutido) ...[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton(
                onPressed: _salvar,
                child: Text(widget.embutido ? 'Criar tabela' : novo ? 'Criar' : 'Salvar'),
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

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.rotulo,
    required this.valor,
    required this.aoMudar,
  });

  final String rotulo;
  final String valor;
  final ValueChanged<int> aoMudar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(rotulo, style: const TextStyle(fontSize: 14))),
          IconButton(
            onPressed: () => aoMudar(-1),
            icon: const Icon(Icons.remove),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 46,
            child: Text(
              valor,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            onPressed: () => aoMudar(1),
            icon: const Icon(Icons.add),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_rows_outlined,
              size: 32,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma tabela ainda',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Crie uma pra cada horário que você mantém — '
              'um semestre, o estágio, a academia.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
