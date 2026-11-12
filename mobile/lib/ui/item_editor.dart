import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../model/item.dart';
import '../model/tabela.dart';
import '../state/app_state.dart';
import '../theme/item_palette.dart';
import '../util/formato_data.dart';
import 'folha_evento.dart';
import 'widgets/evento_tile.dart';
import 'widgets/item_swatch.dart';
import 'widgets/largura_maxima.dart';

/// Cadastro e edição de um Item.
///
/// [original] nulo significa item novo. [tabelaId] pré-seleciona o vínculo no
/// seletor abaixo (ver [Item.tabelaId]) — quem abre o editor a partir do
/// "criar item só pra esta tabela" no editor do dia passa isso adiante, mas o
/// campo continua editável: dá pra vincular (ou desvincular) de qualquer
/// tabela existente na hora de cadastrar, sem precisar estar dentro dela.
class ItemEditor extends StatefulWidget {
  const ItemEditor({super.key, this.original, this.tabelaId});

  final Item? original;
  final String? tabelaId;

  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nome;
  late final TextEditingController _sigla;
  late final TextEditingController _tipo;
  late final TextEditingController _local;
  late final TextEditingController _notas;

  late ItemColor _cor;
  late String? _tabelaId;

  /// Enquanto o usuário não digitar sigla à mão, ela acompanha o nome. Assim o
  /// campo obrigatório se preenche sozinho no caso comum, sem impedir override.
  bool _siglaAutomatica = true;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _nome = TextEditingController(text: o?.nome ?? '');
    _sigla = TextEditingController(text: o?.sigla ?? '');
    _tipo = TextEditingController(text: o?.tipo ?? '');
    _local = TextEditingController(text: o?.local ?? '');
    _notas = TextEditingController(text: o?.notas ?? '');
    _cor = o?.cor ?? ItemColor.oceano;
    _tabelaId = o?.tabelaId ?? widget.tabelaId;
    _siglaAutomatica = o == null;
  }

  @override
  void dispose() {
    for (final c in [_nome, _sigla, _tipo, _local, _notas]) {
      c.dispose();
    }
    super.dispose();
  }

  /// "Programação Orientada a Objetos" -> "POO".
  /// "Cálculo" -> "CÁLCULO". Palavra curta como "a"/"de" não conta.
  static String _sugerirSigla(String nome) {
    final palavras = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.length > 2)
        .toList();
    if (palavras.isEmpty) return nome.trim().toUpperCase();
    if (palavras.length == 1) {
      return palavras.first.toUpperCase();
    }
    return palavras.map((p) => p[0]).join().toUpperCase();
  }

  void _aoDigitarNome(String valor) {
    if (!_siglaAutomatica) return;
    _sigla.text = _sugerirSigla(valor);
  }

  String? _naoVazio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final state = context.read<AppState>();
    String? opcional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final original = widget.original;
    if (original == null) {
      await state.adicionarItem(
        Item.novo(
          nome: _nome.text.trim(),
          sigla: _sigla.text.trim(),
          tipo: _tipo.text.trim(),
          cor: _cor,
          local: opcional(_local),
          notas: opcional(_notas),
          tabelaId: _tabelaId,
        ),
      );
    } else {
      // Reconstrói (não copyWith: local/notas precisam poder virar null de
      // novo se o campo for esvaziado, e copyWith trata null como "não
      // mudei"). Por isso arquivado, que o form não edita, é copiado
      // explícito — "esquecer" ele reseta pro default.
      await state.atualizarItem(
        Item(
          id: original.id,
          nome: _nome.text.trim(),
          sigla: _sigla.text.trim(),
          tipo: _tipo.text.trim(),
          cor: _cor,
          local: opcional(_local),
          notas: opcional(_notas),
          arquivado: original.arquivado,
          tabelaId: _tabelaId,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final novo = widget.original == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(novo ? 'Novo item' : 'Editar item'),
        actions: [
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
              controller: _nome,
              autofocus: novo,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome',
                hintText: 'Academia, Reunião semanal, Consulta médica...',
              ),
              validator: _naoVazio,
              onChanged: _aoDigitarNome,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sigla,
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
              decoration: const InputDecoration(labelText: 'Sigla'),
              validator: _naoVazio,
              onChanged: (_) => _siglaAutomatica = false,
            ),
            const SizedBox(height: 8),
            _CampoTipo(
              controller: _tipo,
              conhecidos: state.tiposConhecidos,
            ),
            const SizedBox(height: 16),
            _SeletorDeVinculo(
              tabelas: state.tabelas,
              selecionada: _tabelaId,
              aoEscolher: (id) => setState(() => _tabelaId = id),
            ),
            const SizedBox(height: 24),
            _SeletorDeCor(
              selecionada: _cor,
              sigla: _sigla.text.trim().isEmpty ? 'ABC' : _sigla.text.trim(),
              aoEscolher: (c) => setState(() => _cor = c),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _local,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Local',
                hintText: 'Sala 204, Academia do bairro...',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notas,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas',
                hintText: 'Com quem, o que levar, o que lembrar...',
              ),
            ),
            // Item novo ainda não tem id pra vincular evento — a seção só
            // aparece depois do primeiro salvar.
            if (!novo) ...[
              const SizedBox(height: 28),
              _EventosDoItem(item: widget.original!),
            ],
          ],
          ),
        ),
      ),
    );
  }
}

