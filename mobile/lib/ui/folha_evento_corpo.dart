import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../state/app_state.dart';
import '../theme/color_density.dart';
import '../theme/tipo_evento_visual.dart';
import '../util/formato_data.dart';
import 'detalhes_evento.dart';
import 'folha_evento.dart';
import 'widgets/chip_deslizavel.dart';
import 'widgets/folha_evento_partes.dart';
import 'widgets/grade_de_chips.dart';

/// 120 → "2h", 90 → "1h30", 45 → "45 min".
String _duracaoCurta(int min) => min < 60
    ? '$min min'
    : '${min ~/ 60}h${min % 60 == 0 ? '' : (min % 60).toString().padLeft(2, '0')}';

String _hhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// O desenho da folha de evento, de cima pra baixo: título, tipo, item,
/// quando, horário, duração, detalhes (local, repetição, onde salvar) e
/// notas; "Salvar" fica preso embaixo. As regras ficam em
/// [FolhaDeEventoState].
///
/// Todas as linhas de chips usam a [GradeDeChips]: mesma altura e linhas
/// justificadas, bordas alinhadas de uma seção pra outra.
class CorpoDaFolha extends StatelessWidget {
  const CorpoDaFolha({super.key, required this.f});

  final FolhaDeEventoState f;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = f.item;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  f.novo ? Icons.event_available : Icons.edit_calendar,
                  size: 20,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  f.novo ? 'Novo evento' : 'Editar evento',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
              ),
              if (!f.novo)
                IconButton(
                  onPressed: f.apagar,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Apagar',
                ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Fechar',
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: f.titulo,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  decoration: _campo(
                    scheme,
                    rotulo: 'Título',
                    dica: f.tituloAutomatico.isEmpty ? 'Dentista, Aniversário de Pedro...' : f.tituloAutomatico,
                    fundo: scheme.surfaceContainerLow,
                  ),
                ),
                SecaoDaFolha(
                  icone: Icons.category_outlined,
                  titulo: 'Tipo',
                  resumo: f.tipo?.rotulo,
                  filhos: [
                    GradeDeChips(opcoes: [
                      for (final t in TipoEvento.values)
                        OpcaoChip(
                          rotulo: t.rotulo,
                          icone: iconeDoTipo(t),
                          selecionado: f.tipo == t,
                          aoTocar: () => f.escolherTipo(t),
                        ),
                    ]),
                  ],
                ),
                SecaoDaFolha(
                  icone: Icons.bookmark_outline,
                  titulo: 'Item',
                  resumo: item?.nome,
                  filhos: [_Itens(f: f)],
                ),
                SecaoDaFolha(
                  icone: Icons.event_outlined,
                  titulo: 'Quando',
                  resumo: _resumoQuando(f),
                  filhos: [
                    _Quando(f: f),
                    if (!f.semData || !f.ehTarefa) ...[
                      if (f.ehTarefa || !f.diaTodo) ...[
                        const RotuloLinha('Horário'),
                        _Horario(f: f),
                      ],
                      if (!f.ehTarefa) ...[
                        const RotuloLinha('Duração'),
                        _Duracao(f: f),
                      ],
                      if (f.diaTodo && !f.ehTarefa) ...[
                        const RotuloLinha('Até'),
                        _Ate(f: f),
                      ],
                      if (f.diaTodo) ...[
                        const RotuloLinha('Aviso'),
                        _Aviso(f: f),
                      ],
                      // Reunião costuma repetir: a escolha fica à vista
                      // aqui, sem vir marcada.
                      if (f.tipo == TipoEvento.reuniao) ...[
                        const RotuloLinha('Repete'),
                        GradeDeChips(opcoes: [
                          for (final r in Repeticao.values)
                            OpcaoChip(
                              rotulo: r.rotulo,
                              selecionado: f.repeticao == r,
                              aoTocar: () => f.escolherRepeticao(r),
                            ),
                        ]),
                      ],
                    ],
                  ],
                ),
                SecaoDaFolha(
                  icone: Icons.tune,
                  titulo: 'Detalhes',
                  filhos: [
                    if (f.tipo == TipoEvento.feriado || f.tipo == TipoEvento.viagem) ...[
                      SeletorFolga(
                        viagem: f.tipo == TipoEvento.viagem,
                        folga: f.folga,
                        aoMudar: f.escolherFolga,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _Detalhes(f: f),
                    const SizedBox(height: 10),
                    TextField(
                      controller: f.notas,
                      minLines: 2,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _campo(
                        scheme,
                        rotulo: 'Notas (opcional)',
                        dica: 'Conteúdo, o que levar...',
                        fundo: scheme.surfaceContainerHighest,
                      ),
                    ),
                    if (f.repeticao != Repeticao.nenhuma && !f.novo)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Mudanças valem pra todas as repetições.',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: f.salvar,
                icon: const Icon(Icons.check),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                label: const Text('Salvar'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "qui 12/11 · 10:00–12:00", "sáb 14/11 · dia todo", "seg 16/11 · 23:59".
  static String _resumoQuando(FolhaDeEventoState f) {
    final base = _resumoQuandoBase(f);
    // Em Reunião a repetição mora nesta seção: aparece no resumo também.
    return f.tipo == TipoEvento.reuniao && f.repeticao != Repeticao.nenhuma
        ? '$base · ${f.repeticao.rotulo.toLowerCase()}'
        : base;
  }

  static String _resumoQuandoBase(FolhaDeEventoState f) {
    if (f.ehTarefa && f.semData) return 'sem data';
    final dia = '${diaAbreviado(f.data).toLowerCase()} ${diaMes(f.data)}';
    if (f.variosDias) {
      final ate = f.ate!;
      final comeco = f.data.month == ate.month ? '${f.data.day}' : diaMes(f.data);
      return '${diaAbreviado(f.data).toLowerCase()} $comeco – ${diaAbreviado(ate).toLowerCase()} ${diaMes(ate)}';
    }
    final volta = f.fimOutroDia;
    if (!f.diaTodo && volta != null) {
      final comeco = f.data.month == volta.month ? '${f.data.day}' : diaMes(f.data);
      return '${diaAbreviado(f.data).toLowerCase()} $comeco ${_hhmm(f.horaInicio)} – '
          '${diaAbreviado(volta).toLowerCase()} ${diaMes(volta)} ${_hhmm(TimeOfDay.fromDateTime(volta))}';
    }
    if (f.diaTodo) return '$dia · ${f.ehTarefa ? 'sem hora' : 'dia todo'}';
    if (f.minutos == 0) return '$dia · ${_hhmm(f.horaInicio)}';
    final fim = f.horaInicio.hour * 60 + f.horaInicio.minute + f.minutos;
    return '$dia · ${_hhmm(f.horaInicio)}–${_hhmm(TimeOfDay(hour: fim ~/ 60 % 24, minute: fim % 60))}';
  }

  static InputDecoration _campo(
    ColorScheme scheme, {
    required String rotulo,
    required String dica,
    required Color fundo,
  }) =>
      InputDecoration(
        labelText: rotulo,
        hintText: dica,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: fundo,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      );
}

class _Itens extends StatelessWidget {
  const _Itens({required this.f});

  final FolhaDeEventoState f;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final itens = f.itensDaTabela;
    return GradeDeChips(opcoes: [
      for (final i in itens)
        () {
          final estilo = resolveCellStyle(cor: i.cor, densidade: ColorDensity.solido, esquema: scheme);
          final sel = f.itemId == i.id;
          return OpcaoChip(
            rotulo: i.sigla,
            selecionado: sel,
            aoTocar: () => f.escolherItem(i.id),
            fundo: sel ? estilo.background : estilo.background.withValues(alpha: 0.35),
            texto: estilo.foreground,
            borda: sel ? estilo.foreground : Colors.transparent,
          );
        }(),
      OpcaoChip(
        rotulo: itens.isEmpty ? 'Escolher item…' : 'Outro…',
        icone: Icons.search,
        selecionado: false,
        aoTocar: () async {
          final id = await escolherOutroItem(
            context,
            [for (final i in state.itens) if (!i.arquivado) i],
          );
          if (id != null && id != f.itemId) f.escolherItem(id);
        },
      ),
    ]);
  }
}

class _Quando extends StatelessWidget {
  const _Quando({required this.f});

  final FolhaDeEventoState f;

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final hoje = inicioDoDia(agora);
    final amanha = DateTime(hoje.year, hoje.month, hoje.day + 1);
    final proximo = f.proximoDoItem;
    final ehProximo = proximo != null &&
        f.data == inicioDoDia(proximo.inicio) &&
        f.horaInicio == TimeOfDay.fromDateTime(proximo.inicio);
    final semData = f.ehTarefa && f.semData;
    final dataLivre = !semData && !ehProximo && f.data != hoje && f.data != amanha;

    return GradeDeChips(opcoes: [
      if (f.ehTarefa)
        OpcaoChip(
          rotulo: 'Sem data',
          icone: Icons.inbox_outlined,
          selecionado: semData,
          aoTocar: f.escolherSemData,
        ),
      if (proximo != null)
        OpcaoChip(
          rotulo: 'Próximo de ${f.item?.sigla} · '
              '${rotuloDoDia(proximo.inicio, agora).toLowerCase()} '
              '${_hhmm(TimeOfDay.fromDateTime(proximo.inicio))}',
          icone: Icons.event_repeat,
          selecionado: !semData && ehProximo,
          aoTocar: f.usarProximoDoItem,
        ),
      OpcaoChip(
        rotulo: 'Hoje',
        selecionado: !semData && !ehProximo && f.data == hoje,
        aoTocar: () => f.escolherData(hoje),
      ),
      OpcaoChip(
        rotulo: 'Amanhã',
        selecionado: !semData && !ehProximo && f.data == amanha,
        aoTocar: () => f.escolherData(amanha),
      ),
      OpcaoChip(
        rotulo: dataLivre ? '${diaAbreviado(f.data).toLowerCase()} ${diaMes(f.data)}' : 'Outra data',
        icone: Icons.calendar_today_outlined,
        selecionado: dataLivre,
        aoTocar: f.escolherDataNoCalendario,
      ),
    ]);
  }
}

/// Último dia de um evento de dia todo: um dia só ou até outra data.
class _Ate extends StatelessWidget {
  const _Ate({required this.f});

  final FolhaDeEventoState f;

  @override
  Widget build(BuildContext context) {
    final ate = f.ate;
    return GradeDeChips(opcoes: [
      OpcaoChip(
        rotulo: 'Só este dia',
        selecionado: !f.variosDias,
        aoTocar: f.escolherUmDiaSo,
      ),
      OpcaoChip(
        rotulo: f.variosDias ? '${diaAbreviado(ate!).toLowerCase()} ${diaMes(ate)}' : 'Outro dia…',
        icone: Icons.date_range,
        selecionado: f.variosDias,
        aoTocar: f.escolherAte,
      ),
    ]);
  }
}

class _Horario extends StatelessWidget {
  const _Horario({required this.f});

  final FolhaDeEventoState f;

  @override
  Widget build(BuildContext context) {
    return GradeDeChips(opcoes: [
      if (f.ehTarefa)
        OpcaoChip(
          rotulo: 'Sem hora',
          selecionado: f.diaTodo,
          aoTocar: f.escolherSemHora,
        ),
      for (final h in f.sugestoesDeHorario)
        () {
          final sigla = f.siglaNoHorario(h);
          return OpcaoChip(
            rotulo: sigla == null ? _hhmm(h) : '${_hhmm(h)} · $sigla',
            selecionado: !f.diaTodo && f.horaInicio == h,
            aoTocar: () => f.escolherHora(h),
          );
        }(),
      OpcaoChip(
        rotulo: 'Outro…',
        icone: Icons.schedule,
        selecionado: false,
        aoTocar: f.escolherHoraInicio,
      ),
    ]);
  }
}

/// Hora do aviso de evento de dia todo (tarefa sem hora, aniversário…).
class _Aviso extends StatelessWidget {
  const _Aviso({required this.f});

  final FolhaDeEventoState f;

  static const _opcoes = [7 * 60, 8 * 60, 12 * 60, 18 * 60];

  @override
  Widget build(BuildContext context) {
    final livre = !_opcoes.contains(f.avisoMin);
    String rotulo(int m) => _hhmm(TimeOfDay(hour: m ~/ 60, minute: m % 60));
    return GradeDeChips(opcoes: [
      for (final m in _opcoes)
        OpcaoChip(
          rotulo: rotulo(m),
          icone: m == _opcoes.first ? Icons.notifications_none : null,
          selecionado: f.avisoMin == m,
          aoTocar: () => f.escolherAviso(m),
        ),
      OpcaoChip(
        rotulo: livre ? rotulo(f.avisoMin) : 'Outro…',
        icone: Icons.schedule,
        selecionado: livre,
        aoTocar: f.escolherAvisoOutro,
      ),
    ]);
  }
}

class _Duracao extends StatelessWidget {
  const _Duracao({required this.f});

  final FolhaDeEventoState f;

  @override
  Widget build(BuildContext context) {
    final minItem = f.minutosDoItem;
    final sigla = f.item?.sigla;
    final outroDia = !f.diaTodo && f.fimOutroDia != null;
    final livre = !f.diaTodo && !outroDia && f.minutos != 0 && f.minutos != 30 &&
        f.minutos != 60 && f.minutos != 120 && f.minutos != minItem;

    final fim = f.horaInicio.hour * 60 + f.horaInicio.minute + f.minutos;
    final ate = _hhmm(TimeOfDay(hour: fim ~/ 60 % 24, minute: fim % 60));

    return GradeDeChips(opcoes: [
      OpcaoChip(
        rotulo: 'Dia todo',
        selecionado: f.diaTodo,
        aoTocar: () => f.escolherDuracao(diaInteiro: true),
      ),
      OpcaoChip(
        rotulo: 'Prazo',
        selecionado: !f.diaTodo && !outroDia && f.minutos == 0,
        aoTocar: () => f.escolherDuracao(min: 0),
      ),
      if (minItem != null && sigla != null)
        OpcaoChip(
          rotulo: '$sigla · ${_duracaoCurta(minItem)}',
          selecionado: !f.diaTodo && !outroDia && f.minutos == minItem,
          aoTocar: () => f.escolherDuracao(min: minItem),
        ),
      for (final (m, r) in const [(30, '30 min'), (60, '1h'), (120, '2h')])
        if (m != minItem)
          OpcaoChip(
            rotulo: r,
            selecionado: !f.diaTodo && !outroDia && f.minutos == m,
            aoTocar: () => f.escolherDuracao(min: m),
          ),
      OpcaoChip(
        rotulo: livre ? 'até $ate' : 'Outra…',
        icone: Icons.more_time,
        selecionado: livre,
        aoTocar: f.escolherDuracaoOutra,
      ),
      OpcaoChip(
        rotulo: outroDia
            ? 'até ${diaAbreviado(f.fimOutroDia!).toLowerCase()} ${diaMes(f.fimOutroDia!)} ${_hhmm(TimeOfDay.fromDateTime(f.fimOutroDia!))}'
            : 'Outro dia…',
        icone: Icons.date_range,
        selecionado: outroDia,
        aoTocar: f.escolherFimOutroDia,
      ),
    ]);
  }
}

/// Local, repetição e onde salvar: cada chip mostra o valor atual; tocar
/// abre o menu acima dele, segurar e arrastar escolhe direto.
class _Detalhes extends StatelessWidget {
  const _Detalhes({required this.f});

  final FolhaDeEventoState f;

  /// Agenda principal do Google tem o e-mail como nome: no chip, só a
  /// parte antes do @, pra caber.
  static String _curto(String nome) => nome.contains('@') ? nome.split('@').first : nome;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final gravaveis = state.agendasGravaveis;
    final local = f.local.text.trim();
    final sugeridos = f.locaisSugeridos;

    final menuLocal = [
      for (final l in sugeridos)
        OpcaoMenu(
          rotulo: l,
          subtitulo: l == f.item?.local ? 'Local de ${f.item!.sigla}' : null,
          icone: Icons.place_outlined,
          selecionada: l == local,
          aoEscolher: () => f.escolherLocal(l),
        ),
      OpcaoMenu(rotulo: 'Digitar…', icone: Icons.edit_outlined, aoEscolher: f.digitarLocal),
      if (local.isNotEmpty)
        OpcaoMenu(rotulo: 'Sem local', icone: Icons.close, aoEscolher: () => f.escolherLocal(null)),
    ];

    final destino = f.destino == null ? null : gravaveis[f.destino] ?? state.agendas[f.destino];

    return GradeDeChips(opcoes: [
      OpcaoChip(
        rotulo: local.isEmpty ? 'Local' : local,
        icone: Icons.place_outlined,
        selecionado: local.isNotEmpty,
        // Nada pra sugerir: o menu teria só "Digitar…", então vai direto.
        menu: menuLocal.length > 1 ? menuLocal : null,
        aoTocar: f.digitarLocal,
      ),
      if (!(f.ehTarefa && f.semData) && f.tipo != TipoEvento.reuniao)
      OpcaoChip(
        rotulo: f.repeticao.rotulo,
        icone: Icons.repeat,
        selecionado: f.repeticao != Repeticao.nenhuma,
        menu: [
          for (final r in Repeticao.values)
            OpcaoMenu(
              rotulo: r.rotulo,
              selecionada: r == f.repeticao,
              aoEscolher: () => f.escolherRepeticao(r),
            ),
        ],
      ),
      if ((gravaveis.isNotEmpty || f.destino != null) && !(f.ehTarefa && f.semData))
        OpcaoChip(
          rotulo: f.destino == null ? 'Só no app' : _curto(destino?.nome ?? 'Google'),
          icone: f.destino == null ? Icons.phone_android : Icons.cloud_outlined,
          selecionado: f.destino != null,
          menu: [
            OpcaoMenu(
              rotulo: 'Só no app',
              subtitulo: 'Não vai pro Google Agenda',
              icone: Icons.phone_android,
              selecionada: f.destino == null,
              aoEscolher: () => f.escolherDestino(null),
            ),
            for (final e in gravaveis.entries)
              OpcaoMenu(
                rotulo: e.value.nome,
                subtitulo: e.value.conta.isNotEmpty && e.value.conta != e.value.nome
                    ? e.value.conta
                    : e.value.nome.contains('@')
                        ? 'Agenda principal'
                        : null,
                cor: e.value.cor == null ? null : Color(e.value.cor!),
                icone: Icons.cloud_outlined,
                selecionada: f.destino == e.key,
                aoEscolher: () => f.escolherDestino(e.key),
              ),
          ],
        ),
    ]);
  }
}
