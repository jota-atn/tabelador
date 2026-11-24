import '../model/evento.dart';
import '../model/item.dart';
import '../model/nota.dart';
import '../model/presente.dart';

/// Prefixo dos ids dos eventos de exemplo — é o que deixa removê-los sem
/// tocar em nada do usuário.
const kPrefixoExemplo = 'exemplo:';

bool ehExemplo(Evento e) => e.id.startsWith(kPrefixoExemplo);

/// Eventos de exemplo pra ver a aba Eventos cheia: todos os tipos, tarefas
/// em todas as seções (atrasada, hoje, semana, depois, sem data, concluída,
/// recorrente), aniversários no mês e no seguinte. Datas relativas a
/// [agora]. Provas vinculadas aos primeiros [itens], se houver.
List<Evento> eventosDeExemplo(DateTime agora, {List<Item> itens = const []}) {
  final hoje = DateTime(agora.year, agora.month, agora.day);
  DateTime dia(int d, [int h = 0, int m = 0]) => DateTime(hoje.year, hoje.month, hoje.day + d, h, m);
  var n = 0;

  Evento ev(
    String titulo,
    TipoEvento tipo,
    DateTime inicio, {
    int? minutos,
    bool diaTodo = false,
    Repeticao repeticao = Repeticao.nenhuma,
    String? local,
    String? notas,
    String? itemId,
    bool semData = false,
    bool feito = false,
    DateTime? ate,
    Prioridade prioridade = Prioridade.normal,
  }) =>
      Evento(
        id: '$kPrefixoExemplo${n++}',
        titulo: titulo,
        inicio: inicio,
        fim: ate ?? (diaTodo || minutos == null ? null : inicio.add(Duration(minutes: minutos))),
        diaInteiro: diaTodo || semData,
        tipo: tipo.rotulo,
        repeticao: repeticao,
        local: local,
        notas: notas,
        itemId: itemId,
        semData: semData,
        feito: feito,
        prioridade: prioridade,
      );

  final item1 = itens.isNotEmpty ? itens[0] : null;
  final item2 = itens.length > 1 ? itens[1] : item1;
  final mesQueVem = DateTime(hoje.year, hoje.month + 1);
  final aniversarioPassado = hoje.day > 3 ? DateTime(hoje.year, hoje.month, 2) : dia(-1);

  return [
    // ----------------------------------------------------------- tarefas
    ev('Entregar relatório', TipoEvento.tarefa, dia(-2), diaTodo: true, itemId: item1?.id),
    ev('Pagar boleto da internet', TipoEvento.tarefa, dia(0), diaTodo: true, prioridade: Prioridade.alta),
    ev('Responder e-mail do orientador', TipoEvento.tarefa, dia(0, 18), minutos: 0),
    ev('Lista de exercícios 4', TipoEvento.tarefa, dia(3), diaTodo: true, itemId: item2?.id),
    ev('Levar o lixo reciclável', TipoEvento.tarefa, dia(1), diaTodo: true, repeticao: Repeticao.semanal),
    ev('Renovar a CNH', TipoEvento.tarefa, dia(20), diaTodo: true, prioridade: Prioridade.alta),
    ev('Trocar a lâmpada do banheiro', TipoEvento.tarefa, hoje, semData: true, prioridade: Prioridade.baixa),
    ev('Estudar pra prova', TipoEvento.tarefa, dia(1), diaTodo: true, itemId: item1?.id),
    ev('Ler o artigo que o grupo mandou', TipoEvento.tarefa, hoje, semData: true),
    ev('Comprar ração', TipoEvento.tarefa, dia(-1), diaTodo: true, feito: true),

    // ------------------------------------------------------------ provas
    ev('Prova 2${item1 == null ? '' : ' · ${item1.sigla}'}', TipoEvento.prova, dia(2, 10),
        minutos: 120, itemId: item1?.id, local: item1?.local, notas: 'Capítulos 4 a 6'),
    ev('Prova final${item2 == null ? '' : ' · ${item2.sigla}'}', TipoEvento.prova, dia(16, 8),
        minutos: 120, itemId: item2?.id),
    ev('Simulado', TipoEvento.prova, dia(35, 14), minutos: 180),
    // Passada, com nota lançada.
    ev('Prova 1${item1 == null ? '' : ' · ${item1.sigla}'}', TipoEvento.prova, dia(-12, 10),
            minutos: 120, itemId: item1?.id)
        .comNota(dia(-12, 10), const Nota(8.5, 10)),

    // ------------------------------------------------------- compromissos
    ev('Almoço com a Ana', TipoEvento.compromisso, dia(1, 12, 30), minutos: 90, local: 'Restaurante do centro'),
    ev('Cortar o cabelo', TipoEvento.compromisso, dia(5, 17), minutos: 60, local: 'Av. Paulista, 1000'),
    ev('Monitoria${item2 == null ? '' : ' · ${item2.sigla}'}', TipoEvento.compromisso, dia(3, 14),
        minutos: 60, itemId: item2?.id),
    ev('Show no sábado', TipoEvento.compromisso, dia(9, 21), minutos: 180),

    // ---------------------------------------------------------- consultas
    ev('Dentista', TipoEvento.consulta, dia(4, 9), minutos: 60, local: 'Rua das Flores, 120 — sala 305'),
    ev('Retorno dermatologista', TipoEvento.consulta, dia(24, 15, 30), minutos: 30),

    // ----------------------------------------------------------- reuniões
    ev('Reunião do grupo de pesquisa', TipoEvento.reuniao, dia(1, 16), minutos: 60,
        repeticao: Repeticao.semanal, local: 'meet.google.com/abc-defg-hij'),
    ev('Planejamento do projeto', TipoEvento.reuniao, dia(6, 10), minutos: 90),
    // Eventos separados com mesmo nome, dia da semana e hora: viram série
    // na página do tipo, cada um com o seu link.
    for (final (d, link) in [(2, 'meet.google.com/caa-aaaa-aaa'), (9, 'meet.google.com/cbb-bbbb-bbb'), (16, 'meet.google.com/ccc-cccc-ccc')])
      ev('Reunião do centro acadêmico', TipoEvento.reuniao, dia(d, 19), minutos: 60, notas: 'Link: https://$link'),

    // ------------------------------------------------------------ viagens
    // Ida e volta com hora.
    ev('Viagem pra casa dos pais', TipoEvento.viagem, dia(12, 8), ate: dia(15, 18)),

    // -------------------------------------------------------- aniversários
    ev('Aniversário da Júlia', TipoEvento.aniversario, aniversarioPassado, diaTodo: true,
        repeticao: Repeticao.anual),
    ev('Aniversário do Pedro', TipoEvento.aniversario, dia(8), diaTodo: true, repeticao: Repeticao.anual)
        .comPresente(dia(8), const Presente('Fone de ouvido')),
    ev('Aniversário da vó', TipoEvento.aniversario, mesQueVem, diaTodo: true, repeticao: Repeticao.anual)
        .comPresente(mesQueVem, const Presente('Manta de tricô', comprado: true)),

    // ------------------------------------------------------------ feriado
    ev('Recesso da universidade', TipoEvento.feriado, dia(7), diaTodo: true),

    // ------------------------------------------------------------- outros
    ev('Fatura do cartão', TipoEvento.outro, dia(10), diaTodo: true, repeticao: Repeticao.mensal),
    // Dia todo, três dias.
    ev('Semana acadêmica', TipoEvento.outro, dia(18), diaTodo: true, ate: dia(20)),
  ];
}
