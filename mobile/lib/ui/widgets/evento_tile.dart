import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/evento.dart';
import '../../state/app_state.dart';
import '../../util/formato_data.dart';
import '../evento_editor.dart';
import 'item_swatch.dart';

/// Uma ocorrência de evento numa lista: bloco de data à esquerda, título e
/// "horário · tipo · item" embaixo. Usado em "Próximos" e na seção de
/// eventos do item. Tocar abre o editor.
class EventoTile extends StatelessWidget {
  const EventoTile({
    super.key,
    required this.ocorrencia,
    this.mostrarItem = true,
    this.esmaecido = false,
  });

  final Ocorrencia ocorrencia;

  /// Na tela do próprio item, repetir o nome dele em cada linha é ruído.
  final bool mostrarItem;

  /// Eventos passados aparecem apagados, pra não competir com os próximos.
  final bool esmaecido;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final evento = ocorrencia.evento;
    final item = state.itemPorId(evento.itemId);
    final agora = DateTime.now();

    final detalhes = [
      faixaHorario(ocorrencia),
      if (evento.tipo.isNotEmpty) evento.tipo,
      if (mostrarItem && item != null) item.sigla,
      if (evento.repeticao != Repeticao.nenhuma) evento.repeticao.rotulo.toLowerCase(),
      if (evento.gravadoNoGoogle) 'Google',
    ].join(' · ');

    final corTexto = esmaecido ? scheme.onSurfaceVariant : scheme.onSurface;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: SizedBox(
        width: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              diaAbreviado(ocorrencia.inicio),
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
            ),
            Text(
              '${ocorrencia.inicio.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: corTexto,
              ),
            ),
          ],
        ),
      ),
      title: Text(
        evento.titulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: corTexto),
      ),
      subtitle: Text(
        '${rotuloDoDia(ocorrencia.inicio, agora)} · $detalhes',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // A cor do item vinculado, na densidade do app — o mesmo sinal visual
      // que liga o evento à disciplina na grade.
      trailing: item == null
          ? (evento.externo
              ? CircleAvatar(
                  radius: 5,
                  backgroundColor: evento.corExterna == null
                      ? scheme.outline
                      : Color(evento.corExterna!),
                )
              : null)
          : ItemSwatch(
              cor: item.cor,
              densidade: state.densidade,
              largura: 8,
              altura: 32,
              raio: 4,
            ),
      // Evento do Google é só leitura por enquanto: detalhes numa folha em
      // vez do formulário.
      onTap: evento.externo
          ? () => _detalhesExterno(context, ocorrencia, state)
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => EventoEditor(original: evento)),
              ),
    );
  }
}

void _detalhesExterno(BuildContext context, Ocorrencia o, AppState state) {
  final e = o.evento;
  final scheme = Theme.of(context).colorScheme;
  final agenda = state.agendas[e.agendaId]?.nome;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        children: [
          Text(e.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            '${rotuloDoDia(o.inicio, DateTime.now())} · ${dataCompleta(o.inicio)} · ${faixaHorario(o)}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (e.local != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(e.local!)),
              ],
            ),
          ],
          if (e.notas != null) ...[
            const SizedBox(height: 12),
            Text(e.notas!, maxLines: 12, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 5,
                backgroundColor:
                    e.corExterna == null ? scheme.outline : Color(e.corExterna!),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Do Google Agenda${agenda == null ? '' : ' · $agenda'} — editar por lá, por enquanto',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
