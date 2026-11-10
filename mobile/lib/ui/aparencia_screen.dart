import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/color_density.dart';
import '../theme/item_palette.dart';
import 'agendas_screen.dart';
import 'widgets/item_swatch.dart';
import 'widgets/largura_maxima.dart';

/// Minutos de antecedência oferecidos no seletor — presets, não campo livre,
/// que não tem por que digitar um número exato aqui.
const List<int> kOpcoesAntecedencia = [5, 10, 15, 20, 30, 45, 60];

/// Escolha da densidade de cor, notificações e exportar/importar backup.
///
/// A escolha de densidade é feita por miniatura da própria grade, não por
/// lista de texto: o ponto de ser opção é ver o resultado antes de aplicar.
class AparenciaScreen extends StatelessWidget {
  const AparenciaScreen({super.key});

  /// Pede a permissão de notificação (Android 13+) só quando o usuário liga
  /// o interruptor — não no início do app, sem contexto do porquê.
  Future<void> _alternarNotificacoes(BuildContext context, bool ativar) async {
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
      _avisar(
        context,
        'Sem permissão de notificação, o Android não deixa avisar.',
      );
      return;
    }

    await state.definirNotificacoesAtivas(true);
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Aparência')),
      body: LarguraMaxima(
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'DENSIDADE DE COR',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final densidade in ColorDensity.values) ...[
            _Opcao(
              densidade: densidade,
              selecionada: densidade == state.densidade,
              aoEscolher: () => state.definirDensidade(densidade),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Text(
            'Vale pro app e pro widget. A cor sempre identifica o item — '
            'a sigla continua visível em qualquer densidade.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          Text(
            'NOTIFICAÇÕES',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Avisar antes de cada horário'),
            subtitle: Text(
              'Da tabela ativa, com item preenchido, e dos eventos.',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            value: state.notificacoesAtivas,
            onChanged: (ativar) => _alternarNotificacoes(context, ativar),
          ),
          if (state.notificacoesAtivas) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(
                  child: Text('Com quanto tempo de antecedência'),
                ),
                DropdownButton<int>(
                  value: state.antecedenciaMinutos,
                  items: [
                    for (final minutos in kOpcoesAntecedencia)
                      DropdownMenuItem(value: minutos, child: Text('$minutos min')),
                  ],
                  onChanged: (minutos) {
                    if (minutos != null) {
                      state.definirAntecedenciaMinutos(minutos);
                    }
                  },
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Avisar eventos também'),
              subtitle: Text(
                'Com hora: na mesma antecedência. Dia todo: às 8h do dia.',
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
              ),
              value: state.notificarEventos,
              onChanged: state.definirNotificarEventos,
            ),
          ],
          const SizedBox(height: 28),
          Text(
            'GOOGLE AGENDA',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('Agendas do aparelho'),
            subtitle: Text(
              'As que o Android sincroniza com sua conta Google.',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AgendasScreen()),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'BACKUP',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _AcaoBackup(
            icone: Icons.upload_outlined,
            titulo: 'Exportar backup',
            descricao:
                'Salva itens, tabelas e preferências num arquivo, pra guardar '
                'ou levar pra outro aparelho.',
            aoTocar: () => _exportar(context),
          ),
          const SizedBox(height: 8),
          _AcaoBackup(
            icone: Icons.download_outlined,
            titulo: 'Importar backup',
            descricao: 'Substitui tudo que está no app pelo conteúdo do arquivo.',
            aoTocar: () => _importar(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Reinstalar o app (por cima de uma atualização, por exemplo) '
            'apaga os dados — exportar antes é a única forma de recuperar.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      ),
    );
  }
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
            _Miniatura(densidade: densidade),
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
class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.densidade});

  final ColorDensity densidade;

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
      width: 82,
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
                          height: 10,
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
