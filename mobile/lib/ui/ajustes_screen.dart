import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/color_density.dart';
import '../theme/item_palette.dart';
import '../theme/tipo_evento_visual.dart';
import '../novidades.dart';
import 'agendas_screen.dart';
import 'widgets/item_swatch.dart';
import 'widgets/largura_maxima.dart';

/// Minutos de antecedência oferecidos no seletor — presets, não campo livre,
/// que não tem por que digitar um número exato aqui.
const List<int> kOpcoesAntecedencia = [5, 10, 15, 20, 30, 45, 60];

/// Pede a permissão de notificação (Android 13+) só quando o usuário liga
/// o interruptor — não no início do app, sem contexto do porquê.
Future<void> alternarNotificacoes(BuildContext context, bool ativar) async {
  final state = context.read<AppState>();

  if (!ativar) {
    await state.definirNotificacoesAtivas(false);
    return;
  }

  final plugin = context.read<FlutterLocalNotificationsPlugin?>();
  final concedida = await plugin
      ?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  if (concedida == false) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sem permissão de notificação, o Android não deixa avisar.')),
    );
    return;
  }

  await state.definirNotificacoesAtivas(true);
}

/// Ajustes: cabeçalho (nome, versão, a grade em miniatura nas cores
/// atuais) e uma seção por assunto, cada uma abrindo a sua página. Uma
/// opção mora num lugar só (exceção: o sol/lua da Semana, atalho do tema).
class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    void abrir(Widget tela) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => tela));

    final tema = switch (state.tema) {
      ThemeMode.system => 'Sistema',
      ThemeMode.light => 'Claro',
      ThemeMode.dark => 'Escuro',
    };
    final cor = kCoresDoApp[state.corDoApp]?.nome ?? 'Material You';

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: LarguraMaxima(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tabelador', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        Text('Versão $kVersao', style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  MiniaturaDaGrade(densidade: state.densidade, largura: 110, altura: 14),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Secao(
              icone: Icons.palette_outlined,
              cor: const Color(0xFF7E57C2),
              titulo: 'Aparência',
              resumo: '$tema · $cor · ${state.densidade.label}',
              aoTocar: () => abrir(const _AparenciaPagina()),
            ),
            _Secao(
              icone: Icons.event_note_outlined,
              cor: const Color(0xFF2E7D32),
              titulo: 'Eventos e Tarefas',
              resumo: [
                state.resumoVisivel ? 'Resumo: ${state.linhasDoResumo} eventos' : 'Sem resumo',
                if (state.tiposEscondidos.isNotEmpty)
                  state.tiposEscondidos.length == 1 ? '1 tipo escondido' : '${state.tiposEscondidos.length} tipos escondidos',
              ].join(' · '),
              aoTocar: () => abrir(const _EventosETarefasPagina()),
            ),
            _Secao(
              icone: Icons.notifications_outlined,
              cor: const Color(0xFFEF6C00),
              titulo: 'Avisos',
              resumo: !state.notificacoesAtivas
                  ? 'Desligados'
                  : '${state.antecedenciaMinutos} min antes${state.notificarEventos ? ' · eventos também' : ''}',
              aoTocar: () => abrir(const _AvisosPagina()),
            ),
            _Secao(
              icone: Icons.event_available_outlined,
              cor: const Color(0xFF1E88E5),
              titulo: 'Google Agenda',
              resumo: switch (state.agendas.length) {
                0 => 'Nenhuma agenda',
                1 => '1 agenda',
                final n => '$n agendas',
              },
              aoTocar: () => abrir(const AgendasScreen()),
            ),
            _Secao(
              icone: Icons.save_outlined,
              cor: const Color(0xFF00897B),
              titulo: 'Dados',
              resumo: 'Exportar e importar backup',
              aoTocar: () => abrir(const _DadosPagina()),
            ),
            _Secao(
              icone: Icons.info_outline,
              cor: const Color(0xFF607D8B),
              titulo: 'Sobre',
              resumo: 'Novidades, introdução',
              aoTocar: () => abrir(const _SobrePagina()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha de seção: ícone num círculo colorido, título, valores atuais.
class _Secao extends StatelessWidget {
  const _Secao({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.resumo,
    required this.aoTocar,
  });

  final IconData icone;
  final Color cor;
  final String titulo;
  final String resumo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: cor,
        child: Icon(icone, color: Colors.white, size: 22),
      ),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        resumo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      onTap: aoTocar,
    );
  }
}

