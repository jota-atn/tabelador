import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabelador/model/item.dart';
import 'package:tabelador/model/tabela.dart';
import 'package:tabelador/state/app_state.dart';
import 'package:tabelador/theme/color_density.dart';
import 'package:tabelador/theme/item_palette.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> novoEstado() async {
    final state = AppState();
    await state.carregar();
    return state;
  }

  test('estado vazio abre sem tabela ativa e na densidade padrão', () async {
    final state = await novoEstado();

    expect(state.carregado, isTrue);
    expect(state.itens, isEmpty);
    expect(state.tabelas, isEmpty);
    expect(state.tabelaAtiva, isNull);
    expect(state.densidade, ColorDensity.suave);
  });

  test('a primeira tabela criada vira a ativa sozinha', () async {
    final state = await novoEstado();
    final t = Tabela.nova(nome: '2026.1');
    await state.adicionarTabela(t);

    expect(state.tabelaAtiva?.id, t.id);

    // A segunda não rouba o posto.
    final outra = Tabela.nova(nome: '2026.2');
    await state.adicionarTabela(outra);
    expect(state.tabelaAtiva?.id, t.id);
  });

  test('tudo sobrevive a fechar e reabrir o app', () async {
    final state = await novoEstado();

    final item = Item.novo(
      nome: 'Cálculo II',
      sigla: 'CÁLC II',
      tipo: 'Aula',
      cor: ItemColor.oceano,
    );
    await state.adicionarItem(item);

    final tabela = Tabela.nova(nome: '2026.1');
    await state.adicionarTabela(tabela);
    await state.definirCelula(tabela.id, 'QUARTA', 1, item.id);
    await state.definirDensidade(ColorDensity.solido);

    // Instância nova lendo do mesmo disco.
    final recarregado = await novoEstado();

    expect(recarregado.itens.single.sigla, 'CÁLC II');
    expect(recarregado.itens.single.cor, ItemColor.oceano);
    expect(recarregado.tabelas.single.celula('QUARTA', 1), item.id);
    expect(recarregado.tabelaAtiva?.id, tabela.id);
    expect(recarregado.densidade, ColorDensity.solido);
  });

  test('notificações desligadas e 15 min de antecedência por padrão',
      () async {
    final state = await novoEstado();
    expect(state.notificacoesAtivas, isFalse);
    expect(state.antecedenciaMinutos, 15);
  });

  test('preferência de notificação sobrevive a fechar e reabrir', () async {
    final state = await novoEstado();
    await state.definirNotificacoesAtivas(true);
    await state.definirAntecedenciaMinutos(45);

    final recarregado = await novoEstado();
    expect(recarregado.notificacoesAtivas, isTrue);
    expect(recarregado.antecedenciaMinutos, 45);
  });

  test('apagar um item limpa as células que apontavam pra ele', () async {
    final state = await novoEstado();

    final item = Item.novo(nome: 'Monitoria', sigla: 'MONIT');
    await state.adicionarItem(item);

    final a = Tabela.nova(nome: '2026.1');
    final b = Tabela.nova(nome: '2026.2');
    await state.adicionarTabela(a);
    await state.adicionarTabela(b);
    await state.definirCelula(a.id, 'SEGUNDA', 0, item.id);
    await state.definirCelula(a.id, 'QUARTA', 0, item.id);
    await state.definirCelula(b.id, 'SEXTA', 2, item.id);

    // O aviso que a tela mostra antes de confirmar.
    expect(state.usosDoItem(item.id), 3);

    await state.removerItem(item.id);

    expect(state.itens, isEmpty);
    expect(state.usosDoItem(item.id), 0);
    for (final t in state.tabelas) {
      expect(t.celulas.values.expand((l) => l).every((c) => c == null), isTrue);
    }
  });

  test('apagar a tabela ativa promove outra', () async {
    final state = await novoEstado();
    final a = Tabela.nova(nome: 'A');
    final b = Tabela.nova(nome: 'B');
    await state.adicionarTabela(a);
    await state.adicionarTabela(b);

    await state.removerTabela(a.id);

    expect(state.tabelaAtiva?.id, b.id);

    await state.removerTabela(b.id);
    expect(state.tabelaAtiva, isNull);
  });

  test('duplicar copia a grade sem ligar as duas tabelas', () async {
    final state = await novoEstado();
    final origem = Tabela.nova(nome: '2026.1', horaInicial: 7, intervalo: 1);
    await state.adicionarTabela(origem);
    await state.definirCelula(origem.id, 'TERÇA', 2, 'item-x');

    final copia = await state.duplicarTabela(origem.id, '2026.2');

    expect(copia, isNotNull);
    expect(copia!.id, isNot(origem.id));
    expect(copia.nome, '2026.2');
    expect(copia.horaInicial, 7);
    expect(copia.celula('TERÇA', 2), 'item-x');

    // Mexer na cópia não mexe na origem.
    await state.definirCelula(copia.id, 'TERÇA', 2, null);
    final aindaOrigem = state.tabelas.firstWhere((t) => t.id == origem.id);
    expect(aindaOrigem.celula('TERÇA', 2), 'item-x');
  });

  test('duplicar mantém os dias e a escolha de ponto facultativo', () async {
    final state = await novoEstado();
    final origem = Tabela.nova(nome: 'Academia', dias: ['TERÇA', 'SÁBADO'])
        .copyWith(pontoFacultativoFolga: false);
    await state.adicionarTabela(origem);
    await state.definirCelula(origem.id, 'SÁBADO', 0, 'item-x');

    final copia = (await state.duplicarTabela(origem.id, 'Academia 2'))!;

    expect(copia.dias, ['TERÇA', 'SÁBADO']);
    expect(copia.celula('SÁBADO', 0), 'item-x');
    expect(copia.pontoFacultativoFolga, isFalse);
  });

  test('id ativo apontando pra tabela inexistente cai na primeira', () async {
    final state = await novoEstado();
    final t = Tabela.nova(nome: 'Única');
    await state.adicionarTabela(t);
    await state.definirTabelaAtiva('id-que-nao-existe');

    final recarregado = await novoEstado();
    expect(recarregado.tabelaAtiva?.id, t.id);
  });

  test('JSON corrompido no disco não impede o app de abrir', () async {
    SharedPreferences.setMockInitialValues({
      'items_json': '{isso não é json válido',
      'tables_json': '[[[',
    });

    final state = await novoEstado();

    expect(state.carregado, isTrue);
    expect(state.itens, isEmpty);
    expect(state.tabelas, isEmpty);
  });

  test('tiposConhecidos alimenta o autocomplete sem repetir nem vazio', () async {
    final state = await novoEstado();
    await state.adicionarItem(Item.novo(nome: 'a', sigla: 'a', tipo: 'Aula'));
    await state.adicionarItem(Item.novo(nome: 'b', sigla: 'b', tipo: 'Aula'));
    await state.adicionarItem(
      Item.novo(nome: 'c', sigla: 'c', tipo: 'Monitoria'),
    );
    await state.adicionarItem(Item.novo(nome: 'd', sigla: 'd', tipo: '  '));

    expect(state.tiposConhecidos, ['Aula', 'Monitoria']);
  });

  test('backup: exportar e importar recupera tudo', () async {
    final origem = await novoEstado();
    final item = Item.novo(
      nome: 'Cálculo II',
      sigla: 'CÁLC II',
      tipo: 'Aula',
      cor: ItemColor.oceano,
    );
    await origem.adicionarItem(item);
    final tabela = Tabela.nova(nome: '2026.1');
    await origem.adicionarTabela(tabela);
    await origem.definirCelula(tabela.id, 'QUARTA', 1, item.id);
    await origem.definirDensidade(ColorDensity.solido);
    await origem.definirNotificacoesAtivas(true);
    await origem.definirAntecedenciaMinutos(30);

    final backup = origem.paraBackup();

    // Destino começa vazio, com dado próprio que o import deve substituir.
    final destino = await novoEstado();
    await destino.adicionarItem(Item.novo(nome: 'lixo', sigla: 'LIXO'));
    await destino.restaurarBackup(backup);

    expect(destino.itens.single.sigla, 'CÁLC II');
    expect(destino.itens.single.cor, ItemColor.oceano);
    expect(destino.tabelas.single.celula('QUARTA', 1), item.id);
    expect(destino.tabelaAtiva?.nome, '2026.1');
    expect(destino.densidade, ColorDensity.solido);
    expect(destino.notificacoesAtivas, isTrue);
    expect(destino.antecedenciaMinutos, 30);

    // E persiste de verdade, não só em memória.
    final recarregado = await novoEstado();
    expect(recarregado.itens.single.sigla, 'CÁLC II');
  });

  test('backup: formato inválido lança em vez de corromper o estado',
      () async {
    final state = await novoEstado();
    await state.adicionarItem(Item.novo(nome: 'x', sigla: 'x'));

    await expectLater(
      () => state.restaurarBackup({'nada a ver': true}),
      throwsA(anything),
    );

    // Estado anterior intacto.
    expect(state.itens.single.nome, 'x');
  });

  test('backup: tabela ativa que não existe no arquivo cai na primeira',
      () async {
    final state = await novoEstado();
    final t = Tabela.nova(nome: 'Única');

    await state.restaurarBackup({
      'itens': [],
      'tabelas': [t.toJson()],
      'tabelaAtivaId': 'id-que-nao-existe',
      'densidade': 'suave',
    });

    expect(state.tabelaAtiva?.id, t.id);
  });

  test('notifica ouvintes quando algo muda', () async {
    final state = await novoEstado();
    var avisos = 0;
    state.addListener(() => avisos++);

    await state.adicionarItem(Item.novo(nome: 'x', sigla: 'x'));
    await state.definirDensidade(ColorDensity.discreto);
    // Densidade repetida não deve notificar de novo.
    await state.definirDensidade(ColorDensity.discreto);

    expect(avisos, 2);
  });
}
