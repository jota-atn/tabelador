import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dev/exemplos.dart';
import '../model/evento.dart';
import '../state/app_state.dart';
import '../theme/tipo_evento_visual.dart';
import '../util/eventos_na_grade.dart';
import '../util/formato_data.dart';
import '../util/tarefas.dart';
import 'calendario_screen.dart';
import 'eventos_do_tipo_screen.dart';
import 'tarefas_screen.dart';
import 'widgets/evento_tile.dart';

/// Quanto à frente a aba conta "próximos" (o Google é lido até ~400 dias).
const _kJanela = Duration(days: 365);

/// Tipo de uma ocorrência pra aba: evento sem tipo conta como Outro.
TipoEvento tipoDe(Evento e) => TipoEvento.doTexto(e.tipo) ?? TipoEvento.outro;

/// A aba Eventos: card largo de Tarefas no topo (3 próximas pendentes,
/// marcáveis), um card por tipo **usado** em grade de 2 colunas (ordem fixa
/// de [TipoEvento] entre eles) e os tipos sem nada pela frente numa linha
/// de chips no fim. Tocar abre a página do tipo. Sem botão de criar: criar
/// continua pela tela Semana.
class EventosScreen extends StatelessWidget {
  const EventosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final agora = DateTime.now();
    final hoje = inicioDoDia(agora);
    final proximas = state
        .ocorrenciasEntre(hoje, hoje.add(_kJanela))
        .where((o) => !o.feita && _naoPassou(o, agora))
        .toList();

    final porTipo = <TipoEvento, List<Ocorrencia>>{};
    for (final o in proximas) {
      (porTipo[tipoDe(o.evento)] ??= []).add(o);
    }

    return Scaffold(
      appBar: AppBar(
        // Segurar o título abre o menu escondido de dados de exemplo.
        title: GestureDetector(
          onLongPress: () => _menuDeExemplos(context),
          child: const Text('Eventos'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Calendário do mês',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CalendarioScreen()),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final colunas = c.maxWidth >= 720 ? 4 : 2;
          final tipos = [for (final t in TipoEvento.values) if (t != TipoEvento.tarefa) t];
          final usados = [for (final t in tipos) if (porTipo[t]?.isNotEmpty ?? false) t];
          final vazios = [for (final t in tipos) if (!usados.contains(t)) t];
          final scheme = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const _CardTarefas(),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: colunas,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  for (final t in usados) _CardTipo(tipo: t, proximas: porTipo[t]!, agora: agora),
                ],
              ),
              if (usados.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Text(
                    'Pra criar um evento, segure um horário na Semana.',
                    style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
                  ),
                ),
              if (vazios.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                  child: Text(
                    'Sem eventos',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final t in vazios) _ChipTipo(tipo: t)],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _menuDeExemplos(BuildContext context) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final qtd = state.eventos.where(ehExemplo).length;
    final escolha = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Dados de exemplo', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Eventos de mentira pra ver as telas cheias. '
                  'Remover apaga só eles, nunca os seus.'),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(qtd == 0 ? 'Adicionar exemplos' : 'Recriar exemplos (datas de hoje)'),
              onTap: () => Navigator.of(ctx).pop('add'),
            ),
            if (qtd > 0)
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: Text('Remover os $qtd exemplos'),
                onTap: () => Navigator.of(ctx).pop('del'),
              ),
          ],
        ),
      ),
    );
    if (escolha == 'add') {
      await state.removerEventosOnde(ehExemplo);
      final novos = eventosDeExemplo(
        DateTime.now(),
        itens: [for (final i in state.itens) if (!i.arquivado) i],
      );
      await state.adicionarEventos(novos);
      messenger.showSnackBar(SnackBar(content: Text('${novos.length} eventos de exemplo adicionados.')));
    } else if (escolha == 'del') {
      final n = await state.removerEventosOnde(ehExemplo);
      messenger.showSnackBar(SnackBar(content: Text('$n eventos de exemplo removidos.')));
    }
  }

  static bool _naoPassou(Ocorrencia o, DateTime agora) =>
      o.evento.diaInteiro ||
      (o.fim.isAfter(o.inicio) ? o.fim.isAfter(agora) : !o.inicio.isBefore(agora));
}

/// Fundo do card: o tom do tipo bem diluído sobre a superfície.
Color _fundo(Color cor, ColorScheme scheme) => Color.alphaBlend(
      cor.withValues(alpha: scheme.brightness == Brightness.dark ? 0.20 : 0.12),
      scheme.surfaceContainerLow,
    );

class _Icone extends StatelessWidget {
  const _Icone({required this.tipo, required this.cor, this.tamanho = 40});

  final TipoEvento tipo;
  final Color cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final sobre = ThemeData.estimateBrightnessForColor(cor) == Brightness.dark ? Colors.white : Colors.black;
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(tamanho * 0.3)),
      child: Icon(iconeDoTipo(tipo), color: sobre, size: tamanho * 0.55),
    );
  }
}

class _CardTarefas extends StatelessWidget {
  const _CardTarefas();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final cor = corDoTipo(TipoEvento.tarefa, scheme.brightness);
    final agora = DateTime.now();
    final pendentes = [
      for (final l in organizarTarefas(state.tarefas, agora))
        if (l.secao != SecaoTarefa.concluidas) l,
    ];
    final atrasadas = pendentes.where((l) => l.secao == SecaoTarefa.atrasadas).length;

