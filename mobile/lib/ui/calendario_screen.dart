import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../state/app_state.dart';
import '../util/formato_data.dart';
import 'evento_editor.dart';
import 'widgets/evento_tile.dart';
import 'widgets/largura_maxima.dart';

const List<String> _kMeses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

const List<String> _kIniciais = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

/// Quantas marcas cabem numa célula de dia antes de virar "+N".
const int _kMarcasPorDia = 3;

/// Visão mensal de todos os eventos: grade do mês em cima, eventos do dia
/// escolhido embaixo.
///
/// Complementa a lista "Próximos" (que só olha 14 dias pra frente) e a
/// grade da semana (que só mostra o que cabe na tabela): aqui aparece
/// tudo, de qualquer tabela, em qualquer data. Trocar de mês por swipe ou
/// pelas setas; tocar num dia mostra os eventos dele; segurar o dia (ou
/// "+") cria um evento naquele dia.
class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  late DateTime _mes; // dia 1 do mês mostrado
  late DateTime _selecionado;

  @override
  void initState() {
    super.initState();
    final hoje = inicioDoDia(DateTime.now());
    _mes = DateTime(hoje.year, hoje.month);
    _selecionado = hoje;
  }

  void _mudarMes(int delta) {
    setState(() {
      _mes = DateTime(_mes.year, _mes.month + delta);
      // Seleção acompanha: hoje se for o mês atual, senão o dia 1.
      final hoje = inicioDoDia(DateTime.now());
      _selecionado = hoje.year == _mes.year && hoje.month == _mes.month ? hoje : _mes;
    });
  }

  void _irParaHoje() {
    final hoje = inicioDoDia(DateTime.now());
    setState(() {
      _mes = DateTime(hoje.year, hoje.month);
      _selecionado = hoje;
    });
  }

  Future<void> _novoEvento(DateTime dia) {
    final agora = DateTime.now();
    // Hora cheia seguinte, no dia escolhido — o mesmo default do botão de
    // evento da tela inicial, só que na data certa.
    final hora = (agora.hour + 1).clamp(0, 23);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventoEditor(
          inicio: DateTime(dia.year, dia.month, dia.day, hora),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final hoje = inicioDoDia(DateTime.now());

    // Sempre 6 semanas a partir da segunda que abre a grade: altura fixa,
    // sem a grade pular de tamanho entre meses de 4, 5 ou 6 linhas.
    final primeiroDia = DateTime(_mes.year, _mes.month, 1 - (_mes.weekday - 1));
    final fimDaGrade = DateTime(primeiroDia.year, primeiroDia.month, primeiroDia.day + 42);

    final porDia = <DateTime, List<Ocorrencia>>{};
    for (final o in state.ocorrenciasEntre(primeiroDia, fimDaGrade)) {
      (porDia[inicioDoDia(o.inicio)] ??= []).add(o);
    }
    // Dia todo primeiro, depois por hora — mesma ordem da lista embaixo.
    for (final lista in porDia.values) {
      lista.sort((a, b) {
        if (a.evento.diaInteiro != b.evento.diaInteiro) {
          return a.evento.diaInteiro ? -1 : 1;
        }
        return a.inicio.compareTo(b.inicio);
      });
    }
    final doDia = porDia[_selecionado] ?? const <Ocorrencia>[];
    final noMes = porDia.entries
        .where((e) => e.key.month == _mes.month && e.key.year == _mes.year)
        .fold(0, (soma, e) => soma + e.value.length);
    final mostrandoMesAtual = _mes.year == hoje.year && _mes.month == hoje.month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário'),
        actions: [
          if (!mostrandoMesAtual || _selecionado != hoje)
            TextButton(onPressed: _irParaHoje, child: const Text('Hoje')),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _novoEvento(_selecionado),
        tooltip: 'Novo evento neste dia',
        child: const Icon(Icons.add),
      ),
      body: LarguraMaxima(
        child: GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -200) _mudarMes(1);
            if (v > 200) _mudarMes(-1);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _mudarMes(-1),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Mês anterior',
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${_kMeses[_mes.month - 1]} ${_mes.year}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          noMes == 0
                              ? 'Nenhum evento'
                              : noMes == 1
                                  ? '1 evento'
                                  : '$noMes eventos',
                          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _mudarMes(1),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Próximo mês',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final l in _kIniciais)
                    Expanded(
                      child: Center(
                        child: Text(
                          l,
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              for (var semana = 0; semana < 6; semana++)
                Row(
                  children: [
                    for (var d = 0; d < 7; d++)
                      Expanded(
                        child: Builder(builder: (context) {
                          final dia = DateTime(
                            primeiroDia.year,
                            primeiroDia.month,
                            primeiroDia.day + semana * 7 + d,
                          );
                          return _CelulaDoDia(
                            dia: dia,
                            doMes: dia.month == _mes.month,
                            hoje: dia == hoje,
                            selecionado: dia == _selecionado,
                            ocorrencias: porDia[dia] ?? const [],
                            aoTocar: () => setState(() {
                              _selecionado = dia;
                              // Tocar num dia do mês vizinho leva pra ele.
                              if (dia.month != _mes.month) {
                                _mes = DateTime(dia.year, dia.month);
                              }
                            }),
                            aoSegurar: () => _novoEvento(dia),
                          );
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${rotuloDoDia(_selecionado, DateTime.now())}'
                  '${_selecionado == hoje || _selecionado == DateTime(hoje.year, hoje.month, hoje.day + 1) ? ' · ${diaMes(_selecionado)}' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (doDia.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Nada neste dia. Toque em + (ou segure o dia) pra criar.',
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                )
              else
                for (final o in doDia) EventoTile(ocorrencia: o),
            ],
          ),
        ),
      ),
    );
  }
}

class _CelulaDoDia extends StatelessWidget {
  const _CelulaDoDia({
    required this.dia,
    required this.doMes,
    required this.hoje,
    required this.selecionado,
    required this.ocorrencias,
    required this.aoTocar,
    required this.aoSegurar,
  });

  final DateTime dia;
  final bool doMes;
  final bool hoje;
  final bool selecionado;
  final List<Ocorrencia> ocorrencias;
  final VoidCallback aoTocar;
  final VoidCallback aoSegurar;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final escuro = scheme.brightness == Brightness.dark;

    final corNumero = selecionado
        ? scheme.onPrimary
        : hoje
            ? scheme.primary
            : doMes
                ? scheme.onSurface
                : scheme.onSurfaceVariant.withValues(alpha: 0.5);

    final visiveis = ocorrencias.take(_kMarcasPorDia).toList();
    final excedente = ocorrencias.length - visiveis.length;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      // Toque longo, não duplo: com onDoubleTap o toque simples esperaria
      // ~300ms pra confirmar que não vem um segundo, e selecionar dia
      // ficaria lento.
      onLongPress: aoSegurar,
      child: Container(
        height: 62,
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.fromLTRB(3, 4, 3, 3),
        decoration: BoxDecoration(
          color: selecionado ? scheme.surfaceContainerHighest : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selecionado ? scheme.primary : null,
                shape: BoxShape.circle,
                border: hoje && !selecionado
                    ? Border.all(color: scheme.primary, width: 1.2)
                    : null,
              ),
              child: Text(
                '${dia.day}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: hoje || selecionado ? FontWeight.w700 : FontWeight.w400,
                  color: corNumero,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Uma barrinha por evento, na cor do item vinculado (ou neutra):
            // dá pra bater o olho no mês e ver "semana de provas de SO"
            // sem ler nada.
            for (final o in visiveis)
              Container(
                height: 4,
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: (state.itemPorId(o.evento.itemId)?.cor.tone(escuro ? 70 : 50) ??
                          (o.evento.corExterna == null
                              ? null
                              : Color(o.evento.corExterna!)) ??
                          scheme.outline)
                      .withValues(alpha: doMes ? 1 : 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            if (excedente > 0)
              Text(
                '+$excedente',
                style: TextStyle(fontSize: 8.5, height: 1, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}
