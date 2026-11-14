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

/// A página de um tipo. Topo fixo: o próximo em destaque com contagem
/// regressiva (desliza pras seguintes) e o calendário do mês com bolinhas na
/// cor do tipo. Embaixo, a única parte que rola: a lista do mês do
/// calendário (séries uma vez, com quantas no mês) ou, tocando num dia, só
/// aquele dia.
class EventosDoTipoScreen extends StatefulWidget {
  const EventosDoTipoScreen({super.key, required this.tipo});

  final TipoEvento tipo;

  @override
  State<EventosDoTipoScreen> createState() => _EventosDoTipoScreenState();
}

class _EventosDoTipoScreenState extends State<EventosDoTipoScreen> {
  late DateTime _mes;
  DateTime? _diaEscolhido;

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

    final pagina = organizarPaginaDoTipo(_doTipo(state, hoje, hoje.add(const Duration(days: 365))), agora);
    final doMes = _doTipo(state, _mes, DateTime(_mes.year, _mes.month + 1));
    final diasComEvento = {for (final o in doMes) o.inicio.day};
    final vazio = pagina.total == 0 && doMes.isEmpty;

    final topo = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(
          _resumo(pagina, state, agora),
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      ),
      if (pagina.destaques.isNotEmpty)
        _Destaques(ocorrencias: pagina.destaques, tipo: widget.tipo, cor: cor)
      else if (vazio)
        _Vazio(tipo: widget.tipo),
      const SizedBox(height: 12),
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
    ];
    final lista = _lista(state, doMes, cor, agora);

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
      body: LayoutBuilder(
        builder: (context, c) {
          // Tela baixa (deitado, janela pequena): sobra quase nada pra lista
          // com o topo fixo — aí rola tudo junto, como antes.
          if (c.maxHeight < 620) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [...topo, ...lista],
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...topo,
                Expanded(
                  child: ListView(padding: const EdgeInsets.only(bottom: 32), children: lista),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// A parte de baixo: o mês do calendário, ou só o dia tocado.
  List<Widget> _lista(AppState state, List<Ocorrencia> doMes, Color cor, DateTime agora) {
    final hoje = inicioDoDia(agora);
    Widget linha(Ocorrencia o, bool ultima) {
      final passou = inicioDoDia(o.inicio).isBefore(hoje);
      final w = _LinhaDoTempo(ocorrencia: o, tipo: widget.tipo, cor: cor, ultima: ultima);
      return passou ? Opacity(opacity: 0.55, child: w) : w;
    }

    if (_diaEscolhido case final dia?) {
      final doDia = [for (final o in doMes) if (o.cobre(dia)) o];
      return [
        _Cabecalho(
          texto: _capitalizar(dataPorExtenso(dia, agora)),
          aoLimpar: () => setState(() => _diaEscolhido = null),
        ),
        if (doDia.isEmpty)
          _Nada('Nada neste dia.')
        else
          for (var i = 0; i < doDia.length; i++) linha(doDia[i], i == doDia.length - 1),
      ];
    }

    final mes = organizarMesDoTipo(doMes, agora);
    final nome = nomeDoMes(_mes, agora);
    final n = mes.series.length + mes.avulsas.length;
    if (mes.vazio) {
      // Pula pro próximo mês que tem algo (só olhando pra frente).
      final fimDoMes = DateTime(_mes.year, _mes.month + 1);
      final seguinte = _doTipo(state, fimDoMes, fimDoMes.add(const Duration(days: 365))).firstOrNull;
      return [
        _Cabecalho(texto: nome),
        _Nada('Nada em ${nome.toLowerCase()}.'),
        if (seguinte != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _mes = DateTime(seguinte.inicio.year, seguinte.inicio.month)),
              icon: const Icon(Icons.chevron_right),
              label: Text(
                '${widget.tipo == TipoEvento.prova || widget.tipo == TipoEvento.consulta || widget.tipo == TipoEvento.reuniao || widget.tipo == TipoEvento.viagem ? 'Próxima' : 'Próximo'} em '
                '${nomeDoMes(DateTime(seguinte.inicio.year, seguinte.inicio.month), agora).toLowerCase()}',
              ),
            ),
          ),
      ];
    }
    return [
      _Cabecalho(texto: '$nome · $n'),
      for (final serie in mes.series) _LinhaSerie(serie: serie, cor: cor, noMes: nome.toLowerCase()),
      for (var i = 0; i < mes.avulsas.length; i++) linha(mes.avulsas[i], i == mes.avulsas.length - 1),
    ];
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

/// Altura fixa do destaque — o topo da página não rola, e o PageView
/// precisa de uma.
const double _kAlturaDoDestaque = 126;

/// O destaque desliza entre as próximas (uma por evento); o card seguinte
/// aparece na borda pra mostrar que dá.
class _Destaques extends StatefulWidget {
  const _Destaques({required this.ocorrencias, required this.tipo, required this.cor});

  final List<Ocorrencia> ocorrencias;
  final TipoEvento tipo;
  final Color cor;

  @override
  State<_Destaques> createState() => _DestaquesState();
}

class _DestaquesState extends State<_Destaques> {
  late final PageController _controle = PageController(viewportFraction: 0.9);
  int _pagina = 0;

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.ocorrencias.length;
    if (n == 1) {
      return SizedBox(
        height: _kAlturaDoDestaque,
        child: _Destaque(ocorrencia: widget.ocorrencias.single, tipo: widget.tipo, cor: widget.cor, primeira: true),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: _kAlturaDoDestaque,
          child: PageView.builder(
            controller: _controle,
            padEnds: false,
            itemCount: n,
            onPageChanged: (i) => setState(() => _pagina = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _Destaque(
                ocorrencia: widget.ocorrencias[i],
                tipo: widget.tipo,
                cor: widget.cor,
                primeira: i == 0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < n; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _pagina ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _pagina ? widget.cor : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Destaque extends StatelessWidget {
  const _Destaque({required this.ocorrencia, required this.tipo, required this.cor, required this.primeira});

  final Ocorrencia ocorrencia;
  final TipoEvento tipo;
  final Color cor;

  /// "PRÓXIMA PROVA" só na primeira; as seguintes dizem "DEPOIS".
  final bool primeira;

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

    final rotulo = !primeira
        ? 'DEPOIS'
        : switch (tipo) {
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
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contagem regressiva: o número grande é o que o olho pega.
                  Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        Text(
                          numero,
                          style: TextStyle(
                            fontSize: numero.length > 3 ? 18 : 26,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            _capitalizar(dataPorExtenso(ocorrencia.inicio, agora)),
                            if (!e.diaInteiro) faixaHorario(ocorrencia),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                        // Uma linha a mais só: o item, ou (sem item) o local.
                        if (local != null && item == null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.place_outlined, size: tipo == TipoEvento.consulta ? 20 : 16, color: cor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  local,
                                  maxLines: 1,
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
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              ItemSwatch(
                                cor: item.cor,
                                densidade: state.densidade,
                                texto: item.sigla,
                                largura: 44,
                                altura: 20,
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
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
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
              childAspectRatio: 1.45,
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
                            width: 28,
                            height: 28,
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
                          const SizedBox(height: 1),
                          Container(
                            width: 4,
                            height: 4,
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

// ------------------------------------------------------------ séries e linha

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
  const _LinhaSerie({required this.serie, required this.cor, required this.noMes});

  final Serie serie;
  final Color cor;

  /// "novembro": a contagem é do mês da lista.
  final String noMes;

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
                        [
                          serie.padrao ?? _quandoRepete(e),
                          '${serie.vezes}× em $noMes',
                          if (naoPassou(serie.proxima, agora))
                            'próxima ${rotuloDoDia(serie.proxima.inicio, agora).toLowerCase()}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                      ),
                    ],
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
                      // Avaliação que já aconteceu: a nota, ou "sem nota" bem
                      // discreto (registra, não cobra).
                      if (e.avaliavel && ocorrencia.inicio.isBefore(agora))
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: switch (e.notaEm(ocorrencia.inicio)) {
                            final nota? => Text(
                                nota.curto,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cor),
                              ),
                            null => Text(
                                'sem nota',
                                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                              ),
                          },
                        )
                      else if (_kContaDias.contains(tipo) && !ocorrencia.inicio.isBefore(inicioDoDia(agora)))
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

/// Cabeçalho da lista: "Novembro · 4", ou o dia tocado com um × pra voltar
/// ao mês.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.texto, this.aoLimpar});

  final String texto;
  final VoidCallback? aoLimpar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rotulo = Text(
      texto.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        letterSpacing: 0.9,
        fontWeight: FontWeight.w700,
        color: scheme.onSurfaceVariant,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 0, 6),
      child: aoLimpar == null
          ? rotulo
          : Row(
              children: [
                Expanded(child: rotulo),
                InputChip(
                  label: const Text('Mês todo'),
                  onPressed: aoLimpar,
                  onDeleted: aoLimpar,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
    );
  }
}

class _Nada extends StatelessWidget {
  const _Nada(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Text(texto, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