/// Página de uma seção: título e a lista das opções dela.
class _Pagina extends StatelessWidget {
  const _Pagina({required this.titulo, required this.filhos});

  final String titulo;
  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: LarguraMaxima(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: filhos),
        ),
      );
}

/// Rótulo de grupo dentro de uma página ("TEMA", "DENSIDADE DE COR").
class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

class _AparenciaPagina extends StatelessWidget {
  const _AparenciaPagina();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return _Pagina(
      titulo: 'Aparência',
      filhos: [
        const _Rotulo('TEMA'),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('Sistema'), icon: Icon(Icons.brightness_auto_outlined)),
            ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode_outlined)),
            ButtonSegment(value: ThemeMode.dark, label: Text('Escuro'), icon: Icon(Icons.dark_mode_outlined)),
          ],
          selected: {state.tema},
          showSelectedIcon: false,
          onSelectionChanged: (s) => state.definirTema(s.single),
        ),
        const _Rotulo('COR DO APP'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            BolinhaDeCor(
              rotulo: 'Material You',
              selecionada: state.corDoApp == null,
              aoEscolher: () => state.definirCorDoApp(null),
            ),
            for (final e in kCoresDoApp.entries)
              BolinhaDeCor(
                rotulo: e.value.nome,
                cor: e.value.cor,
                selecionada: state.corDoApp == e.key,
                aoEscolher: () => state.definirCorDoApp(e.key),
              ),
          ],
        ),
        const _Rotulo('DENSIDADE DE COR'),
        for (final densidade in ColorDensity.values) ...[
          _Opcao(
            densidade: densidade,
            selecionada: densidade == state.densidade,
            aoEscolher: () => state.definirDensidade(densidade),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Uma cor da paleta (ou o Material You, sem [cor]: as cores do papel de
/// parede, num círculo dividido). O nome aparece ao segurar.
class BolinhaDeCor extends StatelessWidget {
  const BolinhaDeCor({super.key, required this.rotulo, this.cor, required this.selecionada, required this.aoEscolher});

  final String rotulo;
  final Color? cor;
  final bool selecionada;
  final VoidCallback aoEscolher;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = cor;
    return Tooltip(
      message: rotulo,
      child: Semantics(
        label: rotulo,
        selected: selecionada,
        button: true,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: aoEscolher,
          child: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selecionada ? scheme.onSurface : Colors.transparent, width: 2.5),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c,
                gradient: c != null
                    ? null
                    : SweepGradient(colors: [
                        scheme.primary,
                        scheme.tertiary,
                        scheme.secondary,
                        scheme.primary,
                      ]),
              ),
              child: selecionada
                  ? Icon(Icons.check, color: c == null ? scheme.onPrimary : Colors.white, size: 22)
                  : c == null
                      ? Icon(Icons.wallpaper, color: scheme.onPrimary, size: 18)
                      : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Quantos eventos o resumo da Semana pode mostrar.
const List<int> kOpcoesLinhasDoResumo = [3, 4, 5, 6, 8, 10];

class _EventosETarefasPagina extends StatelessWidget {
  const _EventosETarefasPagina();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return _Pagina(
      titulo: 'Eventos e Tarefas',
      filhos: [
        const _Rotulo('ABAIXO DA GRADE DA SEMANA'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Resumo de eventos'),
          value: state.resumoVisivel,
          onChanged: state.definirResumoVisivel,
        ),
        if (state.resumoVisivel)
          Row(
            children: [
              const Expanded(child: Text('Quantos eventos')),
              DropdownButton<int>(
                value: kOpcoesLinhasDoResumo.contains(state.linhasDoResumo) ? state.linhasDoResumo : null,
                items: [
                  for (final n in kOpcoesLinhasDoResumo) DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (n) {
                  if (n != null) state.definirLinhasDoResumo(n);
                },
              ),
            ],
          ),
        const _Rotulo('TIPOS DE EVENTO'),
        for (final t in TipoEvento.values)
          if (t != TipoEvento.tarefa)
            Tooltip(
              message: 'Escondido: some da aba Eventos e da criação. Os eventos que já existem continuam na Semana.',
              triggerMode: TooltipTriggerMode.longPress,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(iconeDoTipo(t), color: corDoTipo(t, Theme.of(context).brightness)),
                title: Text(pluralDoTipo(t)),
                value: !state.tiposEscondidos.contains(t),
                onChanged: (visivel) => state.definirTipoEscondido(t, !visivel),
              ),
            ),
      ],
    );
  }
}

/// Quantos dias antes do aniversário o lembrete de presente pode vir.
const List<int> kOpcoesDiasPresente = [1, 2, 3, 5, 7, 10, 14];

String _hhmm(int minutos) =>
    '${(minutos ~/ 60).toString().padLeft(2, '0')}:${(minutos % 60).toString().padLeft(2, '0')}';

class _AvisosPagina extends StatelessWidget {
  const _AvisosPagina();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return _Pagina(
      titulo: 'Avisos',
      filhos: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Avisar antes de cada horário'),
          value: state.notificacoesAtivas,
          onChanged: (ativar) => alternarNotificacoes(context, ativar),
        ),
        if (state.notificacoesAtivas) ...[
          Row(
            children: [
              const Expanded(child: Text('Com quanto tempo de antecedência')),
              DropdownButton<int>(
                value: state.antecedenciaMinutos,
                items: [
                  for (final minutos in kOpcoesAntecedencia)
                    DropdownMenuItem(value: minutos, child: Text('$minutos min')),
                ],
                onChanged: (minutos) {
                  if (minutos != null) state.definirAntecedenciaMinutos(minutos);
                },
              ),
            ],
          ),
          Row(
            children: [
              const Expanded(child: Text('Aviso de dia todo')),
              TextButton(
                onPressed: () async {
                  final m = state.avisoDiaTodoMin;
                  final h = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
                  );
                  if (h != null) state.definirAvisoDiaTodoMin(h.hour * 60 + h.minute);
                },
                child: Text(_hhmm(state.avisoDiaTodoMin)),
              ),
            ],
          ),
          Row(
            children: [
              const Expanded(child: Text('Lembrete de presente')),
              DropdownButton<int>(
                value: kOpcoesDiasPresente.contains(state.diasAvisoPresente) ? state.diasAvisoPresente : null,
                items: [
                  for (final d in kOpcoesDiasPresente)
                    DropdownMenuItem(value: d, child: Text(d == 1 ? '1 dia antes' : '$d dias antes')),
                ],
                onChanged: (d) {
                  if (d != null) state.definirDiasAvisoPresente(d);
                },
              ),
            ],
          ),
          Tooltip(
            message: 'Com hora: na mesma antecedência. Dia todo: na hora do aviso de dia todo.',
            triggerMode: TooltipTriggerMode.longPress,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Avisar eventos também'),
              value: state.notificarEventos,
              onChanged: state.definirNotificarEventos,
            ),
          ),
        ],
      ],
    );
  }
}

