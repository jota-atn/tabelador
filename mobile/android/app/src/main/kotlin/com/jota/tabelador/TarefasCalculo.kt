package com.jota.tabelador

import java.time.LocalDate
import java.time.LocalDateTime

/** Seções do widget de Tarefas, na ordem da página do app. */
enum class SecaoWidget(val rotulo: String) {
    ATRASADAS("Atrasadas"),
    HOJE("Hoje"),
    SEMANA("Esta semana"),
    DEPOIS("Mais tarde"),
    SEM_DATA("Sem data"),
}

/**
 * Mesma regra de `secaoPelaData` (lib/util/tarefas.dart), recalculada a
 * cada redesenho: tarefa de ontem vira "Atrasadas" sem o app rodar.
 */
fun secaoDaTarefa(t: ScheduleTask, agora: LocalDateTime, primeiroDia: Int): SecaoWidget {
    val data = t.date?.let { runCatching { LocalDate.parse(it) }.getOrNull() } ?: return SecaoWidget.SEM_DATA
    val hoje = agora.toLocalDate()
    val passou = if (t.startMin == null) {
        data.isBefore(hoje)
    } else {
        data.atStartOfDay().plusMinutes(t.startMin.toLong()).isBefore(agora)
    }
    if (passou) return SecaoWidget.ATRASADAS
    if (data == hoje) return SecaoWidget.HOJE
    val inicioDaSemana = hoje.minusDays(((hoje.dayOfWeek.value - primeiroDia + 7) % 7).toLong())
    return if (data.isBefore(inicioDaSemana.plusDays(7))) SecaoWidget.SEMANA else SecaoWidget.DEPOIS
}

/** Tarefas que o widget mostra, agrupadas por seção (ordem do app dentro
 *  de cada uma), sem as já [feitas] no widget. */
fun organizarNoWidget(
    tarefas: List<ScheduleTask>,
    agora: LocalDateTime,
    primeiroDia: Int,
    feitas: Set<String>,
): List<Pair<SecaoWidget, List<ScheduleTask>>> =
    tarefas.filter { it.key !in feitas }
        .groupBy { secaoDaTarefa(it, agora, primeiroDia) }
        .toSortedMap()
        .map { (secao, lista) -> secao to lista }

private val DIAS_CURTOS = listOf("seg", "ter", "qua", "qui", "sex", "sáb", "dom")

/** Linha de baixo de uma tarefa: "ontem", "qui 26", "14:30", "12/12 · 9:00". */
fun quandoDaTarefa(t: ScheduleTask, secao: SecaoWidget, hoje: LocalDate): String? {
    val data = t.date?.let { runCatching { LocalDate.parse(it) }.getOrNull() } ?: return null
    val hora = t.startMin?.let { horaMin(it) }
    val dia = when {
        data == hoje -> null
        data == hoje.minusDays(1) -> "ontem"
        data == hoje.plusDays(1) -> "amanhã"
        secao == SecaoWidget.SEMANA -> "${DIAS_CURTOS[data.dayOfWeek.value - 1]} ${data.dayOfMonth}"
        else -> "%d/%d".format(data.dayOfMonth, data.monthValue)
    }
    return listOfNotNull(dia, hora).joinToString(" · ").ifEmpty { null }
}
