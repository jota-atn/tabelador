import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/evento.dart';
import '../../state/app_state.dart';
import '../../util/formato_data.dart';
import '../../util/link_reuniao.dart';
import '../../theme/tipo_evento_visual.dart';
import '../detalhes_evento.dart';
import '../tarefas_acoes.dart';
import 'item_swatch.dart';

/// Uma ocorrência de evento numa lista: bloco de data à esquerda, título e
/// "horário · tipo · item" embaixo. Usado em "Próximos" e na seção de
/// eventos do item. Tocar abre o card de detalhes.
///
/// Tarefa do app troca o bloco da esquerda por uma caixinha (tocar conclui,
/// com Desfazer); a data vai pro texto de baixo. Atrasada fica em vermelho.
class EventoTile extends StatelessWidget {
  const EventoTile({
    super.key,
    required this.ocorrencia,
    this.mostrarItem = true,
    this.esmaecido = false,
    this.mostrarData = true,
    this.aoMarcar,
    this.aoTocar,
    this.aoSegurar,
    this.selecionado = false,
  });

  /// A página de Tarefas cuida do concluir (risca antes de descer); sem
  /// isto, a caixinha conclui com Desfazer direto.
  final ValueChanged<bool>? aoMarcar;

  /// Troca o "tocar abre o card" (modo de seleção da página de Tarefas).
  final VoidCallback? aoTocar;
  final VoidCallback? aoSegurar;
  final bool selecionado;

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
    final tarefa = evento.ehTarefa;
    final feita = tarefa && ocorrencia.feita;
    final atrasada = tarefa &&
        !feita &&
        !evento.semData &&
        (evento.diaInteiro
            ? inicioDoDia(ocorrencia.inicio).isBefore(inicioDoDia(agora))
            : ocorrencia.inicio.isBefore(agora));
    final tipo = TipoEvento.doTexto(evento.tipo);
    final link = linkDeReuniao(evento);

    final detalhes = [
      if (tarefa && evento.semData)
        'Sem data'
      else if (tarefa && mostrarData)
        rotuloDoDia(ocorrencia.inicio, agora),
      if (!(tarefa && (evento.diaInteiro || evento.semData))) faixaHorario(ocorrencia),
      if (evento.tipo.isNotEmpty && !tarefa) evento.tipo,
      if (mostrarItem && item != null) item.sigla,
      if (evento.repeticao != Repeticao.nenhuma) evento.repeticao.rotulo.toLowerCase(),
      if (evento.gravadoNoGoogle) 'Google',
    ].join(' · ');

    final corTexto = esmaecido || feita ? scheme.onSurfaceVariant : scheme.onSurface;

    return ListTile(
      selected: selecionado,
      selectedTileColor: scheme.secondaryContainer,
      onLongPress: aoSegurar,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: tarefa
          ? SizedBox(
              width: 48,
              child: Center(
                child: Checkbox(
                  value: feita,
                  activeColor: corDoTipo(TipoEvento.tarefa, scheme.brightness),
                  shape: const CircleBorder(),
                  onChanged: (v) => aoMarcar != null
                      ? aoMarcar!(v ?? false)
                      : marcarTarefa(context, ocorrencia, v ?? false),
                ),
              ),
            )
          : !mostrarData
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
        style: TextStyle(
          color: corTexto,
          decoration: feita ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: detalhes.isEmpty
          ? null
          : Text(
              mostrarData && !tarefa ? '${rotuloDoDia(ocorrencia.inicio, agora)} · $detalhes' : detalhes,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: atrasada ? TextStyle(color: scheme.error, fontWeight: FontWeight.w600) : null,
            ),
      // A cor do item vinculado, na densidade do app — o mesmo sinal visual
      // que liga o evento à disciplina na grade.
      // Reunião começando (10 min antes até o fim): o atalho de entrar
      // toma o lugar do marcador.
      trailing: link != null && horaDeEntrar(ocorrencia, agora)
          ? IconButton.filledTonal(
              onPressed: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                if (!await abrirLink(link)) {
                  messenger?.showSnackBar(const SnackBar(content: Text('Não deu pra abrir o link.')));
                }
              },
              icon: const Icon(Icons.videocam_outlined),
              tooltip: 'Entrar',
            )
          : item == null
          ? (evento.externo && evento.corExterna != null
              ? CircleAvatar(
                  radius: 5,
                  backgroundColor: Color(evento.corExterna!),
                )
              : tipo == null || tarefa
                  ? null
                  : Icon(iconeDoTipo(tipo), size: 20, color: corDoTipo(tipo, scheme.brightness)))
          : ItemSwatch(
              cor: item.cor,
              densidade: state.densidade,
              largura: 8,
              altura: 32,
              raio: 4,
            ),
      // Tocar mostra o card; editar é o lápis dentro dele.
      onTap: aoTocar ?? () => abrirDetalhesDoEvento(context, ocorrencia),
    );
  }
}

