import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../model/item.dart';
import '../state/app_state.dart';
import '../theme/tipo_evento_visual.dart';
import '../util/eventos_do_tipo.dart';
import '../util/eventos_na_grade.dart';
import '../util/formato_data.dart';
import 'detalhes_evento.dart';
import 'widgets/item_swatch.dart';

/// Tipo de uma ocorrência: evento sem tipo conta como Outro.
TipoEvento _tipoDe(Evento e) => TipoEvento.doTexto(e.tipo) ?? TipoEvento.outro;

/// Tipos em que "quanto falta" é o que importa — a contagem aparece em cada
/// linha, não só no destaque.
const _kContaDias = {TipoEvento.prova, TipoEvento.viagem, TipoEvento.aniversario};

/// A página de um tipo: o próximo em destaque com contagem regressiva, um
/// calendário do mês com bolinhas na cor do tipo (tocar num dia mostra o
/// dia), as séries que se repetem numa linha cada, e a linha do tempo.
class EventosDoTipoScreen extends StatefulWidget {
  const EventosDoTipoScreen({super.key, required this.tipo});

  final TipoEvento tipo;

  @override
  State<EventosDoTipoScreen> createState() => _EventosDoTipoScreenState();
}

class _EventosDoTipoScreenState extends State<EventosDoTipoScreen> {
  late DateTime _mes;
  DateTime? _diaEscolhido;
  bool _passados = false;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mes = DateTime(agora.year, agora.month);
  }

  List<Ocorrencia> _doTipo(AppState state, DateTime de, DateTime ate) => [
        for (final o in state.ocorrenciasEntre(de, ate))
          if (_tipoDe(o.evento) == widget.tipo) o,
      ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final cor = corDoTipo(widget.tipo, scheme.brightness);
    final agora = DateTime.now();
    final hoje = inicioDoDia(agora);

    final pagina = organizarPaginaDoTipo(
      _doTipo(state, hoje.subtract(const Duration(days: 30)), hoje.add(const Duration(days: 365))),
      agora,
    );
    final doMes = _doTipo(state, _mes, DateTime(_mes.year, _mes.month + 1));
    final diasComEvento = {for (final o in doMes) o.inicio.day};
    final doDia = _diaEscolhido == null
        ? const <Ocorrencia>[]
        : [for (final o in doMes) if (inicioDoDia(o.inicio) == _diaEscolhido) o];

    final vazio = pagina.total == 0 && pagina.passadas.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(iconeDoTipo(widget.tipo), color: cor),
            const SizedBox(width: 12),
            Text(pluralDoTipo(widget.tipo)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              _resumo(pagina, state, agora),
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          if (pagina.proxima != null)
            _Destaque(ocorrencia: pagina.proxima!, tipo: widget.tipo, cor: cor)
          else if (vazio)
            _Vazio(tipo: widget.tipo),
          const SizedBox(height: 16),
          _MiniCalendario(
            mes: _mes,
            cor: cor,
            diasComEvento: diasComEvento,
            escolhido: _diaEscolhido,
            aoMudarMes: (m) => setState(() {
              _mes = m;
              _diaEscolhido = null;
            }),
            aoEscolher: (d) => setState(() => _diaEscolhido = _diaEscolhido == d ? null : d),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _diaEscolhido == null
                ? const SizedBox(width: double.infinity)
                : _PainelDoDia(
                    dia: _diaEscolhido!,
                    ocorrencias: doDia,
                    tipo: widget.tipo,
                    cor: cor,
                    aoFechar: () => setState(() => _diaEscolhido = null),
                  ),
          ),
          if (pagina.series.isNotEmpty) ...[
            const _Rotulo('Se repetem'),
            for (final s in pagina.series) _LinhaSerie(serie: s, cor: cor),
          ],
          for (final g in pagina.grupos) ...[
            _Rotulo('${g.rotulo} · ${g.ocorrencias.length}'),
            for (var i = 0; i < g.ocorrencias.length; i++)
              _LinhaDoTempo(
                ocorrencia: g.ocorrencias[i],
                tipo: widget.tipo,
                cor: cor,
                ultima: i == g.ocorrencias.length - 1,
              ),
          ],
          if (pagina.passadas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _passados = !_passados),
                icon: Icon(_passados ? Icons.expand_less : Icons.history),
                label: Text(_passados ? 'Esconder os passados' : 'Últimos 30 dias (${pagina.passadas.length})'),
              ),
            ),
            if (_passados)
              for (var i = 0; i < pagina.passadas.length; i++)
                Opacity(
                  opacity: 0.6,
                  child: _LinhaDoTempo(
                    ocorrencia: pagina.passadas[i],
                    tipo: widget.tipo,
                    cor: scheme.outline,
                    ultima: i == pagina.passadas.length - 1,
                  ),
                ),
          ],
        ],
      ),
    );
  }

  /// A linha de cima: quantos, e o dado que importa pro tipo.
  String _resumo(PaginaDoTipo p, AppState state, DateTime agora) {
    if (p.total == 0) return 'Nada pela frente.';
    final partes = <String>[
      p.total == 1 ? '1 nos próximos 12 meses' : '${p.total} nos próximos 12 meses',
      if (p.series.isNotEmpty) p.series.length == 1 ? '1 se repete' : '${p.series.length} se repetem',
    ];
    if (widget.tipo == TipoEvento.feriado) {
      final hoje = inicioDoDia(agora);
      final folgas = _doTipo(state, hoje, DateTime(agora.year + 1)).where((o) => ehFolga(o.evento, state.tabelaAtiva)).length;
      return folgas == 1 ? '1 de folga até o fim do ano' : '$folgas de folga até o fim do ano';
    }
    if (widget.tipo == TipoEvento.aniversario) {
      final mes = DateTime(agora.year, agora.month);
      final n = _doTipo(state, mes, DateTime(agora.year, agora.month + 1)).length;
      return n == 1 ? '1 este mês' : '$n este mês';
    }
    return partes.join(' · ');
  }
}

