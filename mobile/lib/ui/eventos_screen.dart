import 'package:flutter/foundation.dart';
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

/// Medidas do orçamento de altura da aba (dp).
const double _kEspaco = 12;
const double _kCardMin = 92;
const double _kChipAltura = 40;
const double _kRotuloChips = 40;
const double _kTarefasBase = 72;
const double _kTarefaLinha = 76;

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
        // Segurar o título abre o menu escondido de dados de exemplo — só
        // no build de desenvolvimento; a versão instalada não tem.
        title: GestureDetector(
          onLongPress: kDebugMode ? () => _menuDeExemplos(context) : null,
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
          final escondidos = state.tiposEscondidos;
          final tipos = [
            for (final t in TipoEvento.values)
              if (t != TipoEvento.tarefa && !escondidos.contains(t)) t,
          ];
          final usados = [for (final t in tipos) if (porTipo[t]?.isNotEmpty ?? false) t];
          final vazios = [for (final t in tipos) if (!usados.contains(t)) t];
          final scheme = Theme.of(context).colorScheme;

          // Orçamento de altura: chips e grade com altura mínima; o card de
          // Tarefas mostra quantas tarefas couberem (até 3) e o que sobra
          // estica os cards. Só rola se nem assim couber (tela minúscula).
          final linhasGrade = (usados.length / colunas).ceil();
          final gradeMin = linhasGrade == 0 ? 0.0 : linhasGrade * _kCardMin + (linhasGrade - 1) * _kEspaco;
          final linhasChips = (vazios.length / colunas).ceil();
          final chipsAltura = vazios.isEmpty
              ? 0.0
              : _kRotuloChips + linhasChips * _kChipAltura + (linhasChips - 1) * 8;
          final livre = c.maxHeight - 8 - 16 - _kEspaco - gradeMin - chipsAltura - _kTarefasBase;
          final cabe = livre >= 0;
          final nTarefas = cabe ? (livre / _kTarefaLinha).floor().clamp(0, 3) : 3;

          final chips = [
            if (vazios.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                child: Text(
                  'Sem eventos',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                ),
              ),
              _ChipsAlinhados(tipos: vazios, colunas: colunas),
            ],
          ];
          final dica = Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              'Pra criar um evento, segure um horário na Semana.',
              style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
            ),
          );
          Widget grade(double proporcao) => GridView.count(
                crossAxisCount: colunas,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                mainAxisSpacing: _kEspaco,
                crossAxisSpacing: _kEspaco,
                childAspectRatio: proporcao,
                children: [
                  for (final t in usados) _CardTipo(tipo: t, proximas: porTipo[t]!, agora: agora),
                ],
              );

          if (!cabe) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _CardTarefas(maxTarefas: nTarefas),
                const SizedBox(height: _kEspaco),
                grade(1.5),
                if (usados.isEmpty) dica,
                ...chips,
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardTarefas(maxTarefas: nTarefas),
                const SizedBox(height: _kEspaco),
                Expanded(
                  child: usados.isEmpty
                      ? Align(alignment: Alignment.topLeft, child: dica)
                      : LayoutBuilder(
                          builder: (context, g) {
                            final largura = (g.maxWidth - (colunas - 1) * _kEspaco) / colunas;
                            // Cards esticam até ~1,5 de proporção; acima disso
                            // sobra espaço embaixo em vez de card gigante.
                            final altura = ((g.maxHeight - (linhasGrade - 1) * _kEspaco) / linhasGrade)
                                .clamp(_kCardMin, largura / 1.1);
                            return Align(alignment: Alignment.topCenter, child: grade(largura / altura));
                          },
                        ),
                ),
                ...chips,
              ],
            ),
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
  const _CardTarefas({required this.maxTarefas});

  /// Quantas tarefas cabem na tela sem rolar (0 a 3).
  final int maxTarefas;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final cor = corDoTipo(TipoEvento.tarefa, scheme.brightness);
    final agora = DateTime.now();
    final pendentes = [
      for (final l in organizarTarefas(state.tarefas, agora, state.primeiroDiaDaSemana))
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
              // O total já está no cabeçalho, que abre a página de Tarefas.
              for (final l in pendentes.take(maxTarefas)) EventoTile(ocorrencia: l.ocorrencia),
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

/// Os tipos sem nada pela frente em colunas iguais às dos cards: cada
/// linha ocupa a largura toda, alinhada com a grade acima.
class _ChipsAlinhados extends StatelessWidget {
  const _ChipsAlinhados({required this.tipos, required this.colunas});

  final List<TipoEvento> tipos;
  final int colunas;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tipos.length; i += colunas) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var j = i; j < i + colunas; j++) ...[
                if (j > i) const SizedBox(width: _kEspaco),
                Expanded(child: j < tipos.length ? _ChipTipo(tipo: tipos[j]) : const SizedBox()),
              ],
            ],
          ),
        ],
      ],
    );
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
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => EventosDoTipoScreen(tipo: tipo)),
        ),
        child: SizedBox(
          height: _kChipAltura,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(iconeDoTipo(tipo), size: 18, color: corDoTipo(tipo, scheme.brightness)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pluralDoTipo(tipo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
