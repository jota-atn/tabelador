import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/evento.dart';
import '../theme/tipo_evento_visual.dart';

import '../agenda/agendas_do_aparelho.dart';
import '../data/tabelador_store.dart';
import '../state/app_state.dart';
import 'widgets/largura_maxima.dart';

/// Escolha de quais agendas do aparelho (Google Agenda) aparecem no app.
///
/// Marcar uma agenda que o Android não está baixando (turma do Classroom,
/// tipicamente) liga a sincronização dela — o usuário escolhe tudo aqui, sem
/// precisar achar a chave escondida em outro app.
class AgendasScreen extends StatefulWidget {
  const AgendasScreen({super.key, this.agendas});

  /// Injetável pra teste; nulo pega do Provider (ou cria um).
  final AgendasDoAparelho? agendas;

  @override
  State<AgendasScreen> createState() => _AgendasScreenState();
}

enum _Fase { carregando, semPermissao, pronta, erro }

class _AgendasScreenState extends State<AgendasScreen> {
  late final AgendasDoAparelho _agendas = widget.agendas ??
      context.read<AgendasDoAparelho?>() ??
      AgendasDoAparelho();

  _Fase _fase = _Fase.carregando;
  List<AgendaDoAparelho> _lista = const [];
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar(pedir: false);
  }

  Future<void> _carregar({required bool pedir}) async {
    setState(() => _fase = _Fase.carregando);
    final state = context.read<AppState>();
    try {
      final ok = pedir ? await _agendas.pedirPermissao() : await _agendas.temPermissao();
      if (!ok) {
        if (mounted) setState(() => _fase = _Fase.semPermissao);
        return;
      }
      final lista = await _agendas.listar();
      // Por conta; dentro dela, a agenda principal (nome = e-mail) primeiro.
      lista.sort((a, b) {
        final c = a.conta.toLowerCase().compareTo(b.conta.toLowerCase());
        if (c != 0) return c;
        final pa = a.nome == a.conta ? 0 : 1;
        final pb = b.nome == b.conta ? 0 : 1;
        if (pa != pb) return pa - pb;
        return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      });

      // Primeira vez: já deixa marcado o que o usuário claramente usa.
      if (!state.agendasConfiguradas) {
        await state.definirAgendas({
          for (final a in lista)
            if (a.selecionadaPorPadrao) a.id: AgendaEscolhida.de(a),
        });
      } else {
        // Nome/cor podem ter mudado no Google desde a última vez.
        final atual = state.agendas;
        final atualizado = {
          for (final a in lista)
            if (atual.containsKey(a.id)) a.id: AgendaEscolhida.de(a, tipo: atual[a.id]!.tipo),
        };
        if (!_mapasIguais(atual, atualizado)) await state.definirAgendas(atualizado);
      }

      if (mounted) {
        setState(() {
          _lista = lista;
          _fase = _Fase.pronta;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = '$e';
          _fase = _Fase.erro;
        });
      }
    }
  }

  static bool _mapasIguais(Map<String, AgendaEscolhida> a, Map<String, AgendaEscolhida> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  Future<void> _alternar(AgendaDoAparelho agenda, bool marcar) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final novo = {...state.agendas};
    if (marcar) {
      novo[agenda.id] = AgendaEscolhida.de(agenda, tipo: state.agendas[agenda.id]?.tipo);
    } else {
      novo.remove(agenda.id);
    }

    if (marcar && !agenda.sincroniza) {
      try {
        await _agendas.definirSincronizacao(agenda.id, ativa: true);
        setState(() {
          _lista = [
            for (final a in _lista)
              a.id == agenda.id
                  ? AgendaDoAparelho(
                      id: a.id,
                      nome: a.nome,
                      conta: a.conta,
                      tipoConta: a.tipoConta,
                      cor: a.cor,
                      nivelAcesso: a.nivelAcesso,
                      visivel: a.visivel,
                      sincroniza: true,
                      dono: a.dono,
                    )
                  : a,
          ];
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'O Android vai baixar os eventos de "${agenda.nome}". '
              'Pode levar alguns minutos.',
            ),
          ),
        );
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Não deu pra ligar a sincronização dessa agenda.')),
        );
      }
    }
    // Desmarcar não desliga a sincronização: ela pode já estar ligada antes
    // do app (e o Google Agenda usar), então não é do app desfazer.

    await state.definirAgendas(novo);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendas do aparelho'),
        actions: [
          if (_fase == _Fase.pronta)
            IconButton(
              onPressed: () async {
                await _carregar(pedir: false);
                await state.recarregarEventosExternos();
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar',
            ),
        ],
      ),
      body: LarguraMaxima(
        child: switch (_fase) {
          _Fase.carregando => const Center(child: CircularProgressIndicator()),
          _Fase.semPermissao => _Explicacao(
              aoPermitir: () => _carregar(pedir: true),
            ),
          _Fase.erro => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não deu pra ler as agendas.\n$_erro',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ),
          _Fase.pronta => _Lista(
              agendas: _lista,
              selecionadas: state.agendas.keys.toSet(),
              tipos: {for (final e in state.agendas.entries) e.key: e.value.tipoEfetivo},
              aoMudarTipo: (a, t) =>
                  state.definirTipoDaAgenda(a.id, t == a.tipoSugerido ? null : t),
              qtdEventos: _contarEventos(state),
              aoAlternar: _alternar,
            ),
        },
      ),
    );
  }

  Map<String, int> _contarEventos(AppState state) {
    final r = <String, int>{};
    for (final e in state.eventosExternos) {
      r[e.agendaId!] = (r[e.agendaId!] ?? 0) + 1;
    }
    return r;
  }
}

