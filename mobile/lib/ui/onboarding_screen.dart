import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../native_widget/home_widget_sync.dart';
import '../state/app_state.dart';
import 'agendas_screen.dart';
import 'aparencia_screen.dart';
import 'tabelas_screen.dart';
import 'widgets/grade_de_chips.dart';
import 'widgets/largura_maxima.dart';

/// Primeira abertura: boas-vindas, primeira tabela, Google Agenda, widget e
/// avisos. Uma vez só (flag `onboarding_visto`), "Pular" sempre à mão e
/// todo passo opcional — "Continuar" sem fazer nada só segue.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _paginas = PageController();
  int _atual = 0;

  static const _total = 4;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _ir(int pagina) {
    FocusScope.of(context).unfocus();
    unawaited(_paginas.animateToPage(
      pagina,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    ));
  }

  void _concluir() => context.read<AppState>().concluirOnboarding();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ultima = _atual == _total - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Align(
                alignment: Alignment.centerRight,
                child: ultima
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextButton(onPressed: _concluir, child: const Text('Pular')),
                      ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _paginas,
                onPageChanged: (p) => setState(() => _atual = p),
                children: const [
                  _BoasVindas(),
                  _PrimeiraTabela(),
                  _GoogleAgenda(),
                  _WidgetEAvisos(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: _atual == 0
                        ? null
                        : TextButton(onPressed: () => _ir(_atual - 1), child: const Text('Voltar')),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _total; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _atual ? 20 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _atual ? scheme.primary : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 112,
                    child: FilledButton(
                      onPressed: ultima ? _concluir : () => _ir(_atual + 1),
                      child: Text(ultima ? 'Começar' : 'Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Esqueleto comum das páginas: ícone grande, título, texto e conteúdo.
class _Pagina extends StatelessWidget {
  const _Pagina({
    required this.icone,
    required this.titulo,
    required this.texto,
    this.filhos = const [],
  });

  final IconData icone;
  final String titulo;
  final String texto;
  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LarguraMaxima(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icone, size: 32, color: scheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 20),
            Text(titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(texto, style: TextStyle(fontSize: 15, height: 1.4, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            ...filhos,
          ],
        ),
      ),
    );
  }
}

/// Linha "ícone + título + explicação", usada nas listas das páginas.
class _Recurso extends StatelessWidget {
  const _Recurso({required this.icone, required this.titulo, required this.texto});

  final IconData icone;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(texto, style: TextStyle(fontSize: 13.5, height: 1.35, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Caixa de "feito" (tabela criada, agendas conectadas).
class _Feito extends StatelessWidget {
  const _Feito({required this.texto, this.acao});

  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 14, height: 1.35, color: scheme.onSecondaryContainer),
            ),
          ),
          ?acao,
        ],
      ),
    );
  }
}

class _BoasVindas extends StatelessWidget {
  const _BoasVindas();

  @override
  Widget build(BuildContext context) {
    return const _Pagina(
      icone: Icons.calendar_view_week,
      titulo: 'Bem-vindo ao Tabelador',
      texto: 'Monte sua semana em tabelas, e seus compromissos aparecem junto.',
      filhos: [
        _Recurso(
          icone: Icons.grid_view,
          titulo: 'Tabelas da semana',
          texto: 'Aulas, trabalho, treino: cada coisa no seu horário, com cor.',
        ),
        _Recurso(
          icone: Icons.event_available,
          titulo: 'Eventos',
          texto: 'Provas, consultas, aniversários — em poucos toques, sem formulário.',
        ),
        _Recurso(
          icone: Icons.sync,
          titulo: 'Google Agenda',
          texto: 'O que já está na sua agenda (e no Classroom) aparece aqui.',
        ),
        _Recurso(
          icone: Icons.widgets_outlined,
          titulo: 'Widget e avisos',
          texto: 'O dia na tela inicial, e um aviso antes de cada horário.',
        ),
      ],
    );
  }
}

class _PrimeiraTabela extends StatelessWidget {
  const _PrimeiraTabela();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tabela = state.tabelaAtiva;
    return _Pagina(
      icone: Icons.table_chart_outlined,
      titulo: 'Sua primeira tabela',
      texto: 'Dê um nome e escolha os dias e horários. Dá pra mudar tudo depois, '
          'e ter várias tabelas (faculdade, academia...).',
      filhos: [
        if (tabela != null)
          _Feito(
            texto: '"${tabela.nome}" criada. Depois, é só tocar num horário da grade pra preencher.',
          )
        else
          ConfigTabela(aoCriar: (_) => FocusScope.of(context).unfocus()),
      ],
    );
  }
}

