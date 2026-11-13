import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../state/app_state.dart';
import '../util/formato_data.dart';
import '../util/carro.dart';
import '../util/link_reuniao.dart';
import 'folha_evento.dart';
import 'editar_presente.dart';
import 'lancar_nota.dart';
import '../theme/tipo_evento_visual.dart';
import 'widgets/item_swatch.dart';

const _kDiaPorExtenso = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];

const _kMes = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

/// "quarta-feira, 11 de novembro" — o ano só aparece se não for o atual.
String dataPorExtenso(DateTime d, DateTime agora) {
  final ano = d.year == agora.year ? '' : ' de ${d.year}';
  return '${_kDiaPorExtenso[d.weekday - 1]}, ${d.day} de ${_kMes[d.month - 1]}$ano';
}

/// "Hoje", "Amanhã", "Ontem", "Em 5 dias", "Há 3 dias".
String distanciaEmDias(DateTime d, DateTime agora) {
  final dias = inicioDoDia(d).difference(inicioDoDia(agora)).inDays;
  return switch (dias) {
    0 => 'Hoje',
    1 => 'Amanhã',
    -1 => 'Ontem',
    > 1 => 'Em $dias dias',
    _ => 'Há ${-dias} dias',
  };
}

/// "ter 17/11 – sex 20/11 · 4 dias".
String _periodo(Ocorrencia o) {
  String dia(DateTime d) => '${diaAbreviado(d).toLowerCase()} ${diaMes(d)}';
  final n = (o.ultimoDia.difference(inicioDoDia(o.inicio)).inHours / 24).round() + 1;
  final comHora = !o.evento.diaInteiro;
  final texto = '${dia(o.inicio)}${comHora ? ' ${hora(o.inicio)}' : ''}'
      ' – ${dia(o.ultimoDia)}${comHora ? ' ${hora(o.fim)}' : ''} · $n dias';
  return texto[0].toUpperCase() + texto.substring(1);
}

/// 120 → "2 h", 90 → "1 h 30", 45 → "45 min".
String _duracao(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return '$m min';
  final resto = m % 60;
  return '${m ~/ 60} h${resto == 0 ? '' : ' ${resto.toString().padLeft(2, '0')}'}';
}

/// Abre o card de um evento: só leitura, resumido. O lápis (evento do app)
/// fecha o card e abre a folha de edição — tocar num evento é quase sempre
/// pra conferir, não pra mudar.
Future<void> abrirDetalhesDoEvento(BuildContext context, Ocorrencia ocorrencia) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => DetalhesDoEvento(
      ocorrencia: ocorrencia,
      aoEditar: () {
        Navigator.of(sheetContext).pop();
        if (context.mounted) {
          abrirFolhaDeEvento(context, original: ocorrencia.evento);
        }
      },
    ),
  );
}

class DetalhesDoEvento extends StatelessWidget {
  const DetalhesDoEvento({super.key, required this.ocorrencia, this.aoEditar});

  final Ocorrencia ocorrencia;
  final VoidCallback? aoEditar;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tema = Theme.of(context);
    final scheme = tema.colorScheme;
    final escuro = scheme.brightness == Brightness.dark;
    final agora = DateTime.now();

    // O card fica aberto enquanto a tarefa é concluída: relê o evento.
    final original = this.ocorrencia;
    final e = state.eventoPorId(original.evento.id) ?? original.evento;
    final ocorrencia = Ocorrencia(e, original.inicio, original.fim);
    final tarefa = e.ehTarefa;
    final feita = tarefa && ocorrencia.feita;
    final item = state.itemPorId(e.itemId);
    final tipo = TipoEvento.doTexto(e.tipo);
    final agendaOrigem = e.externo ? state.agendas[e.agendaId]?.nome : null;
    final link = linkDeReuniao(e);
    // O bloco de chamada que o Google cola na descrição some: o Entrar
    // faz o papel dele.
    final notasVisiveis = notasSemBlocoDeChamada(e.notas);
    final agendaDestino =
        e.gravadoNoGoogle ? state.agendas[e.agendaDestinoId]?.nome : null;