    void abrir() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TarefasScreen()),
        );

    return Card.filled(
      margin: EdgeInsets.zero,
      color: _fundo(cor, scheme),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: abrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Icone(tipo: TipoEvento.tarefa, cor: cor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tarefas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(
                          [
                            pendentes.isEmpty
                                ? 'Nada pendente'
                                : pendentes.length == 1
                                    ? '1 pendente'
                                    : '${pendentes.length} pendentes',
                            if (atrasadas > 0) atrasadas == 1 ? '1 atrasada' : '$atrasadas atrasadas',
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 13,
                            color: atrasadas > 0 ? scheme.error : scheme.onSurfaceVariant,
                            fontWeight: atrasadas > 0 ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 4),
              for (final l in pendentes.take(3)) EventoTile(ocorrencia: l.ocorrencia),
              if (pendentes.length > 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: abrir,
                    child: Text('Ver todas (${pendentes.length})'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTipo extends StatelessWidget {
  const _CardTipo({required this.tipo, required this.proximas, required this.agora});

  final TipoEvento tipo;
  final List<Ocorrencia> proximas;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cor = corDoTipo(tipo, scheme.brightness);
    var (destaque, linha) = switch (tipo) {
      TipoEvento.feriado => _feriados(context),
      TipoEvento.aniversario => _aniversarios(context),
      _ => _padrao(),
    };
    // Aniversário sem nada este mês, mas com algum mais adiante.
    if (destaque == null && linha == null) (destaque, linha) = _padrao();

    return Card.filled(
      margin: EdgeInsets.zero,
      color: _fundo(cor, scheme),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => EventosDoTipoScreen(tipo: tipo)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Icone(tipo: tipo, cor: cor, tamanho: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pluralDoTipo(tipo),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (linha != null)
                Text(
                  linha,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface),
                ),
              if (destaque != null)
                Text(
                  destaque,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// "3 próximas" + "qui 13/11 · Prova de SO".
  (String?, String?) _padrao() {
    if (proximas.isEmpty) return (null, null);
    final n = proximas.length;
    final femininos = {TipoEvento.prova, TipoEvento.consulta, TipoEvento.reuniao, TipoEvento.viagem};
    final palavra = femininos.contains(tipo)
        ? (n == 1 ? 'próxima' : 'próximas')
        : (n == 1 ? 'próximo' : 'próximos');
    final p = proximas.first;
    // Vários dias já começado: "Viagem a BH · Em viagem · volta sex 20/11".
    if (p.variosDias && p.acontecendo(agora)) {
      return ('$n $palavra', '${p.evento.titulo} · ${faixaDeDias(p, agora)}');
    }
    return ('$n $palavra', '${rotuloDoDia(p.inicio, agora)} · ${p.evento.titulo}');
  }

  /// Hoje é feriado? Senão o próximo; e quantos (folga) até o fim do ano.
  (String?, String?) _feriados(BuildContext context) {
    if (proximas.isEmpty) return (null, null);
    final hoje = inicioDoDia(agora);
    final fimDoAno = DateTime(agora.year + 1);
    final folgas = proximas.where((o) => ehFolga(o.evento, context.read<AppState>().tabelaAtiva) && o.inicio.isBefore(fimDoAno)).length;
    final deHoje = proximas.where((o) => o.cobre(hoje)).toList();
    final contagem = folgas == 0
        ? 'Nenhum até o fim do ano'
        : folgas == 1
            ? '1 até o fim do ano'
            : '$folgas até o fim do ano';
    if (deHoje.isNotEmpty) return (contagem, 'Hoje: ${deHoje.first.evento.titulo}');
    final p = proximas.first;
    return (contagem, '${rotuloDoDia(p.inicio, agora)} · ${p.evento.titulo}');
  }

  /// Os do mês atual (os que já passaram também contam); nos últimos dias
  /// do mês, adianta o primeiro do mês seguinte.
  (String?, String?) _aniversarios(BuildContext context) {
    final state = context.read<AppState>();
    final mes = DateTime(agora.year, agora.month);
    final proximoMes = DateTime(agora.year, agora.month + 1);
    final doMes = state
        .ocorrenciasEntre(mes, proximoMes)
        .where((o) => tipoDe(o.evento) == TipoEvento.aniversario)
        .toList();
    final hoje = inicioDoDia(agora);
    final restantes = doMes.where((o) => !inicioDoDia(o.inicio).isBefore(hoje)).toList();
    final contagem = doMes.isEmpty
        ? null
        : doMes.length == 1
            ? '1 este mês'
            : '${doMes.length} este mês';
    if (restantes.isNotEmpty) {
      final p = restantes.first;
      return (contagem, '${rotuloDoDia(p.inicio, agora)} · ${p.evento.titulo}');
    }
    final fimDoMes = proximoMes.difference(hoje).inDays <= 7;
    final seguinte = proximas.where((o) => !o.inicio.isBefore(proximoMes)).firstOrNull;
    if (fimDoMes && seguinte != null) {
      return (contagem ?? 'Nenhum este mês', '${rotuloDoDia(seguinte.inicio, agora)} · ${seguinte.evento.titulo}');
    }
    return (contagem, null);
  }
}

/// Tipo sem nada pela frente: chip pequeno no fim da aba; tocar abre a
/// página dele (onde dá pra ver o passado ou criar).
class _ChipTipo extends StatelessWidget {
  const _ChipTipo({required this.tipo});

  final TipoEvento tipo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(iconeDoTipo(tipo), size: 18, color: corDoTipo(tipo, scheme.brightness)),
      label: Text(pluralDoTipo(tipo)),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EventosDoTipoScreen(tipo: tipo)),
      ),
    );
  }
}
