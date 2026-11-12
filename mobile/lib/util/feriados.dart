import 'package:flutter/foundation.dart';

import '../model/tabela.dart';

/// O que um feriado embutido faz com o dia.
///
/// - [folga]: lei federal, ninguém tem aula/expediente — esmaece as aulas
///   e conta em "N feriados até o fim do ano".
/// - [pontoFacultativo]: Carnaval e Corpus Christi. Depende de onde a
///   pessoa estuda/trabalha, então cada tabela decide
///   ([Tabela.pontoFacultativoFolga]).
/// - [comemorativa]: Dia das Mães, Namorados… aparece, não esmaece nada.
enum NaturezaFeriado { folga, pontoFacultativo, comemorativa }

/// Uma data calculada pelo app, não guardada em lugar nenhum — vale pra
/// qualquer ano sem depender do Google.
@immutable
class FeriadoEmbutido {
  const FeriadoEmbutido(this.dia, this.nome, this.natureza);

  /// Meia-noite local do dia.
  final DateTime dia;
  final String nome;
  final NaturezaFeriado natureza;

  /// Folga nesta tabela? Ponto facultativo segue a escolha dela; sem tabela
  /// conta só a folga de lei.
  bool ehFolgaPara(Tabela? tabela) => switch (natureza) {
        NaturezaFeriado.folga => true,
        NaturezaFeriado.pontoFacultativo => tabela?.pontoFacultativoFolga ?? false,
        NaturezaFeriado.comemorativa => false,
      };

  @override
  bool operator ==(Object other) =>
      other is FeriadoEmbutido &&
      other.dia == dia &&
      other.nome == nome &&
      other.natureza == natureza;

  @override
  int get hashCode => Object.hash(dia, nome, natureza);

  @override
  String toString() => 'FeriadoEmbutido($dia, $nome, ${natureza.name})';
}

/// Domingo de Páscoa (calendário gregoriano), pelo algoritmo de
/// Meeus/Jones/Butcher. Base dos feriados móveis.
DateTime pascoa(int ano) {
  final a = ano % 19;
  final b = ano ~/ 100;
  final c = ano % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final mes = (h + l - 7 * m + 114) ~/ 31;
  final dia = (h + l - 7 * m + 114) % 31 + 1;
  return DateTime(ano, mes, dia);
}

/// N-ésimo domingo do mês (Mães = 2º de maio, Pais = 2º de agosto).
DateTime _domingo(int ano, int mes, int n) {
  final primeiro = DateTime(ano, mes);
  final ate = (DateTime.sunday - primeiro.weekday) % 7;
  return DateTime(ano, mes, 1 + ate + (n - 1) * 7);
}

/// Soma dias pelo calendário (não por 24h), por causa do horário de verão.
DateTime _mais(DateTime d, int dias) => DateTime(d.year, d.month, d.day + dias);

final Map<int, List<FeriadoEmbutido>> _cache = {};

/// Feriados nacionais e datas comemorativas de [ano], em ordem de data.
///
/// Folga = lei federal (Lei 662/1949, 6.802/1980 e 14.759/2023 — esta pôs
/// a Consciência Negra em 2024) + Sexta-feira Santa. Carnaval e Corpus
/// Christi não são feriado federal, são ponto facultativo. Quarta de
/// Cinzas (meio expediente) fica de fora de propósito.
List<FeriadoEmbutido> feriadosDoAno(int ano) => _cache.putIfAbsent(ano, () {
      const folga = NaturezaFeriado.folga;
      const facultativo = NaturezaFeriado.pontoFacultativo;
      const comemorativa = NaturezaFeriado.comemorativa;
      final p = pascoa(ano);
      final lista = [
        FeriadoEmbutido(DateTime(ano, 1, 1), 'Ano Novo', folga),
        FeriadoEmbutido(_mais(p, -48), 'Carnaval', facultativo),
        FeriadoEmbutido(_mais(p, -47), 'Carnaval', facultativo),
        FeriadoEmbutido(_mais(p, -2), 'Sexta-feira Santa', folga),
        FeriadoEmbutido(p, 'Páscoa', comemorativa),
        FeriadoEmbutido(DateTime(ano, 4, 21), 'Tiradentes', folga),
        FeriadoEmbutido(DateTime(ano, 5, 1), 'Dia do Trabalho', folga),
        FeriadoEmbutido(_domingo(ano, 5, 2), 'Dia das Mães', comemorativa),
        FeriadoEmbutido(_mais(p, 60), 'Corpus Christi', facultativo),
        FeriadoEmbutido(DateTime(ano, 6, 12), 'Dia dos Namorados', comemorativa),
        FeriadoEmbutido(_domingo(ano, 8, 2), 'Dia dos Pais', comemorativa),
        FeriadoEmbutido(DateTime(ano, 9, 7), 'Independência do Brasil', folga),
        FeriadoEmbutido(DateTime(ano, 10, 12), 'Nossa Senhora Aparecida', folga),
        FeriadoEmbutido(DateTime(ano, 10, 12), 'Dia das Crianças', comemorativa),
        FeriadoEmbutido(DateTime(ano, 11, 2), 'Finados', folga),
        FeriadoEmbutido(DateTime(ano, 11, 15), 'Proclamação da República', folga),
        if (ano >= 2024)
          FeriadoEmbutido(DateTime(ano, 11, 20), 'Dia da Consciência Negra', folga),
        FeriadoEmbutido(DateTime(ano, 12, 24), 'Véspera de Natal', comemorativa),
        FeriadoEmbutido(DateTime(ano, 12, 25), 'Natal', folga),
        FeriadoEmbutido(DateTime(ano, 12, 31), 'Véspera de Ano Novo', comemorativa),
      ]..sort((a, b) => a.dia.compareTo(b.dia));
      return List.unmodifiable(lista);
    });

/// Os que caem em `[de, ate)`, em ordem.
List<FeriadoEmbutido> feriadosEntre(DateTime de, DateTime ate) => [
      for (var ano = de.year; ano <= ate.year; ano++)
        for (final f in feriadosDoAno(ano))
          if (!f.dia.isBefore(DateTime(de.year, de.month, de.day)) && f.dia.isBefore(ate)) f,
    ];

/// Os embutidos do dia de [quando] (pode ter dois: Aparecida e Crianças).
List<FeriadoEmbutido> feriadosNoDia(DateTime quando) {
  final dia = DateTime(quando.year, quando.month, quando.day);
  return [for (final f in feriadosDoAno(dia.year)) if (f.dia == dia) f];
}

/// O feriado embutido que dá folga em [tabela] no dia de [quando], se
/// algum. É o que esmaece as aulas do dia e cala os avisos delas.
FeriadoEmbutido? folgaEmbutida(DateTime quando, Tabela? tabela) {
  for (final f in feriadosNoDia(quando)) {
    if (f.ehFolgaPara(tabela)) return f;
  }
  return null;
}