class _GoogleAgenda extends StatelessWidget {
  const _GoogleAgenda();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final gravaveis = state.agendasGravaveis;
    final destino = state.agendaDestinoPadrao;
    final n = state.agendas.length;

    void abrirAgendas() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AgendasScreen()),
        );

    return _Pagina(
      icone: Icons.event_note,
      titulo: 'Google Agenda',
      texto: 'O Tabelador lê e grava nas agendas que este celular já sincroniza, '
          'sem login separado. Você escolhe quais aparecem.',
      filhos: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.school_outlined, color: scheme.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Usa o Classroom? ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(
                        text: 'Cada turma é uma agenda separada, e vem desmarcada. '
                            'Marque suas turmas na lista e as atividades aparecem aqui.',
                      ),
                    ],
                    style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onTertiaryContainer),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!state.agendasConfiguradas)
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: abrirAgendas,
              icon: const Icon(Icons.link),
              label: const Text('Conectar Google Agenda'),
            ),
          )
        else ...[
          _Feito(
            texto: n == 0
                ? 'Nenhuma agenda marcada.'
                : n == 1
                    ? '1 agenda conectada.'
                    : '$n agendas conectadas.',
            acao: TextButton(onPressed: abrirAgendas, child: const Text('Mudar')),
          ),
          if (gravaveis.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Eventos que você criar ficam salvos em:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            GradeDeChips(opcoes: [
              OpcaoChip(
                rotulo: 'Só no app',
                icone: Icons.phone_android,
                selecionado: destino == null,
                aoTocar: () => state.definirAgendaDestinoPadrao(null),
              ),
              for (final e in gravaveis.entries)
                OpcaoChip(
                  rotulo: e.value.nome,
                  icone: Icons.cloud_outlined,
                  selecionado: destino == e.key,
                  aoTocar: () => state.definirAgendaDestinoPadrao(e.key),
                ),
            ]),
            const SizedBox(height: 8),
            Text(
              'Dá pra trocar em cada evento.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ],
    );
  }
}

class _WidgetEAvisos extends StatefulWidget {
  const _WidgetEAvisos();

  @override
  State<_WidgetEAvisos> createState() => _WidgetEAvisosState();
}

class _WidgetEAvisosState extends State<_WidgetEAvisos> {
  /// Nem todo launcher deixa o app pedir pra fixar o widget; sem suporte,
  /// fica só a instrução.
  bool _podeFixar = false;

  @override
  void initState() {
    super.initState();
    unawaited(_verificar());
  }

  Future<void> _verificar() async {
    try {
      final ok = await HomeWidget.isRequestPinWidgetSupported() ?? false;
      if (mounted) setState(() => _podeFixar = ok);
    } catch (_) {
      // Sem o plugin nativo (testes): só a instrução.
    }
  }

  Future<void> _fixar() async {
    try {
      await HomeWidget.requestPinWidget(androidName: kTodayScheduleWidgetReceiver);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return _Pagina(
      icone: Icons.widgets_outlined,
      titulo: 'Widget e avisos',
      texto: 'O dia de hoje na tela inicial, sem abrir o app — horários e eventos juntos.',
      filhos: [
        if (_podeFixar) ...[
          SizedBox(
            height: 50,
            child: FilledButton.tonalIcon(
              onPressed: _fixar,
              icon: const Icon(Icons.add_to_home_screen),
              label: const Text('Adicionar widget'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          _podeFixar
              ? 'Ou: segure num espaço vazio da tela inicial → Widgets → Tabelador.'
              : 'Segure num espaço vazio da tela inicial → Widgets → Tabelador.',
          style: TextStyle(fontSize: 13.5, height: 1.4, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        const Text('Avisos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Avisar antes de cada horário'),
          subtitle: Text(
            '${state.antecedenciaMinutos} min antes — muda em Aparência.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          value: state.notificacoesAtivas,
          onChanged: (v) => alternarNotificacoes(context, v),
        ),
        if (state.notificacoesAtivas)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Avisar eventos também'),
            value: state.notificarEventos,
            onChanged: state.definirNotificarEventos,
          ),
      ],
    );
  }
}
