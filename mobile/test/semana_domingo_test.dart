import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/model/tabela.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/util/eventos_na_grade.dart';
import 'package:tabelador/util/formato_data.dart';
import 'package:tabelador/util/semana.dart';
import 'package:tabelador/util/tarefas.dart';

// 2026-11-22 é um domingo; 23 segunda; 25 quarta; 28 sábado.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('início da semana: segunda ou domingo', () {
    final domingo = DateTime(2026, 11, 22);
    final quarta = DateTime(2026, 11, 25, 15);
    expect(inicioDaSemana(domingo), DateTime(2026, 11, 16));
    expect(inicioDaSemana(domingo, DateTime.sunday), DateTime(2026, 11, 22));
    expect(inicioDaSemana(quarta, DateTime.sunday), DateTime(2026, 11, 22));
    expect(inicioDaSemana(quarta), DateTime(2026, 11, 23));
    expect(ultimoDiaDaSemana(DateTime.monday), DateTime.sunday);
    expect(ultimoDiaDaSemana(DateTime.sunday), DateTime.saturday);
    expect(iniciaisDaSemana(DateTime.sunday).first, 'D');
  });

  test('data de cada coluna nas duas convenções', () {
    expect(dataDaColuna(DateTime(2026, 11, 22), 'DOMINGO'), DateTime(2026, 11, 22));
    expect(dataDaColuna(DateTime(2026, 11, 22), 'SEGUNDA'), DateTime(2026, 11, 23));
    expect(dataDaColuna(DateTime(2026, 11, 22), 'SÁBADO'), DateTime(2026, 11, 28));
    expect(dataDaColuna(DateTime(2026, 11, 16), 'DOMINGO'), DateTime(2026, 11, 22));
    expect(dataDaColuna(DateTime(2026, 11, 16), 'SEGUNDA'), DateTime(2026, 11, 16));
  });

  test('título da semana entende o domingo como começo', () {
    final quarta = DateTime(2026, 11, 25);
    expect(tituloDaSemana(DateTime(2026, 11, 22), quarta), 'Esta semana');
    expect(tituloDaSemana(DateTime(2026, 11, 29), quarta), 'Semana que vem');
  });

  test('tabela: domingo primeiro nas colunas e o JSON guarda', () {
    final t = Tabela.nova(nome: 'Igreja', dias: ['SEGUNDA', 'DOMINGO', 'SÁBADO']);
    expect(t.dias, ['SEGUNDA', 'SÁBADO', 'DOMINGO']);
    final d = t.copyWith(comecaNoDomingo: true);
    expect(d.dias, ['DOMINGO', 'SEGUNDA', 'SÁBADO']);
    expect(d.primeiroDia, DateTime.sunday);
    final volta = Tabela.fromJson(d.toJson());
    expect(volta.comecaNoDomingo, isTrue);
    expect(volta.dias.first, 'DOMINGO');
    expect(Tabela.fromJson(t.toJson()).comecaNoDomingo, isFalse);
  });

  test('"Esta semana" de Tarefas acaba no sábado com a semana começando no domingo', () {
    final sabado = DateTime(2026, 11, 28, 10);
    final noDomingo = Evento(
      id: 't',
      titulo: 'Lavar o carro',
      inicio: DateTime(2026, 11, 29),
      diaInteiro: true,
      tipo: 'Tarefa',
    );
    final o = Ocorrencia(noDomingo, noDomingo.inicio, noDomingo.inicio);
    expect(secaoPelaData(o, sabado), SecaoTarefa.semana);
    expect(secaoPelaData(o, sabado, DateTime.sunday), SecaoTarefa.depois);
  });

  test('a semana mostrada segue a tabela ativa', () async {
    final state = AppState(feriadosEmbutidos: false);
    await state.carregar();
    final quarta = DateTime(2026, 11, 25, 9);
    final t = Tabela.nova(nome: 'Domingo').copyWith(comecaNoDomingo: true);
    await state.adicionarTabela(t);
    await state.definirTabelaAtiva(t.id);
    expect(state.primeiroDiaDaSemana, DateTime.sunday);
    expect(state.inicioMostrado(quarta), DateTime(2026, 11, 22));

    await state.definirTabelaAtiva(null);
    expect(state.inicioMostrado(quarta), DateTime(2026, 11, 23));
  });
}