    // A cor do card segue a mesma lógica da lista: item vinculado → cor do
    // item; evento do Google sem item → cor da agenda; senão, a do tipo.
    final base = item != null
        ? item.cor.tone(escuro ? 80 : 40)
        : e.corExterna != null
            ? Color(e.corExterna!)
            : tipo != null
                ? corDoTipo(tipo, scheme.brightness)
                : scheme.primary;
    final fundoCabecalho = Color.alphaBlend(
      base.withValues(alpha: escuro ? 0.22 : 0.14),
      scheme.surfaceContainerLow,
    );
    final sobreBase =
        ThemeData.estimateBrightnessForColor(base) == Brightness.dark ? Colors.white : Colors.black;

    final passou = !e.semData &&
        ocorrencia.fim.isBefore(agora) &&
        !(e.diaInteiro && inicioDoDia(ocorrencia.inicio) == inicioDoDia(agora));

    final aviso = e.avisoMin ?? kAvisoDiaTodoPadrao;
    final textoAviso =
        '${(aviso ~/ 60).toString().padLeft(2, '0')}:${(aviso % 60).toString().padLeft(2, '0')}';
    final horario = e.diaInteiro
        ? [tarefa ? 'Sem hora' : 'Dia todo', if (tarefa || e.avisoMin != null) 'aviso às $textoAviso']
            .join(' · ')
        : [
            faixaHorario(ocorrencia),
            if (ocorrencia.fim.isAfter(ocorrencia.inicio)) _duracao(ocorrencia.fim.difference(ocorrencia.inicio)),
          ].join(' · ');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ------------------------------------------------- o card
          Card.filled(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: fundoCabecalho,
                  padding: const EdgeInsets.fromLTRB(20, 18, 8, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          tipo == null ? Icons.event : iconeDoTipo(tipo),
                          color: sobreBase,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                if (e.tipo.isNotEmpty) e.tipo,
                                if (feita)
                                  'Concluída'
                                else if (ocorrencia.variosDias && ocorrencia.acontecendo(agora))
                                  tipo == TipoEvento.viagem ? 'Em viagem' : 'Acontecendo'
                                else if (!e.semData)
                                  distanciaEmDias(ocorrencia.inicio, agora),
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: passou ? scheme.onSurfaceVariant : base,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              e.titulo,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                decoration: feita ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (aoEditar != null && !e.externo)
                        IconButton.filledTonal(
                          onPressed: aoEditar,
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _Linha(
                  icone: Icons.calendar_today_outlined,
                  texto: e.semData
                      ? 'Sem data'
                      : ocorrencia.variosDias
                          ? _periodo(ocorrencia)
                          : _capitalizar(dataPorExtenso(ocorrencia.inicio, agora)),
                ),
                // Vários dias com hora: a hora já está na linha da data.
                if (!e.semData && !(ocorrencia.variosDias && !e.diaInteiro))
                  _Linha(icone: Icons.schedule, texto: horario),
                if (e.repeticao != Repeticao.nenhuma)
                  _Linha(icone: Icons.repeat, texto: e.repeticao.rotulo),
                if (e.local != null) _Linha(icone: Icons.place_outlined, texto: e.local!),
                if (enderecoPraCarro(e, localDoItem: item?.local) case final endereco?)
                  _BotoesDeCarro(endereco: endereco, apelido: e.titulo),
                if (item != null)
                  _Linha(
                    icone: Icons.bookmark_outline,
                    texto: item.nome,
                    fim: ItemSwatch(
                      cor: item.cor,
                      densidade: state.densidade,
                      texto: item.sigla,
                      largura: 52,
                      altura: 26,
                    ),
                  ),
                if (notasVisiveis != null) _Linha(icone: Icons.notes, texto: notasVisiveis, multilinha: true),
                if (link != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: FilledButton.icon(
                      onPressed: () => _entrar(context, link),
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Entrar'),
                    ),
                  ),
                // Nota: só depois que a avaliação aconteceu (ou a tarefa foi
                // entregue). Lançada, a linha mostra e o toque edita.
                if (e.avaliavel && (!ocorrencia.inicio.isAfter(agora) || feita))
                  if (e.notaEm(ocorrencia.inicio) case final nota?)
                    InkWell(
                      onTap: () => abrirLancarNota(context, ocorrencia),
                      child: _Linha(icone: Icons.grade_outlined, texto: 'Nota: ${nota.texto}'),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: OutlinedButton.icon(
                        onPressed: () => abrirLancarNota(context, ocorrencia),
                        icon: const Icon(Icons.grade_outlined),
                        label: const Text('Lançar nota'),
                      ),
                    ),
                // Presente: um por ano (ocorrência). Guardado, a linha mostra
                // a ideia com "Comprado" ao lado e o toque edita.
                if (e.ehAniversario && !e.semData)
                  if (e.presenteEm(ocorrencia.inicio) case final presente?)
                    InkWell(
                      onTap: () => abrirEditarPresente(context, ocorrencia),
                      child: _Linha(
                        icone: Icons.card_giftcard,
                        texto: presente.ideia,
                        fim: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Comprado', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                            Checkbox(
                              value: presente.comprado,
                              onChanged: (v) =>
                                  state.definirPresente(ocorrencia, presente.comComprado(v ?? false)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: OutlinedButton.icon(
                        onPressed: () => abrirEditarPresente(context, ocorrencia),
                        icon: const Icon(Icons.card_giftcard),
                        label: const Text('Presente'),
                      ),
                    ),
                // Feriado do Google: o app não sabe se é folga (a agenda
                // mistura feriado com data comemorativa) — a pessoa diz.
                if ((e.ehFeriado || tipo == TipoEvento.viagem) && e.externo && !e.embutido)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SeletorFolga(
                      viagem: tipo == TipoEvento.viagem,
                      folga: !e.comemorativa,
                      aoMudar: (v) => state.definirFolgaExterna(e.id, v),
                    ),
                  ),
                // Tarefa do Classroom não abre na folha: a prioridade se
                // escolhe aqui.
                if (tarefa && e.externo && !feita)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SegmentedButton<Prioridade>(
                      segments: [
                        for (final p in Prioridade.values)
                          ButtonSegment(
                            value: p,
                            label: Text(p.rotulo),
                            icon: iconeDaPrioridade(p) == null ? null : Icon(iconeDaPrioridade(p)),
                          ),
                      ],
                      selected: {e.prioridade},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => state.definirPrioridadeExterna(e.id, s.first),
                    ),
                  ),
                if (tarefa)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: feita
                        ? OutlinedButton.icon(
                            onPressed: () => state.marcarFeita(ocorrencia, false),
                            icon: const Icon(Icons.undo),
                            label: const Text('Reabrir'),
                          )
                        : FilledButton.icon(
                            onPressed: () => state.marcarFeita(ocorrencia, true),
                            icon: const Icon(Icons.check),
                            label: Text(
                              e.repeticao == Repeticao.nenhuma ? 'Concluir' : 'Concluir esta',
                            ),
                          ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // ------------------------------------------------- rodapé: onde vive
          // Só quando o evento está no Google: "só neste aparelho" e "feriado
          // calculado pelo app" não mudam nada pra quem olha.
          if ((e.externo && !e.embutido) || e.gravadoNoGoogle)
            Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.externo
                        ? 'Do Google Agenda${agendaOrigem == null ? '' : ' · $agendaOrigem'}'
                        : 'Também no Google Agenda${agendaDestino == null ? '' : ' · $agendaDestino'}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _entrar(BuildContext context, String link) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!await abrirLink(link)) {
      messenger?.showSnackBar(const SnackBar(content: Text('Não deu pra abrir o link.')));
    }
  }

  static String _capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Folga ou data comemorativa — duas opções lado a lado, uma marcada. Usado
/// no card de detalhes do feriado do Google e na folha de criar feriado.
class SeletorFolga extends StatelessWidget {
  const SeletorFolga({super.key, required this.folga, required this.aoMudar, this.viagem = false});

  final bool folga;

  /// Viagem: "Sem aula" / "Mantém as aulas" em vez de Folga/Comemorativa.
  final bool viagem;
  final ValueChanged<bool> aoMudar;

  // A explicação de cada opção fica no segurar (tooltip), não na tela —
  // padrão do app pra informação que só serve a quem tem dúvida.
  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(
          value: true,
          label: Text(viagem ? 'Sem aula' : 'Folga'),
          icon: const Icon(Icons.beach_access_outlined),
          tooltip: viagem
              ? 'Os horários dos dias da viagem ficam apagados e sem aviso'
              : 'Sem aula nesse dia: os horários ficam apagados e sem aviso',
        ),
        ButtonSegment(
          value: false,
          label: Text(viagem ? 'Mantém as aulas' : 'Comemorativa'),
          icon: Icon(viagem ? Icons.school_outlined : Icons.celebration_outlined),
          tooltip: viagem
              ? 'As aulas seguem normais durante a viagem'
              : 'Só uma data pra lembrar: as aulas seguem normais',
        ),
      ],
      selected: {folga},
      onSelectionChanged: (s) => aoMudar(s.first),
    );
  }
}