class _DadosPagina extends StatelessWidget {
  const _DadosPagina();

  @override
  Widget build(BuildContext context) {
    return _Pagina(
      titulo: 'Dados',
      filhos: [
        const SizedBox(height: 8),
        _AcaoBackup(
          icone: Icons.upload_outlined,
          titulo: 'Exportar backup',
          descricao: 'Itens, tabelas, eventos e preferências num arquivo.',
          aoTocar: () => _exportar(context),
        ),
        const SizedBox(height: 8),
        _AcaoBackup(
          icone: Icons.download_outlined,
          titulo: 'Importar backup',
          descricao: 'Substitui tudo que está no app pelo conteúdo do arquivo.',
          aoTocar: () => _importar(context),
        ),
      ],
    );
  }
}

class _SobrePagina extends StatelessWidget {
  const _SobrePagina();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Pagina(
      titulo: 'Sobre',
      filhos: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Versão'),
          trailing: Text(kVersao, style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
        const _Rotulo('NOVIDADES'),
        for (final (versao, itens) in kNovidades) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(versao, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          for (final t in itens)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: scheme.onSurfaceVariant)),
                  Expanded(child: Text(t)),
                ],
              ),
            ),
        ],
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.waving_hand_outlined),
          title: const Text('Rever a introdução'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Volta pra raiz primeiro: a introdução toma o lugar da tela
            // inicial, e esta tela ficaria por cima dela.
            final state = context.read<AppState>();
            Navigator.of(context).popUntil((r) => r.isFirst);
            state.reverOnboarding();
          },
        ),
      ],
    );
  }
}

