/// Primeiro dia (meia-noite) da semana de [d], com a semana começando em
/// [primeiro] — `DateTime.monday` (padrão) ou `DateTime.sunday` (tabela com
/// a semana começando no domingo, ver `Tabela.comecaNoDomingo`).
DateTime inicioDaSemana(DateTime d, [int primeiro = DateTime.monday]) =>
    DateTime(d.year, d.month, d.day - (d.weekday - primeiro) % 7);

/// Último dia da semana que começa em [primeiro]: domingo ou sábado.
int ultimoDiaDaSemana(int primeiro) => (primeiro + 5) % 7 + 1;

/// Iniciais dos dias pro cabeçalho dos calendários, na ordem da semana.
List<String> iniciaisDaSemana(int primeiro) => primeiro == DateTime.sunday
    ? const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']
    : const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
