import 'package:flutter/material.dart';

import '../../model/item.dart';

/// Rótulo pequeno de cada linha da folha de evento ("Tipo", "Item"...).
class RotuloLinha extends StatelessWidget {
  const RotuloLinha(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Seção da folha de evento num cartão: ícone colorido, título forte e,
/// à direita, o valor escolhido ("Prova", "qui 12/11 · 10:00–12:00") —
/// dá pra conferir o evento lendo só os cabeçalhos.
class SecaoDaFolha extends StatelessWidget {
  const SecaoDaFolha({
    super.key,
    required this.icone,
    required this.titulo,
    required this.filhos,
    this.resumo,
  });

  final IconData icone;
  final String titulo;
  final String? resumo;
  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, size: 17, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 10),
              Text(
                titulo,
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: scheme.onSurface),
              ),
              const SizedBox(width: 12),
              if (resumo != null)
                Expanded(
                  child: Text(
                    resumo!,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...filhos,
        ],
      ),
    );
  }
}

/// "Outro item…": todos os itens não arquivados, com busca. Devolve o id.
Future<String?> escolherOutroItem(BuildContext context, List<Item> itens) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BuscaDeItem(itens: itens),
  );
}

class _BuscaDeItem extends StatefulWidget {
  const _BuscaDeItem({required this.itens});

  final List<Item> itens;

  @override
  State<_BuscaDeItem> createState() => _BuscaDeItemState();
}

class _BuscaDeItemState extends State<_BuscaDeItem> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final b = _busca.trim().toLowerCase();
    final filtrados = [
      for (final i in widget.itens)
        if (b.isEmpty || i.nome.toLowerCase().contains(b) || i.sigla.toLowerCase().contains(b)) i,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar item',
                ),
                onChanged: (v) => setState(() => _busca = v),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final i in filtrados)
                    ListTile(
                      title: Text(i.nome),
                      subtitle: Text(i.sigla),
                      onTap: () => Navigator.of(context).pop(i.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
