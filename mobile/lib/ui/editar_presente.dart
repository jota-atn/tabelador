import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../model/presente.dart';
import '../state/app_state.dart';

/// Diálogo do presente de um aniversário: a ideia e se já foi comprado.
/// Com presente já guardado, dá pra trocar ou remover.
Future<void> abrirEditarPresente(BuildContext context, Ocorrencia ocorrencia) {
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<AppState>(),
      child: _EditarPresente(ocorrencia: ocorrencia),
    ),
  );
}

class _EditarPresente extends StatefulWidget {
  const _EditarPresente({required this.ocorrencia});

  final Ocorrencia ocorrencia;

  @override
  State<_EditarPresente> createState() => _EditarPresenteState();
}

class _EditarPresenteState extends State<_EditarPresente> {
  late final TextEditingController _ideia;
  late bool _comprado;

  Presente? get _atual => widget.ocorrencia.evento.presenteEm(widget.ocorrencia.inicio);

  @override
  void initState() {
    super.initState();
    _ideia = TextEditingController(text: _atual?.ideia ?? '');
    _comprado = _atual?.comprado ?? false;
  }

  @override
  void dispose() {
    _ideia.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final ideia = _ideia.text.trim();
    final navigator = Navigator.of(context);
    // Ideia apagada = sem presente.
    await context
        .read<AppState>()
        .definirPresente(widget.ocorrencia, ideia.isEmpty ? null : Presente(ideia, comprado: _comprado));
    navigator.pop();
  }

  Future<void> _remover() async {
    final navigator = Navigator.of(context);
    await context.read<AppState>().definirPresente(widget.ocorrencia, null);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.ocorrencia.evento.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ideia,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Presente'),
            onSubmitted: (_) => _salvar(),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _comprado,
            onChanged: (v) => setState(() => _comprado = v ?? false),
            title: const Text('Comprado'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
      actions: [
        if (_atual != null) TextButton(onPressed: _remover, child: const Text('Remover')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