/// Campo de tipo com autocomplete dos valores já usados.
///
/// Texto livre em vez de enum fechado, como a spec decidiu — mas sugerir o que
/// já existe evita "Aula", "aula" e "Aulas" convivendo na mesma biblioteca.
class _CampoTipo extends StatelessWidget {
  const _CampoTipo({required this.controller, required this.conhecidos});

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
          decoration: const InputDecoration(
            labelText: 'Tipo',
            hintText: 'Aula, Treino, Pausa...',
          ),
        ),
        if (conhecidos.isNotEmpty) ...[
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
      ],
    );
  }
}

/// Escolhe se o item é compartilhado (aparece em qualquer tabela) ou
/// exclusivo de uma tabela específica (ver [Item.tabelaId]) — sem precisar
/// estar dentro do editor daquela tabela pra decidir isso.
class _SeletorDeVinculo extends StatelessWidget {
  const _SeletorDeVinculo({
    required this.tabelas,
    required this.selecionada,
    required this.aoEscolher,
  });

  final List<Tabela> tabelas;
  final String? selecionada;
  final ValueChanged<String?> aoEscolher;

  @override
  Widget build(BuildContext context) {
    // Sem tabela nenhuma cadastrada ainda, não tem o que oferecer além de
    // compartilhado — o próprio default.
    if (tabelas.isEmpty) return const SizedBox.shrink();

    // Defensivo: se o vínculo apontar pra uma tabela que sumiu (não deveria
    // acontecer, `removerTabela` apaga o item junto), cai em compartilhado
    // em vez de estourar o Dropdown por valor sem item correspondente.
    final valor =
        selecionada != null && tabelas.any((t) => t.id == selecionada)
            ? selecionada
            : null;

    return DropdownButtonFormField<String?>(
      initialValue: valor,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Vínculo'),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('Compartilhado (qualquer tabela)'),
        ),
        for (final tabela in tabelas)
          DropdownMenuItem(value: tabela.id, child: Text('Só em ${tabela.nome}')),
      ],
      onChanged: aoEscolher,
    );
  }
}

class _SeletorDeCor extends StatelessWidget {
  const _SeletorDeCor({
    required this.selecionada,
    required this.sigla,
    required this.aoEscolher,
  });

  final ItemColor selecionada;
  final String sigla;
  final ValueChanged<ItemColor> aoEscolher;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cor',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cor in ItemColor.values)
              GestureDetector(
                onTap: () => aoEscolher(cor),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: cor == selecionada
                          ? scheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  // A amostra usa a densidade real do app: escolher cor num
                  // quadradinho que não parece a célula da tabela é chutar.
                  child: ItemSwatch(
                    cor: cor,
                    densidade: state.densidade,
                    texto: sigla,
                    largura: 62,
                    altura: 38,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// "Eventos" na tela do item: os próximos em destaque, os passados
/// recolhidos, e o atalho pra criar um já vinculado.
class _EventosDoItem extends StatelessWidget {
  const _EventosDoItem({required this.item});

  final Item item;

  /// Até onde procurar a próxima ocorrência de um recorrente — anual precisa
  /// de pelo menos um ano de janela pra sempre achar a próxima.
  static const _janela = Duration(days: 400);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final hoje = inicioDoDia(agora);

    final proximos = <Ocorrencia>[];
    final passados = <Ocorrencia>[];
    for (final e in state.eventosDoItem(item.id)) {
      final futuras = e
          .ocorrenciasEntre(hoje, hoje.add(_janela))
          .where((o) => e.diaInteiro || !o.fim.isBefore(agora));
      if (futuras.isNotEmpty) {
        proximos.add(futuras.first);
      } else {
        passados.add(Ocorrencia(e, e.inicio, e.inicio.add(e.duracao)));
      }
    }
    proximos.sort((a, b) => a.inicio.compareTo(b.inicio));
    passados.sort((a, b) => b.inicio.compareTo(a.inicio));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Eventos',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            TextButton.icon(
              onPressed: () => abrirFolhaDeEvento(context, itemId: item.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Evento'),
            ),
          ],
        ),
        if (proximos.isEmpty && passados.isEmpty)
          Text(
            'Provas, entregas e outros momentos ligados a ${item.sigla} aparecem aqui.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        for (final o in proximos) EventoTile(ocorrencia: o, mostrarItem: false),
        if (passados.isNotEmpty)
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(
              passados.length == 1 ? '1 passado' : '${passados.length} passados',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            children: [
              for (final o in passados)
                EventoTile(ocorrencia: o, mostrarItem: false, esmaecido: true),
            ],
          ),
      ],
    );
  }
}
