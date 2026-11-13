import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../model/nota.dart';
import '../state/app_state.dart';

/// Diálogo "7,5 de 10": nota e máximo (que vem com o último usado). Com
/// nota já lançada, dá pra trocar ou remover.
Future<void> abrirLancarNota(BuildContext context, Ocorrencia ocorrencia) {
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<AppState>(),
      child: _LancarNota(ocorrencia: ocorrencia),
    ),
  );
}

class _LancarNota extends StatefulWidget {
  const _LancarNota({required this.ocorrencia});

  final Ocorrencia ocorrencia;

  @override
  State<_LancarNota> createState() => _LancarNotaState();
}

class _LancarNotaState extends State<_LancarNota> {
  late final TextEditingController _valor;
  late final TextEditingController _maximo;
  String? _erro;

  Nota? get _atual => widget.ocorrencia.evento.notaEm(widget.ocorrencia.inicio);

  @override
  void initState() {
    super.initState();
    final atual = _atual;
    _valor = TextEditingController(text: atual == null ? '' : formatarNumero(atual.valor));
    _maximo = TextEditingController(
      text: formatarNumero(atual?.maximo ?? context.read<AppState>().ultimoMaximo),
    );
  }

  @override
  void dispose() {
    _valor.dispose();
    _maximo.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final valor = lerNumero(_valor.text);
    final maximo = lerNumero(_maximo.text);
    if (valor == null || maximo == null) {
      setState(() => _erro = 'Digite a nota e o máximo.');
      return;
    }
    if (maximo <= 0 || valor < 0 || valor > maximo) {
      setState(() => _erro = 'A nota vai de 0 até ${formatarNumero(maximo > 0 ? maximo : 10)}.');
      return;
    }
    final navigator = Navigator.of(context);
    await context.read<AppState>().lancarNota(widget.ocorrencia, Nota(valor, maximo));
    navigator.pop();
  }

  Future<void> _remover() async {
    final navigator = Navigator.of(context);
    await context.read<AppState>().lancarNota(widget.ocorrencia, null);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final teclado = const TextInputType.numberWithOptions(decimal: true);
    final soNumero = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    return AlertDialog(
      title: Text(widget.ocorrencia.evento.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _valor,
                  autofocus: true,
                  keyboardType: teclado,
                  inputFormatters: soNumero,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(labelText: 'Nota'),
                  onSubmitted: (_) => _salvar(),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text('de', style: TextStyle(fontSize: 16)),
              ),
              Expanded(
                child: TextField(
                  controller: _maximo,
                  keyboardType: teclado,
                  inputFormatters: soNumero,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22),
                  decoration: const InputDecoration(labelText: 'Máximo'),
                  onSubmitted: (_) => _salvar(),
                ),
              ),
            ],
          ),
          if (_erro != null) ...[
            const SizedBox(height: 10),
            Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
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
