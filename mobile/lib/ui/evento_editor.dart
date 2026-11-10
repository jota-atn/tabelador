import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../model/item.dart';
import '../state/app_state.dart';
import '../util/formato_data.dart';
import '../util/id.dart';
import 'widgets/largura_maxima.dart';

/// Cadastro e edição de um [Evento].
///
/// [original] nulo é evento novo. [itemId] e [inicio] pré-preenchem vínculo
/// e data/hora — é assim que "+ evento" na tela de um item já chega
/// vinculado, e (no próximo lote) que o toque longo numa célula já chega com
/// o horário dela.
class EventoEditor extends StatefulWidget {
  const EventoEditor({super.key, this.original, this.itemId, this.inicio});

  final Evento? original;
  final String? itemId;
  final DateTime? inicio;

  @override
  State<EventoEditor> createState() => _EventoEditorState();
}

class _EventoEditorState extends State<EventoEditor> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titulo;
  late final TextEditingController _tipo;
  late final TextEditingController _local;
  late final TextEditingController _notas;

  late DateTime _data;
  late TimeOfDay _horaInicio;
  late TimeOfDay _horaFim;
  late bool _diaInteiro;
  late Repeticao _repeticao;
  String? _itemId;

  /// Como a sigla do item: enquanto o usuário não digitar um título à mão,
  /// ele acompanha tipo + item ("Prova · Sistemas Operacionais"). Cobre o
  /// caso mais comum sem precisar digitar nada.
  bool _tituloAutomatico = true;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    final inicio = o?.inicio ?? widget.inicio ?? _proximaHoraCheia();
    final fim = o?.fim ?? inicio.add(const Duration(hours: 1));

    _titulo = TextEditingController(text: o?.titulo ?? '');
    _tipo = TextEditingController(text: o?.tipo ?? '');
    _local = TextEditingController(text: o?.local ?? '');
    _notas = TextEditingController(text: o?.notas ?? '');
    _data = inicioDoDia(inicio);
    _horaInicio = TimeOfDay.fromDateTime(inicio);
    _horaFim = TimeOfDay.fromDateTime(fim);
    _diaInteiro = o?.diaInteiro ?? false;
    _repeticao = o?.repeticao ?? Repeticao.nenhuma;
    _itemId = o?.itemId ?? widget.itemId;
    _tituloAutomatico = o == null;

    if (_tituloAutomatico) _tipo.addListener(_atualizarTituloAutomatico);
  }

  static DateTime _proximaHoraCheia() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day, agora.hour + 1);
  }

  @override
  void dispose() {
    for (final c in [_titulo, _tipo, _local, _notas]) {
      c.dispose();
    }
    super.dispose();
  }

  void _atualizarTituloAutomatico() {
    if (!_tituloAutomatico) return;
    final item = context.read<AppState>().itemPorId(_itemId);
    final partes = [
      if (_tipo.text.trim().isNotEmpty) _tipo.text.trim(),
      if (item != null) item.nome,
    ];
    _titulo.text = partes.join(' · ');
  }

  int _minutos(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _escolherHora({required bool inicio}) async {
    final escolhida = await showTimePicker(
      context: context,
      initialTime: inicio ? _horaInicio : _horaFim,
    );
    if (escolhida == null) return;
    setState(() {
      if (inicio) {
        // Arrastar o início leva o fim junto, mantendo a duração — o mesmo
        // que o Google Agenda faz, e evita fim antes do início.
        final duracao = _minutos(_horaFim) - _minutos(_horaInicio);
        _horaInicio = escolhida;
        final novoFim = (_minutos(escolhida) + duracao).clamp(0, 23 * 60 + 59);
        _horaFim = TimeOfDay(hour: novoFim ~/ 60, minute: novoFim % 60);
      } else {
        _horaFim = escolhida;
      }
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_diaInteiro && _minutos(_horaFim) < _minutos(_horaInicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O término é antes do início.')),
      );
      return;
    }

    final state = context.read<AppState>();
    String? opcional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    DateTime naData(TimeOfDay t) =>
        DateTime(_data.year, _data.month, _data.day, t.hour, t.minute);
    final inicio = _diaInteiro ? _data : naData(_horaInicio);
    final fim = _diaInteiro ? null : naData(_horaFim);

    final evento = Evento(
      id: widget.original?.id ?? gerarId(),
      titulo: _titulo.text.trim(),
      inicio: inicio,
      fim: fim,
      diaInteiro: _diaInteiro,
      tipo: _tipo.text.trim(),
      repeticao: _repeticao,
      itemId: _itemId,
      local: opcional(_local),
      notas: opcional(_notas),
    );

    if (widget.original == null) {
      await state.adicionarEvento(evento);
    } else {
      await state.atualizarEvento(evento);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _apagar() async {
    final original = widget.original!;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Apagar ${original.titulo}?'),
        content: Text(
          original.repeticao == Repeticao.nenhuma
              ? 'O evento vai sumir de todas as telas.'
              : 'Todas as repetições deste evento vão sumir.',
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
    if (!(confirmou ?? false) || !mounted) return;
    await context.read<AppState>().removerEvento(original.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final novo = widget.original == null;
    final scheme = Theme.of(context).colorScheme;

    // Arquivado não é oferecido pra vínculo novo, mas se o evento já aponta
    // pra um, ele continua na lista — senão o Dropdown estoura.
    final itensVinculaveis = [
      for (final i in state.itens)
        if (!i.arquivado || i.id == _itemId) i,
    ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: Text(novo ? 'Novo evento' : 'Editar evento'),
        actions: [
          if (!novo)
            IconButton(
              onPressed: _apagar,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Apagar',
            ),
          TextButton(onPressed: _salvar, child: const Text('Salvar')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LarguraMaxima(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              TextFormField(
                controller: _titulo,
                autofocus: novo && _itemId == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Prova, Aniversário de Pedro, Consulta...',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                onChanged: (_) => _tituloAutomatico = false,
              ),
              const SizedBox(height: 16),
              _CampoTipoEvento(
                controller: _tipo,
                conhecidos: state.tiposDeEventoConhecidos,
              ),
              const SizedBox(height: 16),
              _SeletorDeItem(
                itens: itensVinculaveis,
                selecionado: _itemId,
                aoEscolher: (id) {
                  setState(() => _itemId = id);
                  _atualizarTituloAutomatico();
                },
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dia todo'),
                value: _diaInteiro,
                onChanged: (v) => setState(() => _diaInteiro = v),
              ),
              _LinhaDeEscolha(
                icone: Icons.calendar_today_outlined,
                rotulo: 'Data',
                valor:
                    '${diaAbreviado(_data).toLowerCase()}, ${dataCompleta(_data)}',
                aoTocar: _escolherData,
              ),
              if (!_diaInteiro) ...[
                _LinhaDeEscolha(
                  icone: Icons.schedule,
                  rotulo: 'Início',
                  valor: _horaInicio.format(context),
                  aoTocar: () => _escolherHora(inicio: true),
                ),
                _LinhaDeEscolha(
                  icone: Icons.schedule_outlined,
                  rotulo: 'Término',
                  valor: _horaFim.format(context),
                  aoTocar: () => _escolherHora(inicio: false),
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<Repeticao>(
                initialValue: _repeticao,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Repetição'),
                items: [
                  for (final r in Repeticao.values)
                    DropdownMenuItem(value: r, child: Text(r.rotulo)),
                ],
                onChanged: (r) => setState(() => _repeticao = r ?? _repeticao),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _local,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Local'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notas,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Conteúdo da prova, o que levar...',
                ),
              ),
              if (_repeticao != Repeticao.nenhuma && !novo) ...[
                const SizedBox(height: 16),
                Text(
                  'Mudanças valem pra todas as repetições.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaDeEscolha extends StatelessWidget {
  const _LinhaDeEscolha({
    required this.icone,
    required this.rotulo,
    required this.valor,
    required this.aoTocar,
  });

  final IconData icone;
  final String rotulo;
  final String valor;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icone),
      title: Text(rotulo),
      trailing: Text(valor, style: Theme.of(context).textTheme.titleSmall),
      onTap: aoTocar,
    );
  }
}

/// Igual ao campo de tipo do item, com vocabulário próprio de evento.
class _CampoTipoEvento extends StatelessWidget {
  const _CampoTipoEvento({required this.controller, required this.conhecidos});

  final TextEditingController controller;
  final List<String> conhecidos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Tipo'),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final tipo in conhecidos)
              ActionChip(
                label: Text(tipo),
                onPressed: () => controller.text = tipo,
              ),
          ],
        ),
      ],
    );
  }
}

class _SeletorDeItem extends StatelessWidget {
  const _SeletorDeItem({
    required this.itens,
    required this.selecionado,
    required this.aoEscolher,
  });

  final List<Item> itens;
  final String? selecionado;
  final ValueChanged<String?> aoEscolher;

  @override
  Widget build(BuildContext context) {
    final valor =
        selecionado != null && itens.any((i) => i.id == selecionado)
            ? selecionado
            : null;

    return DropdownButtonFormField<String?>(
      initialValue: valor,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Item vinculado'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Nenhum (evento avulso)')),
        for (final item in itens)
          DropdownMenuItem(
            value: item.id,
            child: Text('${item.nome} (${item.sigla})',
                overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: aoEscolher,
    );
  }
}
