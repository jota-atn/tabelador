import '../model/tabela.dart';

/// Índice do dia de hoje em [kDias] (Segunda=0..Sexta=4), ou -1 no fim de
/// semana — a grade não tem coluna pra apontar.
int indiceDeHoje([DateTime? agora]) {
  final dia = (agora ?? DateTime.now()).weekday;
  return dia <= 5 ? dia - 1 : -1;
}

/// Em qual slot de [tabela] estamos agora, ou -1 fora do expediente ou no fim
/// de semana.
///
/// Usado pela grade semanal (destaque do horário corrente) e pelo snapshot do
/// widget nativo (mesmo destaque, resolvido do lado de fora do Flutter).
int slotCorrente(Tabela tabela, [DateTime? momento]) {
  final agora = momento ?? DateTime.now();
  if (indiceDeHoje(agora) < 0) return -1;

  final minutos = agora.hour * 60 + agora.minute;
  for (var i = 0; i < tabela.qtdHorarios; i++) {
    final comeco = (tabela.horaInicial + i * tabela.intervalo) * 60;
    final fim = comeco + tabela.intervalo * 60;
    if (minutos >= comeco && minutos < fim) return i;
  }
  return -1;
}
