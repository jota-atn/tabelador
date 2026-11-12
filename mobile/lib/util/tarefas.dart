import '../model/evento.dart';

/// Onde uma tarefa cai na página de Tarefas, na ordem em que as seções
/// aparecem.
enum SecaoTarefa {
  atrasadas('Atrasadas'),
  hoje('Hoje'),
  semana('Esta semana'),
  depois('Mais tarde'),
  semData('Sem data'),
  concluidas('Concluídas');

  const SecaoTarefa(this.rotulo);
  final String rotulo;
}

/// Uma linha da página: a ocorrência que representa a tarefa e a seção.
class LinhaTarefa {
  const LinhaTarefa(this.ocorrencia, this.secao);

  final Ocorrencia ocorrencia;
  final SecaoTarefa secao;

  /// Identifica a linha mesmo quando a tarefa repete (uma ocorrência por
  /// vez aparece, mas a chave muda quando ela anda pra próxima).
  String get chave => '${ocorrencia.evento.id}@${ocorrencia.inicio.toIso8601String()}';
}

/// Quanto à frente procurar a próxima ocorrência pendente de uma tarefa
/// que repete.
const _horizonte = Duration(days: 400);

/// A ocorrência que representa [e] na lista: a própria tarefa (com ou sem
/// data) ou, se repete, a primeira ocorrência pendente de hoje em diante.
/// Recorrente sem nenhuma pendente no horizonte: null (some da lista).
Ocorrencia? ocorrenciaDaTarefa(Evento e, DateTime agora) {
  if (e.semData) return Ocorrencia.semData(e);
  if (e.repeticao == Repeticao.nenhuma) {
    return Ocorrencia(e, e.inicio, e.inicio.add(e.duracao));
  }
  final hoje = DateTime(agora.year, agora.month, agora.day);
  for (final o in e.ocorrenciasEntre(hoje, hoje.add(_horizonte))) {
    if (!o.feita) return o;
  }
  return null;
}

/// Em que seção a ocorrência [o] cai, sem olhar se está concluída (a
/// página usa isso pra deixar a recém-concluída riscada no lugar dela).
SecaoTarefa secaoPelaData(Ocorrencia o, DateTime agora) {
  final e = o.evento;
  if (e.semData) return SecaoTarefa.semData;
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final dia = DateTime(o.inicio.year, o.inicio.month, o.inicio.day);
  final passou = e.diaInteiro ? dia.isBefore(hoje) : o.inicio.isBefore(agora);
  if (passou) return SecaoTarefa.atrasadas;
  if (dia == hoje) return SecaoTarefa.hoje;
  // Segunda que vem, meia-noite: fim de "esta semana" (igual à tela Semana).
  final fimDaSemana = DateTime(hoje.year, hoje.month, hoje.day + (8 - hoje.weekday));
  if (dia.isBefore(fimDaSemana)) return SecaoTarefa.semana;
  return SecaoTarefa.depois;
}

/// Todas as tarefas organizadas: pendentes por data, sem data, concluídas
/// por último (mais recente primeiro). Dentro de cada seção, por data.
List<LinhaTarefa> organizarTarefas(Iterable<Evento> tarefas, DateTime agora) {
  final linhas = <LinhaTarefa>[];
  for (final e in tarefas) {
    final o = ocorrenciaDaTarefa(e, agora);
    if (o == null) continue;
    linhas.add(LinhaTarefa(o, o.feita ? SecaoTarefa.concluidas : secaoPelaData(o, agora)));
  }
  linhas.sort((a, b) {
    final s = a.secao.index.compareTo(b.secao.index);
    if (s != 0) return s;
    final c = a.ocorrencia.inicio.compareTo(b.ocorrencia.inicio);
    return a.secao == SecaoTarefa.concluidas ? -c : c;
  });
  return linhas;
}
