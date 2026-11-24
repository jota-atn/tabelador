package com.jota.tabelador

import java.time.LocalDate
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

// 2026-11-25 é uma quarta.
class TarefasCalculoTest {
    private fun t(key: String, date: String?, startMin: Int? = null) =
        ScheduleTask(key, key, date, startMin, false, "#888888", "#888888")

    private val agora = LocalDateTime.of(2026, 11, 25, 10, 0)

    @Test
    fun secoesComoNoApp() {
        assertEquals(SecaoWidget.ATRASADAS, secaoDaTarefa(t("a", "2026-11-24"), agora, 1))
        assertEquals(SecaoWidget.ATRASADAS, secaoDaTarefa(t("b", "2026-11-25", 9 * 60), agora, 1))
        assertEquals(SecaoWidget.HOJE, secaoDaTarefa(t("c", "2026-11-25"), agora, 1))
        assertEquals(SecaoWidget.HOJE, secaoDaTarefa(t("d", "2026-11-25", 11 * 60), agora, 1))
        assertEquals(SecaoWidget.SEMANA, secaoDaTarefa(t("e", "2026-11-29"), agora, 1)) // domingo
        assertEquals(SecaoWidget.DEPOIS, secaoDaTarefa(t("e", "2026-11-29"), agora, 7)) // semana de domingo
        assertEquals(SecaoWidget.SEM_DATA, secaoDaTarefa(t("f", null), agora, 1))
    }

    @Test
    fun agrupaEscondeFeitas() {
        val grupos = organizarNoWidget(
            listOf(t("hoje", "2026-11-25"), t("velha", "2026-11-20"), t("feita", "2026-11-25"), t("solta", null)),
            agora, 1, setOf("feita"),
        )
        assertEquals(listOf(SecaoWidget.ATRASADAS, SecaoWidget.HOJE, SecaoWidget.SEM_DATA), grupos.map { it.first })
        assertEquals(listOf("hoje"), grupos[1].second.map { it.key })
    }

    @Test
    fun quando() {
        val hoje = LocalDate.of(2026, 11, 25)
        assertEquals("ontem", quandoDaTarefa(t("a", "2026-11-24"), SecaoWidget.ATRASADAS, hoje))
        assertEquals("14:00", quandoDaTarefa(t("b", "2026-11-25", 14 * 60), SecaoWidget.HOJE, hoje))
        assertEquals(null, quandoDaTarefa(t("c", "2026-11-25"), SecaoWidget.HOJE, hoje))
        assertEquals("amanhã", quandoDaTarefa(t("d", "2026-11-26"), SecaoWidget.SEMANA, hoje))
        assertEquals("sex 27 · 9:00", quandoDaTarefa(t("e", "2026-11-27", 9 * 60), SecaoWidget.SEMANA, hoje))
        assertEquals("12/12", quandoDaTarefa(t("f", "2026-12-12"), SecaoWidget.DEPOIS, hoje))
    }
}
