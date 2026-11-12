import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/evento.dart';
import '../../state/app_state.dart';
import '../../util/formato_data.dart';
import '../detalhes_evento.dart';
import 'item_swatch.dart';

/// Uma ocorrência de evento numa lista: bloco de data à esquerda, título e
/// "horário · tipo · item" embaixo. Usado em "Próximos" e na seção de
/// eventos do item. Tocar abre o card de detalhes.
class EventoTile extends StatelessWidget {
  const EventoTile({
    super.key,
    required this.ocorrencia,
    this.mostrarItem = true,
    this.esmaecido = false,
    this.mostrarData = true,
  });

  final Ocorrencia ocorrencia;

  /// Na tela do próprio item, repetir o nome dele em cada linha é ruído.
  final bool mostrarItem;

  /// Eventos passados aparecem apagados, pra não competir com os próximos.
  final bool esmaecido;

  /// Dentro de um grupo por dia ("Esta semana"), a data já está no
  /// cabeçalho do grupo: o bloco da esquerda mostra a hora no lugar.
  final bool mostrarData;

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
      leading: !mostrarData
          ? SizedBox(
              width: 48,
              child: Center(
                child: Text(
                  evento.diaInteiro ? 'dia todo' : hora(ocorrencia.inicio),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: evento.diaInteiro ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: corTexto,
                  ),
                ),
              ),
            )
          : SizedBox(
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
        mostrarData ? '${rotuloDoDia(ocorrencia.inicio, agora)} · $detalhes' : detalhes,
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
      // Tocar mostra o card; editar é o lápis dentro dele.
      onTap: () => abrirDetalhesDoEvento(context, ocorrencia),
    );
  }
}