class _Explicacao extends StatelessWidget {
  const _Explicacao({required this.aoPermitir});

  final VoidCallback aoPermitir;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined, size: 40, color: scheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Usar o Google Agenda do aparelho',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'O app lê as agendas que o Android já sincroniza com sua conta '
              'Google, e os eventos delas aparecem na grade, no calendário, no '
              'widget e nos avisos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: aoPermitir, child: const Text('Permitir acesso')),
          ],
        ),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({
    required this.agendas,
    required this.selecionadas,
    required this.qtdEventos,
    required this.aoAlternar,
    required this.tipos,
    required this.aoMudarTipo,
  });

  final List<AgendaDoAparelho> agendas;
  final Set<String> selecionadas;

  /// Tipo dos eventos de cada agenda marcada.
  final Map<String, TipoEvento> tipos;
  final void Function(AgendaDoAparelho, TipoEvento) aoMudarTipo;
  final Map<String, int> qtdEventos;
  final void Function(AgendaDoAparelho, bool) aoAlternar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (agendas.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma agenda no aparelho.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final filhos = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          'Marque as agendas que devem aparecer no app. Eventos criados no app '
          'podem ser salvos numa delas (escolha no próprio formulário) e vão '
          'pro Google Agenda. Cada agenda marcada tem um tipo pros eventos '
          'dela — turmas do Classroom viram Tarefa e feriados, Feriado, '
          'sozinhos.',
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
      ),
    ];
    String? contaAtual;
    for (final a in agendas) {
      if (a.conta != contaAtual) {
        contaAtual = a.conta;
        filhos.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              a.tipoConta == 'LOCAL' ? 'Neste aparelho' : a.conta,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }

      final marcada = selecionadas.contains(a.id);
      final qtd = qtdEventos[a.id];
      final subtitulo = !a.sincroniza
          ? 'Não sincroniza no aparelho — marcar liga'
          : marcada && qtd != null
              ? (qtd == 1 ? '1 evento' : '$qtd eventos')
              : marcada
                  ? 'Nenhum evento ainda'
                  : null;

      filhos.add(
        CheckboxListTile(
          value: marcada,
          onChanged: (v) => aoAlternar(a, v ?? false),
          secondary: CircleAvatar(
            radius: 7,
            backgroundColor: a.cor == null ? scheme.outline : Color(a.cor!),
          ),
          title: Text(a.nome == a.conta ? 'Principal' : a.nome),
          subtitle: subtitulo == null
              ? null
              : Text(subtitulo, style: const TextStyle(fontSize: 12)),
        ),
      );
      final tipo = tipos[a.id];
      if (marcada && tipo != null) {
        filhos.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<TipoEvento>(
                tooltip: 'Tipo dos eventos',
                initialValue: tipo,
                onSelected: (t) => aoMudarTipo(a, t),
                itemBuilder: (_) => [
                  for (final t in TipoEvento.values)
                    PopupMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Icon(iconeDoTipo(t), size: 20, color: corDoTipo(t, scheme.brightness)),
                          const SizedBox(width: 12),
                          Text(t == a.tipoSugerido ? '${t.rotulo} (sugerido)' : t.rotulo),
                        ],
                      ),
                    ),
                ],
                child: Chip(
                  avatar: Icon(iconeDoTipo(tipo), size: 18, color: corDoTipo(tipo, scheme.brightness)),
                  label: Text('Eventos como ${tipo.rotulo}'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        );
      }
    }
    filhos.add(const SizedBox(height: 32));
    return ListView(children: filhos);
  }
}