// --------------------------------------------------------------- destaque

class _Destaque extends StatelessWidget {
  const _Destaque({required this.ocorrencia, required this.tipo, required this.cor});

  final Ocorrencia ocorrencia;
  final TipoEvento tipo;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final escuro = scheme.brightness == Brightness.dark;
    final agora = DateTime.now();
    final e = ocorrencia.evento;
    final item = state.itemPorId(e.itemId);
    final local = e.local ?? item?.local;
    final sobre = ThemeData.estimateBrightnessForColor(cor) == Brightness.dark ? Colors.white : Colors.black;

    final dias = inicioDoDia(ocorrencia.inicio).difference(inicioDoDia(agora)).inDays;
    final (numero, legenda) = switch (dias) {
      <= 0 => ('HOJE', e.diaInteiro ? '' : hora(ocorrencia.inicio)),
      1 => ('1', 'dia'),
      < 100 => ('$dias', 'dias'),
      _ => ('${(dias / 30).round()}', 'meses'),
    };

    final rotulo = switch (tipo) {
      TipoEvento.prova => 'PRÓXIMA PROVA',
      TipoEvento.consulta => 'PRÓXIMA CONSULTA',
      TipoEvento.reuniao => 'PRÓXIMA REUNIÃO',
      TipoEvento.viagem => 'PRÓXIMA VIAGEM',
      TipoEvento.aniversario => 'PRÓXIMO ANIVERSÁRIO',
      TipoEvento.feriado => 'PRÓXIMO FERIADO',
      TipoEvento.compromisso => 'PRÓXIMO COMPROMISSO',
      _ => 'PRÓXIMO',
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => abrirDetalhesDoEvento(context, ocorrencia),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(cor.withValues(alpha: escuro ? 0.34 : 0.22), scheme.surfaceContainerLow),
                  Color.alphaBlend(cor.withValues(alpha: escuro ? 0.12 : 0.07), scheme.surfaceContainerLow),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contagem regressiva: o número grande é o que o olho pega.
                  Container(
                    width: 76,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        Text(
                          numero,
                          style: TextStyle(
                            fontSize: numero.length > 3 ? 20 : 30,
                            fontWeight: FontWeight.w800,
                            color: sobre,
                            height: 1.1,
                          ),
                        ),
                        if (legenda.isNotEmpty)
                          Text(legenda, style: TextStyle(fontSize: 12, color: sobre, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rotulo,
                          style: TextStyle(
                            fontSize: 11.5,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: escuro ? cor : Color.lerp(cor, Colors.black, 0.2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.2),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            _capitalizar(dataPorExtenso(ocorrencia.inicio, agora)),
                            if (!e.diaInteiro) faixaHorario(ocorrencia),
                          ].join(' · '),
                          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                        if (local != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.place_outlined, size: tipo == TipoEvento.consulta ? 20 : 16, color: cor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  local,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: tipo == TipoEvento.consulta ? 14.5 : 13,
                                    fontWeight: tipo == TipoEvento.consulta ? FontWeight.w600 : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (item != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ItemSwatch(
                                cor: item.cor,
                                densidade: state.densidade,
                                texto: item.sigla,
                                largura: 48,
                                altura: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(item.nome,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ---------------------------------------------------------- mini calendário

const _kIniciais = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

class _MiniCalendario extends StatelessWidget {
  const _MiniCalendario({
    required this.mes,
    required this.cor,
    required this.diasComEvento,
    required this.escolhido,
    required this.aoMudarMes,
    required this.aoEscolher,
  });

  final DateTime mes;
  final Color cor;
  final Set<int> diasComEvento;
  final DateTime? escolhido;
  final ValueChanged<DateTime> aoMudarMes;
  final ValueChanged<DateTime> aoEscolher;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final hoje = inicioDoDia(agora);
    final diasNoMes = DateTime(mes.year, mes.month + 1, 0).day;
    final vazios = DateTime(mes.year, mes.month).weekday - 1;
    final sobre = ThemeData.estimateBrightnessForColor(cor) == Brightness.dark ? Colors.white : Colors.black;

    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Mês anterior',
                  onPressed: () => aoMudarMes(DateTime(mes.year, mes.month - 1)),
                ),
                Expanded(
                  child: Text(
                    nomeDoMes(mes, agora),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Próximo mês',
                  onPressed: () => aoMudarMes(DateTime(mes.year, mes.month + 1)),
                ),
              ],
            ),
            Row(
              children: [
                for (final l in _kIniciais)
                  Expanded(
                    child: Text(
                      l,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.1,
              children: [
                for (var i = 0; i < vazios; i++) const SizedBox.shrink(),
                for (var d = 1; d <= diasNoMes; d++)
                  () {
                    final data = DateTime(mes.year, mes.month, d);
                    final tem = diasComEvento.contains(d);
                    final sel = escolhido == data;
                    final ehHoje = data == hoje;
                    return InkResponse(
                      onTap: () => aoEscolher(data),
                      radius: 22,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sel
                                  ? cor
                                  : tem
                                      ? cor.withValues(alpha: 0.16)
                                      : null,
                              border: ehHoje && !sel ? Border.all(color: cor, width: 1.6) : null,
                            ),
                            child: Text(
                              '$d',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: tem || ehHoje ? FontWeight.w700 : FontWeight.w400,
                                color: sel
                                    ? sobre
                                    : data.isBefore(hoje)
                                        ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                                        : scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tem && !sel ? cor : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    );
                  }(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PainelDoDia extends StatelessWidget {
  const _PainelDoDia({
    required this.dia,
    required this.ocorrencias,
    required this.tipo,
    required this.cor,
    required this.aoFechar,
  });

  final DateTime dia;
  final List<Ocorrencia> ocorrencias;
  final TipoEvento tipo;
  final Color cor;
  final VoidCallback aoFechar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cor.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _capitalizar(dataPorExtenso(dia, agora)),
                    style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), tooltip: 'Fechar', onPressed: aoFechar),
              ],
            ),
            if (ocorrencias.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Nada neste dia.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              for (var i = 0; i < ocorrencias.length; i++)
                _LinhaDoTempo(
                  ocorrencia: ocorrencias[i],
                  tipo: tipo,
                  cor: cor,
                  ultima: i == ocorrencias.length - 1,
                ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ séries e linha

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
        child: Text(
          texto.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 0.9,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

/// "Toda semana · qui 16:00" — o jeito curto de dizer quando a série cai.
String _quandoRepete(Evento e) {
  final h = e.diaInteiro ? '' : ' ${hora(e.inicio)}';
  return switch (e.repeticao) {
    Repeticao.diaria => 'Todo dia$h',
    Repeticao.semanal => 'Toda ${diaAbreviado(e.inicio).toLowerCase()}$h',
    Repeticao.mensal => 'Todo dia ${e.inicio.day}$h',
    Repeticao.anual => 'Todo ano em ${diaMes(e.inicio)}',
    Repeticao.nenhuma => '',
  };
}

class _LinhaSerie extends StatelessWidget {
  const _LinhaSerie({required this.serie, required this.cor});

  final Serie serie;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final e = serie.evento;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Color.alphaBlend(cor.withValues(alpha: 0.08), scheme.surfaceContainerLow),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => abrirDetalhesDoEvento(context, serie.proxima),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.repeat, color: cor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${_quandoRepete(e)} · próxima ${rotuloDoDia(serie.proxima.inicio, agora).toLowerCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${serie.vezes}×',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Uma linha da linha do tempo: data à esquerda presa a uma bolinha e a um
/// fio vertical que liga ao próximo; à direita um cartãozinho.
class _LinhaDoTempo extends StatelessWidget {
  const _LinhaDoTempo({
    required this.ocorrencia,
    required this.tipo,
    required this.cor,
    required this.ultima,
  });

  final Ocorrencia ocorrencia;
  final TipoEvento tipo;
  final Color cor;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final e = ocorrencia.evento;
    final Item? item = state.itemPorId(e.itemId);
    final local = e.local ?? item?.local;
    final ehHoje = inicioDoDia(ocorrencia.inicio) == inicioDoDia(agora);

    final detalhe = [
      if (!e.diaInteiro) faixaHorario(ocorrencia),
      ?local,
      if (e.repeticao != Repeticao.nenhuma) _quandoRepete(e),
    ].join(' · ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Text(
                  diaAbreviado(ocorrencia.inicio).toLowerCase(),
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
                Text(
                  '${ocorrencia.inicio.day}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ehHoje ? cor : scheme.onSurface,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: ehHoje ? cor : scheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: cor, width: 2.5),
                  ),
                ),
                if (!ultima)
                  Expanded(
                    child: Container(width: 2, color: cor.withValues(alpha: 0.3)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => abrirDetalhesDoEvento(context, ocorrencia),
                  child: Row(
                    children: [
                      Container(width: 4, color: item == null ? cor : item.cor.tone(scheme.brightness == Brightness.dark ? 80 : 40)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.titulo,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                              ),
                              if (detalhe.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  detalhe,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (_kContaDias.contains(tipo) && !ocorrencia.inicio.isBefore(inicioDoDia(agora)))
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              contagemRegressiva(ocorrencia.inicio, agora),
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: cor),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.tipo});

  final TipoEvento tipo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(iconeDoTipo(tipo), size: 48, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            'Nada marcado. Crie pelo botão da tela Semana, ou escolha este '
            'tipo pra uma agenda do Google em Agendas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
