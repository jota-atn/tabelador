package com.jota.tabelador

import java.time.LocalDate
import java.time.LocalDateTime

/** Algo com hora marcada: um horário da tabela ou um evento. */
data class Momento(
    val titulo: String,
    val tipo: String?,
    val local: String?,
    val data: LocalDate,
    val inicioMin: Int,
    val fimMin: Int,
    val barLight: String,
    val barDark: String,
) {
    val inicio: LocalDateTime get() = data.atStartOfDay().plusMinutes(inicioMin.toLong())
    val fim: LocalDateTime get() = data.atStartOfDay().plusMinutes(fimMin.toLong())
}

/**
 * O que o widget Próximo mostra: o que está acontecendo [agora] (se houver)
 * e o [proximo] a começar. [mudaEm] é quando isso muda (algo começa ou
 * termina) — o widget agenda um redesenho pra essa hora.
 */
data class Proximo(val agora: Momento?, val proximo: Momento?, val mudaEm: LocalDateTime?)

private val NOMES_DIA = listOf("SEGUNDA", "TERÇA", "QUARTA", "QUINTA", "SEXTA", "SÁBADO", "DOMINGO")

/** Dias olhados pra frente: o snapshot leva hoje + 7. */
private const val DIAS_A_FRENTE = 7

/** "8:00" ou "8:30" → minutos desde meia-noite. */
private fun minutos(hm: String): Int? {
    val partes = hm.trim().split(':')
    val h = partes.getOrNull(0)?.trim()?.toIntOrNull() ?: return null
    val m = partes.getOrNull(1)?.trim()?.toIntOrNull() ?: 0
    return h * 60 + m
}

/** Horários e eventos (com hora) de [dia], já sem folga e sem os apagados. */
fun momentosDoDia(snapshot: TodayScheduleSnapshot, dia: LocalDate): List<Momento> {
    val iso = dia.toString()
    val slots = if (snapshot.folgas.containsKey(iso)) {
        emptyList()
    } else {
        val apagados = snapshot.apagados[iso].orEmpty()
        snapshot.week[NOMES_DIA[dia.dayOfWeek.value - 1]].orEmpty()
            .filter { it.time !in apagados }
            .mapNotNull { s ->
                val inicio = minutos(s.time.substringBefore('-')) ?: return@mapNotNull null
                val fim = minutos(s.time.substringAfter('-')) ?: return@mapNotNull null
                Momento(
                    titulo = s.nome?.takeIf { it.isNotBlank() } ?: s.sigla,
                    tipo = s.tipo.takeIf { it.isNotBlank() },
                    local = s.local,
                    data = dia,
                    inicioMin = inicio,
                    fimMin = fim,
                    barLight = s.barLight,
                    barDark = s.barDark,
                )
            }
    }
    val eventos = snapshot.events
        .filter { it.date == iso && !it.allDay }
        .map { e ->
            Momento(
                titulo = e.title,
                tipo = null,
                local = e.local,
                data = dia,
                inicioMin = e.startMin,
                fimMin = maxOf(e.endMin, e.startMin),
                barLight = e.barLight,
                barDark = e.barDark,
            )
        }
    // Empate na hora: o horário da tabela antes do evento, como no widget Hoje.
    return (slots + eventos).sortedBy { it.inicioMin }
}

fun calcularProximo(snapshot: TodayScheduleSnapshot, agora: LocalDateTime): Proximo {
    val hoje = agora.toLocalDate()
    val deHoje = momentosDoDia(snapshot, hoje)
    // Em andamento: o que começou por último (aula dentro da qual cai um
    // evento mostra o evento).
    val emAndamento = deHoje.filter { !it.inicio.isAfter(agora) && it.fim.isAfter(agora) }.maxByOrNull { it.inicioMin }
    var proximo: Momento? = null
    for (k in 0..DIAS_A_FRENTE) {
        val dia = hoje.plusDays(k.toLong())
        val lista = if (k == 0) deHoje else momentosDoDia(snapshot, dia)
        proximo = lista.firstOrNull { it.inicio.isAfter(agora) }
        if (proximo != null) break
    }
    val mudaEm = listOfNotNull(emAndamento?.fim, proximo?.inicio).minOrNull()
    return Proximo(emAndamento, proximo, mudaEm)
}

/** "10:00" ou "8:30". */
fun horaMin(min: Int): String = "%d:%02d".format(min / 60, min % 60)

/** "Hoje", "Amanhã" ou o dia da semana ("Sexta"). */
fun rotuloDoDia(dia: LocalDate, hoje: LocalDate): String = when (dia) {
    hoje -> "Hoje"
    hoje.plusDays(1) -> "Amanhã"
    else -> NOMES_DIA[dia.dayOfWeek.value - 1].lowercase().replaceFirstChar { it.uppercase() }
}
