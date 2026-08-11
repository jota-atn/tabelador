import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/tabela.dart';
import '../state/app_state.dart';

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
    builder: (_) => _ConfigTabela(original: original),
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

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Apagar ${tabela.nome}?'),
        content: Text(
          _preenchidas == 0
              ? 'A tabela está vazia.'
              : 'Os $_preenchidas horários preenchidos vão junto. '
                  'Os itens continuam cadastrados.',
        ),
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
        onTap: () => context.read<AppState>().definirTabelaAtiva(tabela.id),
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
                  'apagar' => _apagar(context),
                  _ => null,
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'renomear', child: Text('Renomear')),
                  PopupMenuItem(value: 'configurar', child: Text('Horários')),
                  PopupMenuItem(value: 'duplicar', child: Text('Duplicar')),
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
class _ConfigTabela extends StatefulWidget {
  const _ConfigTabela({this.original});

  final Tabela? original;

  @override
  State<_ConfigTabela> createState() => _ConfigTabelaState();
}

class _ConfigTabelaState extends State<_ConfigTabela> {
  late final TextEditingController _nome;
  late int _horaInicial;
  late int _intervalo;
  late int _qtdHorarios;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _nome = TextEditingController(text: o?.nome ?? '');
    _horaInicial = o?.horaInicial ?? 8;
    _intervalo = o?.intervalo ?? 2;
    _qtdHorarios = o?.qtdHorarios ?? 6;
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  /// Quantas células o usuário perde se confirmar. Zero quando a tabela cresce
  /// ou é nova.
  int get _perdidas =>
      widget.original?.celulasPerdidasAo(_qtdHorarios) ?? 0;

  List<String> get _previaHorarios => [
        for (var i = 0; i < _qtdHorarios; i++)
          '${_horaInicial + i * _intervalo}:00',
      ];

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) return;

    final state = context.read<AppState>();
    final original = widget.original;

    if (original == null) {
      await state.adicionarTabela(
        Tabela.nova(
          nome: nome,
          horaInicial: _horaInicial,
          intervalo: _intervalo,
          qtdHorarios: _qtdHorarios,
        ),
      );
    } else {
      await state.atualizarTabela(
        original.copyWith(
          nome: nome,
          horaInicial: _horaInicial,
          intervalo: _intervalo,
          qtdHorarios: _qtdHorarios,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final novo = widget.original == null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            novo ? 'Nova tabela' : 'Horários de ${widget.original!.nome}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nome,
            autofocus: novo,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: '2026.1',
            ),
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
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _salvar,
                child: Text(novo ? 'Criar' : 'Salvar'),
              ),
            ],
          ),
        ],
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