/// Uber e 99 embaixo do local de Consulta e Compromisso — cada um só se o
/// app está instalado.
class _BotoesDeCarro extends StatefulWidget {
  const _BotoesDeCarro({required this.endereco, required this.apelido});

  final String endereco;
  final String apelido;

  @override
  State<_BotoesDeCarro> createState() => _BotoesDeCarroState();
}

class _BotoesDeCarroState extends State<_BotoesDeCarro> {
  /// Instalado não muda com o card aberto: pergunta uma vez por sessão.
  /// Ícone de cada app instalado (null = não instalado). Não muda com o
  /// card aberto: pergunta uma vez por sessão.
  static Future<(Uint8List?, Uint8List?)>? _icones;

  static Future<(Uint8List?, Uint8List?)> _verificar() async {
    Future<Uint8List?> icone(String pacote) async =>
        await appInstalado(pacote) ? (await iconeDoApp(pacote) ?? Uint8List(0)) : null;
    return (await icone(kPacoteUber), await icone(kPacote99));
  }

  static Widget _icone(Uint8List bytes) => bytes.isEmpty
      ? const Icon(Icons.local_taxi_outlined)
      : ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.memory(bytes, width: 20, height: 20),
        );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Uint8List?, Uint8List?)>(
      future: _icones ??= _verificar(),
      builder: (context, snap) {
        final (uber, noventaENove) = snap.data ?? (null, null);
        if (uber == null && noventaENove == null) return const SizedBox.shrink();
        final messenger = ScaffoldMessenger.maybeOf(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              if (uber != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (!await chamarUber(widget.endereco, apelido: widget.apelido)) {
                        messenger?.showSnackBar(const SnackBar(content: Text('Não deu pra abrir o Uber.')));
                      }
                    },
                    icon: _icone(uber),
                    label: const Text('Uber'),
                  ),
                ),
              if (uber != null && noventaENove != null) const SizedBox(width: 8),
              if (noventaENove != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final abriu = await chamar99(widget.endereco);
                      messenger?.showSnackBar(SnackBar(
                        content: Text(abriu ? 'Endereço copiado' : 'Não deu pra abrir a 99.'),
                      ));
                    },
                    icon: _icone(noventaENove),
                    label: const Text('99'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.icone, required this.texto, this.fim, this.multilinha = false});

  final IconData icone;
  final String texto;
  final Widget? fim;
  final bool multilinha;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      child: Row(
        crossAxisAlignment: multilinha ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icone, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              texto,
              maxLines: multilinha ? 20 : 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, height: 1.35),
            ),
          ),
          if (fim != null) ...[const SizedBox(width: 12), fim!],
        ],
      ),
    );
  }
}
