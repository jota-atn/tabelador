import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Uma linha do menu flutuante de um chip.
class OpcaoMenu {
  const OpcaoMenu({
    required this.rotulo,
    required this.aoEscolher,
    this.subtitulo,
    this.cor,
    this.icone,
    this.selecionada = false,
  });

  final String rotulo;

  /// Segunda linha menor (ex.: a conta dona da agenda).
  final String? subtitulo;

  /// Bolinha de cor à esquerda (cor da agenda).
  final Color? cor;
  final IconData? icone;
  final bool selecionada;
  final VoidCallback aoEscolher;
}

/// Menu flutuante **acima** de um chip (abaixo, se não couber).
///
/// Dois jeitos de usar, mesmo menu:
/// - toque: abre e fica aberto; toca numa opção, ou fora pra fechar;
/// - segurar: abre já em modo arrasto; deslizar **pra cima** destaca a
///   opção sob o dedo (com vibração) e soltar escolhe. Soltar sem destacar
///   nada deixa o menu aberto, como se tivesse tocado.
///
/// O arrasto só começa depois do toque longo ganhar o gesto, então não
/// briga com rolar ou fechar a folha.
class MenuFlutuante {
  MenuFlutuante(this.opcoes);

  final List<OpcaoMenu> opcoes;

  OverlayEntry? _entrada;
  final _destacada = ValueNotifier<int?>(null);
  List<Rect> _linhas = const [];
  Rect _caixa = Rect.zero;
  bool _arrastando = false;

  static const double _alturaLinha = 46;
  static const double _alturaComSub = 56;
  static const double _pad = 6;

  bool get aberto => _entrada != null;

  void abrir(BuildContext chipContext, {required bool arrastando}) {
    if (opcoes.isEmpty) return;
    fechar();
    final caixa = chipContext.findRenderObject()! as RenderBox;
    final chip = caixa.localToGlobal(Offset.zero) & caixa.size;
    final mq = MediaQuery.of(chipContext);
    final tela = mq.size;

    // Largura: pelo menos a do chip, nunca passando da tela (16 de margem).
    final largura = math.min(tela.width - 32, math.max(chip.width, 220.0));
    final esquerda = chip.left.clamp(16.0, math.max(16.0, tela.width - 16 - largura)).toDouble();
    final alturas = <double>[for (final o in opcoes) o.subtitulo == null ? _alturaLinha : _alturaComSub];
    final altura = alturas.fold(0.0, (a, b) => a + b) + _pad * 2;
    var topo = chip.top - 8 - altura;
    if (topo < mq.padding.top + 8) topo = chip.bottom + 8;
    _caixa = Rect.fromLTWH(esquerda, topo, largura, altura);

    final linhas = <Rect>[];
    var y = topo + _pad;
    for (final h in alturas) {
      linhas.add(Rect.fromLTWH(esquerda, y, largura, h));
      y += h;
    }
    _linhas = linhas;
    _arrastando = arrastando;
    _destacada.value = null;

    if (arrastando) unawaited(HapticFeedback.mediumImpact());
    final tema = Theme.of(chipContext);
    _entrada = OverlayEntry(
      builder: (_) => Theme(
        data: tema,
        child: _Menu(
          caixa: _caixa,
          acima: topo < chip.top,
          opcoes: opcoes,
          alturas: alturas,
          destacada: _destacada,
          aoTocarFora: fechar,
          aoEscolher: _escolher,
        ),
      ),
    );
    Overlay.of(chipContext).insert(_entrada!);
  }

  /// Dedo andando durante o arrasto.
  void mover(Offset dedo) {
    if (!aberto || !_arrastando) return;
    int? nova;
    if (dedo.dx >= _caixa.left - 32 && dedo.dx <= _caixa.right + 32) {
      for (var i = 0; i < _linhas.length; i++) {
        if (dedo.dy >= _linhas[i].top && dedo.dy < _linhas[i].bottom) nova = i;
      }
    }
    if (nova != _destacada.value) {
      _destacada.value = nova;
      if (nova != null) unawaited(HapticFeedback.selectionClick());
    }
  }

  /// Soltou o dedo depois de segurar.
  void soltar() {
    if (!aberto) return;
    final i = _destacada.value;
    _arrastando = false;
    if (i != null) _escolher(i);
  }

  void _escolher(int i) {
    fechar();
    opcoes[i].aoEscolher();
  }

  void fechar() {
    _entrada?.remove();
    _entrada = null;
    _arrastando = false;
    _destacada.value = null;
  }

  void dispose() {
    fechar();
    _destacada.dispose();
  }
}

class _Menu extends StatefulWidget {
  const _Menu({
    required this.caixa,
    required this.acima,
    required this.opcoes,
    required this.alturas,
    required this.destacada,
    required this.aoTocarFora,
    required this.aoEscolher,
  });

  final Rect caixa;
  final bool acima;
  final List<OpcaoMenu> opcoes;
  final List<double> alturas;
  final ValueNotifier<int?> destacada;
  final VoidCallback aoTocarFora;
  final ValueChanged<int> aoEscolher;

  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  )..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final curva = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.aoTocarFora,
          ),
        ),
        Positioned.fromRect(
          rect: widget.caixa,
          child: FadeTransition(
            opacity: curva,
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(curva),
              alignment: widget.acima ? Alignment.bottomLeft : Alignment.topLeft,
              child: Material(
                elevation: 8,
                color: scheme.surfaceContainerHigh,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: MenuFlutuante._pad),
                  child: ValueListenableBuilder<int?>(
                    valueListenable: widget.destacada,
                    builder: (context, destacada, _) => Column(
                      children: [
                        for (var i = 0; i < widget.opcoes.length; i++)
                          _Linha(
                            opcao: widget.opcoes[i],
                            altura: widget.alturas[i],
                            destacada: destacada == i,
                            aoTocar: () => widget.aoEscolher(i),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.opcao,
    required this.altura,
    required this.destacada,
    required this.aoTocar,
  });

  final OpcaoMenu opcao;
  final double altura;
  final bool destacada;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final o = opcao;
    final corTexto = destacada ? scheme.onPrimary : scheme.onSurface;
    final corSub = destacada ? scheme.onPrimary.withValues(alpha: 0.8) : scheme.onSurfaceVariant;
    return Material(
      color: destacada ? scheme.primary : Colors.transparent,
      child: InkWell(
        onTap: aoTocar,
        child: SizedBox(
          height: altura,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                if (o.cor != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: CircleAvatar(radius: 6, backgroundColor: o.cor),
                  )
                else if (o.icone != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(o.icone, size: 18, color: corSub),
                  ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.rotulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: o.selecionada ? FontWeight.w700 : FontWeight.w500,
                          color: corTexto,
                        ),
                      ),
                      if (o.subtitulo != null)
                        Text(
                          o.subtitulo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: corSub),
                        ),
                    ],
                  ),
                ),
                if (o.selecionada)
                  Icon(Icons.check, size: 18, color: destacada ? scheme.onPrimary : scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
