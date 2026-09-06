import '../model/tabela.dart';

/// Nome do dia de hoje pelo `DateTime.weekday` (1=segunda..7=domingo) — cobre
/// a semana inteira, ao contrário de uma tabela específica, que pode não ter
/// coluna pra ele.
String nomeDoDia([DateTime? agora]) =>
    kTodosDias[(agora ?? DateTime.now()).weekday - 1];

/// Índice de hoje dentro de [dias] (os dias de uma tabela), ou -1 se hoje não
/// é um dos dias dela.
int indiceDeHoje(List<String> dias, [DateTime? agora]) =>
    dias.indexOf(nomeDoDia(agora));

/// Em qual slot de [tabela] estamos agora, ou -1 fora do expediente ou num
/// dia que a tabela não tem.
///
/// Usado pela grade semanal (destaque do horário corrente) e pelo snapshot do
/// widget nativo (mesmo destaque, resolvido do lado de fora do Flutter).
int slotCorrente(Tabela tabela, [DateTime? momento]) {
  final agora = momento ?? DateTime.now();
  if (indiceDeHoje(tabela.dias, agora) < 0) return -1;

  final minutos = agora.hour * 60 + agora.minute;
  for (var i = 0; i < tabela.qtdHorarios; i++) {
    final comeco = (tabela.horaInicial + i * tabela.intervalo) * 60;
    final fim = comeco + tabela.intervalo * 60;
    if (minutos >= comeco && minutos < fim) return i;
  }
  return -1;
}
