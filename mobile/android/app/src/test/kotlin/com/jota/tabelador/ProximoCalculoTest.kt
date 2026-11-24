package com.jota.tabelador

import java.time.LocalDate
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

// 2026-11-25 é uma quarta.
class ProximoCalculoTest {
    private fun slot(time: String, sigla: String, nome: String? = null, local: String? = null) = ScheduleSlot(
        time = time, sigla = sigla, tipo = "Aula", local = local, nome = nome,
        bgLight = "#FFFFFF", bgDark = "#000000", fgLight = "#000000", fgDark = "#FFFFFF",
        barLight = "#AB365C", barDark = "#FFB1C8", barWidthDp = 4,
    )

    private fun evento(date: String, inicio: Int, fim: Int, titulo: String, diaTodo: Boolean = false) = ScheduleEvent(
        date = date, allDay = diaTodo, startMin = inicio, endMin = fim, time = "", title = titulo,
        sigla = null, local = "Bloco C", barLight = "#888888", barDark = "#888888",
    )

    private val snapshot = TodayScheduleSnapshot(
        tableName = "2026.2",
        week = mapOf(
            "QUARTA" to listOf(slot("8:00-10:00", "CÁLC", "Cálculo II"), slot("10:00-12:00", "SO", "Sistemas Operacionais", "Sala 3")),
            "QUINTA" to listOf(slot("14:00-16:00", "ÁLG")),
        ),
        events = listOf(
            evento("2026-11-25", 9 * 60, 9 * 60 + 30, "Monitoria"),
            evento("2026-11-25", 0, 0, "Aniversário", diaTodo = true),
        ),
    )

    @Test
    fun emAndamentoEProximoDeHoje() {
        val p = calcularProximo(snapshot, LocalDateTime.of(2026, 11, 25, 8, 15))
        assertEquals("Cálculo II", p.agora?.titulo)
        assertEquals("Monitoria", p.proximo?.titulo)
        assertEquals(LocalDateTime.of(2026, 11, 25, 9, 0), p.mudaEm)
    }

    @Test
    fun eventoDentroDaAulaVenceNoAgora() {
        val p = calcularProximo(snapshot, LocalDateTime.of(2026, 11, 25, 9, 10))
        assertEquals("Monitoria", p.agora?.titulo)
        assertEquals("Sistemas Operacionais", p.proximo?.titulo)
        assertEquals("Sala 3", p.proximo?.local)
    }

    @Test
    fun nadaMaisHojeVaiProDiaSeguinte() {
        val p = calcularProximo(snapshot, LocalDateTime.of(2026, 11, 25, 13, 0))
        assertNull(p.agora)
        assertEquals("ÁLG", p.proximo?.titulo) // sem nome: a sigla
        assertEquals(LocalDate.of(2026, 11, 26), p.proximo?.data)
        assertEquals("Amanhã", rotuloDoDia(p.proximo!!.data, LocalDate.of(2026, 11, 25)))
    }

    @Test
    fun folgaEApagadosSaem() {
        val comFolga = snapshot.copy(
            folgas = mapOf("2026-11-25" to "Feriado"),
            apagados = mapOf("2026-11-26" to setOf("14:00-16:00")),
        )
        val p = calcularProximo(comFolga, LocalDateTime.of(2026, 11, 25, 7, 0))
        // Quarta de folga: só o evento; quinta com a aula apagada.
        assertEquals("Monitoria", p.proximo?.titulo)
        val depois = calcularProximo(comFolga, LocalDateTime.of(2026, 11, 25, 10, 0))
        assertEquals(LocalDate.of(2026, 12, 2), depois.proximo?.data) // quarta seguinte
    }

    @Test
    fun vazioNadaPelaFrente() {
        val p = calcularProximo(TodayScheduleSnapshot.vazio, LocalDateTime.of(2026, 11, 25, 7, 0))
        assertNull(p.proximo)
        assertNull(p.mudaEm)
        assertEquals("10:00", horaMin(600))
        assertEquals("8:30", horaMin(510))
    }
}
