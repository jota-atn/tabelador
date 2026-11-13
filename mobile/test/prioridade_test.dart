import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/data/tabelador_store.dart';
import 'package:tabelador/model/evento.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/util/tarefas.dart';

Evento _tarefa(String titulo, DateTime quando, {Prioridade p = Prioridade.normal}) => Evento(
      id: titulo,
      titulo: titulo,
      inicio: quando,
      diaInteiro: true,
      tipo: 'Tarefa',
      prioridade: p,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('JSON: normal não é gravado; alta e baixa voltam', () {
    final normal = _tarefa('a', DateTime(2026, 11, 13));
    expect(normal.toJson().containsKey('prioridade'), isFalse);
    final alta = _tarefa('b', DateTime(2026, 11, 13), p: Prioridade.alta);
    expect(Evento.fromJson(alta.toJson()).prioridade, Prioridade.alta);
    expect(Evento.fromJson(alta.toJson()), alta);
    expect(Prioridade.fromKey('xyz'), Prioridade.normal);
  });

  test('na seção: alta primeiro, baixa por último, depois a data', () {
    final agora = DateTime(2026, 11, 12, 9); // quinta
    final linhas = organizarTarefas([
      _tarefa('normal cedo', DateTime(2026, 11, 13)),
      _tarefa('baixa cedo', DateTime(2026, 11, 13), p: Prioridade.baixa),
      _tarefa('alta tarde', DateTime(2026, 11, 15), p: Prioridade.alta),
      _tarefa('normal tarde', DateTime(2026, 11, 14)),
      _tarefa('hoje baixa', DateTime(2026, 11, 12), p: Prioridade.baixa),
    ], agora);
    expect([for (final l in linhas) l.ocorrencia.evento.titulo], [
      'hoje baixa', // Hoje vem antes de Esta semana, seja qual for a prioridade
      'alta tarde',
      'normal cedo',
      'normal tarde',
      'baixa cedo',
    ]);
  });

  test('externo: guarda, decora e entra no backup', () async {
    expect(decodificarPrioridadesExternas('{"g:1:2":"alta","g:3:4":"normal"}'), {'g:1:2': Prioridade.alta});
    expect(codificarPrioridadesExternas({'x': Prioridade.normal, 'y': Prioridade.baixa}), {'y': 'baixa'});

    final state = AppState(feriadosEmbutidos: false);
    await state.carregar();
    await state.definirPrioridadeExterna('g:1:2', Prioridade.alta);
    final backup = state.paraBackup();
    expect((backup['externos'] as Map)['prioridades'], {'g:1:2': 'alta'});

    final outro = AppState(feriadosEmbutidos: false);
    await outro.carregar();
    expect(outro.paraBackup()['externos']['prioridades'], {'g:1:2': 'alta'});
  });
}