/// Junta tudo num JSON e abre o "salvar como" nativo (SAF) — o usuário
/// escolhe onde salvar (Drive, Arquivos, qualquer pasta). Evita pedir
/// permissão de armazenamento: quem escreve o arquivo de fato é o sistema,
/// o app só entrega os bytes.
Future<void> _exportar(BuildContext context) async {
  final state = context.read<AppState>();
  final json = const JsonEncoder.withIndent('  ').convert(state.paraBackup());

  final agora = DateTime.now();
  String dois(int n) => n.toString().padLeft(2, '0');
  final nome =
      'tabelador-backup-${agora.year}${dois(agora.month)}${dois(agora.day)}.json';

  final uri = await FilePicker.saveFile(
    fileName: nome,
    bytes: Uint8List.fromList(utf8.encode(json)),
    mimeType: 'application/json',
  );

  if (!context.mounted) return;
  _avisar(context, uri == null ? 'Exportação cancelada.' : 'Backup salvo.');
}

void _avisar(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
}

Future<void> _importar(BuildContext context) async {
  final arquivo = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (arquivo == null || !context.mounted) return;

  final Map<String, dynamic> dados;
  try {
    final bytes = await arquivo.readAsBytes();
    dados = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  } catch (_) {
    if (!context.mounted) return;
    _avisar(context, 'Esse arquivo não é um backup válido.');
    return;
  }

  if (!context.mounted) return;
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Importar backup?'),
      content: const Text(
        'Isso substitui todos os itens, tabelas e preferências atuais '
        'pelo conteúdo do arquivo. Não tem como desfazer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Importar'),
        ),
      ],
    ),
  );
  if (confirmou != true || !context.mounted) return;

  try {
    await context.read<AppState>().restaurarBackup(dados);
  } catch (_) {
    if (!context.mounted) return;
    _avisar(context, 'Esse arquivo não é um backup válido.');
    return;
  }

  if (!context.mounted) return;
  _avisar(context, 'Backup importado.');
}

class _AcaoBackup extends StatelessWidget {
  const _AcaoBackup({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.aoTocar,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: aoTocar,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icone, color: scheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    descricao,
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.densidade,
    required this.selecionada,
    required this.aoEscolher,
  });

  final ColorDensity densidade;
  final bool selecionada;
  final VoidCallback aoEscolher;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: aoEscolher,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selecionada ? scheme.surfaceContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selecionada ? scheme.primary : scheme.outlineVariant,
            width: selecionada ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            MiniaturaDaGrade(densidade: densidade),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    densidade.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    densidade.description,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selecionada
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selecionada ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Uma semana em miniatura, com a repetição e os vazios que a grade real tem.
class MiniaturaDaGrade extends StatelessWidget {
  const MiniaturaDaGrade({super.key, required this.densidade, this.largura = 82, this.altura = 10});

  final ColorDensity densidade;
  final double largura;
  final double altura;

  static const List<List<ItemColor?>> _amostra = [
    [
      ItemColor.oceano,
      ItemColor.oliva,
      ItemColor.oceano,
      ItemColor.oliva,
      null,
    ],
    [
      ItemColor.turquesa,
      null,
      ItemColor.turquesa,
      ItemColor.ametista,
      ItemColor.ametista,
    ],
    [
      ItemColor.ambar,
      ItemColor.ambar,
      ItemColor.ambar,
      ItemColor.ambar,
      ItemColor.ambar,
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largura,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final linha in _amostra)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  for (final cor in linha)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: SizedBox(
                          height: altura,
                          child: cor == null
                              ? const SizedBox.shrink()
                              : ItemSwatch(
                                  cor: cor,
                                  densidade: densidade,
                                  raio: 2,
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
