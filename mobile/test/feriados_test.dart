import 'package:flutter_test/flutter_test.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/model/tabela.dart';
import 'package:tabelador/util/eventos_na_grade.dart';
import 'package:tabelador/util/feriados.dart';

void main() {
  group('pascoa', () {
    test('bate com datas conhecidas', () {
      expect(pascoa(2000), DateTime(2000, 4, 23));
      expect(pascoa(2019), DateTime(2019, 4, 21));
      expect(pascoa(2024), DateTime(2024, 3, 31));
      expect(pascoa(2025), DateTime(2025, 4, 20));
      expect(pascoa(2026), DateTime(2026, 4, 5));
      expect(pascoa(2027), DateTime(2027, 3, 28));
      expect(pascoa(2038), DateTime(2038, 4, 25)); // a mais tarde possível
      expect(pascoa(2285), DateTime(2285, 3, 22)); // a mais cedo possível
    });
  });

  group('feriadosDoAno', () {
    FeriadoEmbutido doNome(int ano, String nome) =>
        feriadosDoAno(ano).firstWhere((f) => f.nome == nome);

    test('móveis de 2026 pela Páscoa', () {
      final carnaval = feriadosDoAno(2026).where((f) => f.nome == 'Carnaval');
      expect(carnaval.map((f) => f.dia), [DateTime(2026, 2, 16), DateTime(2026, 2, 17)]);
      expect(doNome(2026, 'Sexta-feira Santa').dia, DateTime(2026, 4, 3));
      expect(doNome(2026, 'Corpus Christi').dia, DateTime(2026, 6, 4));
    });

    test('móveis de 2025 pela Páscoa', () {
      expect(doNome(2025, 'Sexta-feira Santa').dia, DateTime(2025, 4, 18));
      expect(doNome(2025, 'Corpus Christi').dia, DateTime(2025, 6, 19));
      expect(feriadosDoAno(2025).where((f) => f.nome == 'Carnaval').first.dia,
          DateTime(2025, 3, 3));
    });

    test('Mães e Pais no segundo domingo', () {
      expect(doNome(2026, 'Dia das Mães').dia, DateTime(2026, 5, 10));
      expect(doNome(2026, 'Dia dos Pais').dia, DateTime(2026, 8, 9));
      expect(doNome(2027, 'Dia das Mães').dia, DateTime(2027, 5, 9));
      expect(doNome(2027, 'Dia dos Pais').dia, DateTime(2027, 8, 8));
      // Mês que começa num domingo: o segundo é o dia 8.
      expect(doNome(2022, 'Dia das Mães').dia, DateTime(2022, 5, 8));
    });

    test('folgas federais: as 9 fixas mais a Sexta-feira Santa', () {
      final folgas = feriadosDoAno(2026)
          .where((f) => f.natureza == NaturezaFeriado.folga)
          .map((f) => '${f.dia.day}/${f.dia.month}');
      expect(folgas, ['1/1', '3/4', '21/4', '1/5', '7/9', '12/10', '2/11', '15/11', '20/11', '25/12']);
    });

    test('Consciência Negra só a partir de 2024', () {
      expect(feriadosDoAno(2023).any((f) => f.nome.contains('Consciência')), isFalse);
      expect(feriadosDoAno(2024).any((f) => f.nome.contains('Consciência')), isTrue);
    });

    test('em ordem de data', () {
      final dias = feriadosDoAno(2026).map((f) => f.dia).toList();
      expect(dias, [...dias]..sort());
    });
  });

  group('feriadosEntre / feriadosNoDia', () {
    test('janela atravessando o ano', () {
      final f = feriadosEntre(DateTime(2026, 12, 20), DateTime(2027, 1, 2));
      expect(f.map((e) => e.nome),
          ['Véspera de Natal', 'Natal', 'Véspera de Ano Novo', 'Ano Novo']);
    });

    test('dia com dois: Aparecida e Crianças', () {
      final f = feriadosNoDia(DateTime(2026, 10, 12, 15, 30));
      expect(f.map((e) => e.natureza),
          [NaturezaFeriado.folga, NaturezaFeriado.comemorativa]);
    });
  });

  group('folgaEmbutida', () {
    final faculdade = Tabela.nova(nome: '2026.1');
    final estagio = Tabela.nova(nome: 'Estágio').copyWith(pontoFacultativoFolga: false);

    test('folga de lei vale pra toda tabela', () {
      expect(folgaEmbutida(DateTime(2026, 11, 20, 10), estagio)?.nome,
          'Dia da Consciência Negra');
    });

    test('ponto facultativo segue a tabela', () {
      final carnaval = DateTime(2026, 2, 16, 8);
      expect(folgaEmbutida(carnaval, faculdade)?.nome, 'Carnaval');
      expect(folgaEmbutida(carnaval, estagio), isNull);
      expect(folgaEmbutida(carnaval, null), isNull);
    });

    test('comemorativa não é folga', () {
      expect(folgaEmbutida(DateTime(2026, 6, 12), faculdade), isNull);
      expect(folgaEmbutida(DateTime(2026, 6, 11), faculdade), isNull);
    });
  });

  group('Tabela.pontoFacultativoFolga', () {
    test('ligado por padrão e sobrevive ao JSON', () {
      final t = Tabela.nova(nome: 'X');
      expect(t.pontoFacultativoFolga, isTrue);
      expect(t.toJson().containsKey('pontoFacultativoFolga'), isFalse);

      final desligada = t.copyWith(pontoFacultativoFolga: false);
      final volta = Tabela.fromJson(desligada.toJson());
      expect(volta.pontoFacultativoFolga, isFalse);
      expect(Tabela.fromJson(t.toJson()).pontoFacultativoFolga, isTrue);
    });
  });

  group('folga na grade', () {
    final tabela = Tabela.nova(nome: '2026.2');
    final segunda = DateTime(2026, 11, 16);
    Ocorrencia oc(Evento e) => Ocorrencia(e, e.inicio, e.inicio);

    test('embutido esmaece o dia mesmo sem ocorrências', () {
      final semana = distribuirEventos(tabela: tabela, segunda: segunda, ocorrencias: const []);
      expect(semana.folga('SEXTA'), 'Dia da Consciência Negra');
      expect(semana.folga('SEGUNDA'), isNull);
    });

    test('feriado criado à mão: folga, a não ser que seja comemorativa', () {
      final recesso = Evento.novo(
        titulo: 'Recesso',
        inicio: DateTime(2026, 11, 17),
        diaInteiro: true,
        tipo: 'Feriado',
      );
      final festa = Evento.novo(
        titulo: 'Aniversário da cidade',
        inicio: DateTime(2026, 11, 18),
        diaInteiro: true,
        tipo: 'Feriado',
      );
      final comemorativa = Evento.fromJson({...festa.toJson(), 'comemorativa': true});
      final semana = distribuirEventos(
        tabela: tabela,
        segunda: segunda,
        ocorrencias: [oc(recesso), oc(comemorativa)],
      );
      expect(semana.folga('TERÇA'), 'Recesso');
      expect(semana.folga('QUARTA'), isNull);
      expect(Evento.fromJson(comemorativa.toJson()).comemorativa, isTrue);
    });

    test('feriado do Google: só esmaece se marcado como folga', () {
      final bruto = Evento(
        id: 'g',
        titulo: 'Aniversário da cidade',
        inicio: DateTime(2026, 11, 19),
        diaInteiro: true,
        agendaId: 'feriados',
      );
      final comemorativo = bruto.decorado(tipo: 'Feriado', feito: false, comemorativa: true);
      final folga = bruto.decorado(tipo: 'Feriado', feito: false);
      final dia = DateTime(2026, 11, 19);
      expect(folgaNoDia(dia, tabela, [oc(comemorativo)]), isNull);
      expect(folgaNoDia(dia, tabela, [oc(folga)]), 'Aniversário da cidade');
    });

    test('embutido vira evento só leitura com a natureza nas notas', () {
      final e = feriadosNoDia(DateTime(2026, 2, 16)).single.comoEvento();
      expect(e.embutido, isTrue);
      expect(e.externo, isTrue);
      expect(e.notas, 'Ponto facultativo');
      expect(ehFolga(e, tabela), isTrue);
      expect(ehFolga(e, tabela.copyWith(pontoFacultativoFolga: false)), isFalse);
      expect(feriadoEmbutidoDe(e)?.nome, 'Carnaval');
    });
  });
}
