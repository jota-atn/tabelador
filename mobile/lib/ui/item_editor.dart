import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/item.dart';
import '../state/app_state.dart';
import '../theme/item_palette.dart';
import 'widgets/item_swatch.dart';

/// Cadastro e edição de um Item.
///
/// [original] nulo significa item novo.
class ItemEditor extends StatefulWidget {
  const ItemEditor({super.key, this.original});

  final Item? original;

  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nome;
  late final TextEditingController _sigla;
  late final TextEditingController _tipo;
  late final TextEditingController _local;
  late final TextEditingController _professor;
  late final TextEditingController _notas;

  late ItemColor _cor;

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
    _professor = TextEditingController(text: o?.professor ?? '');
    _notas = TextEditingController(text: o?.notas ?? '');
    _cor = o?.cor ?? ItemColor.oceano;
    _siglaAutomatica = o == null;
  }

  @override
  void dispose() {
    for (final c in [_nome, _sigla, _tipo, _local, _professor, _notas]) {
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
          professor: opcional(_professor),
          notas: opcional(_notas),
        ),
      );
    } else {
      await state.atualizarItem(
        Item(
          id: original.id,
          nome: _nome.text.trim(),
          sigla: _sigla.text.trim(),
          tipo: _tipo.text.trim(),
          cor: _cor,
          local: opcional(_local),
          professor: opcional(_professor),
          notas: opcional(_notas),
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            TextFormField(
              controller: _nome,
              autofocus: novo,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome',
                hintText: 'Cálculo Diferencial e Integral II',
              ),
              validator: _naoVazio,
              onChanged: _aoDigitarNome,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sigla,
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'Sigla',
                helperText: 'É ela que aparece na grade e no widget',
              ),
              validator: _naoVazio,
              onChanged: (_) => _siglaAutomatica = false,
            ),
            const SizedBox(height: 8),
            _CampoTipo(
              controller: _tipo,
              conhecidos: state.tiposConhecidos,
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
                hintText: 'Bloco C, sala 204',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _professor,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Professor'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notas,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
          ],
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
            hintText: 'Aula, Monitoria, Pausa...',
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
