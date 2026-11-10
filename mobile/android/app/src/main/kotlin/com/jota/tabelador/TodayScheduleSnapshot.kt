package com.jota.tabelador

import org.json.JSONArray
import org.json.JSONObject

/** Uma célula ocupada de um dia, já com as cores resolvidas em hex pelo Flutter. */
data class ScheduleSlot(
    val time: String,
    val sigla: String,
    val tipo: String,
    val local: String?,
    val bgLight: String,
    val bgDark: String,
    val fgLight: String,
    val fgDark: String,
    val barLight: String,
    val barDark: String,
    val barWidthDp: Int,
)

/**
 * Espelho Kotlin do JSON `today_schedule_json` escrito pelo Flutter (ver
 * `lib/native_widget/today_schedule_snapshot.dart`). Carrega a semana
 * inteira, não só um dia — quem resolve "qual dia é hoje" é o widget, na
 * hora de desenhar (`TodayScheduleWidget.kt`), pra nunca ficar preso num dia
 * antigo enquanto o Flutter não roda de novo.
 */
data class TodayScheduleSnapshot(
    val tableName: String,
    val week: Map<String, List<ScheduleSlot>>,
) {
    companion object {
        val vazio = TodayScheduleSnapshot(tableName = "", week = emptyMap())

        /** JSON ausente ou corrompido vira o snapshot vazio, nunca derruba o widget. */
        fun parse(json: String?): TodayScheduleSnapshot {
            if (json.isNullOrBlank()) return vazio

            return try {
                val obj = JSONObject(json)
                val weekObj = obj.optJSONObject("week")
                val week = buildMap {
                    if (weekObj != null) {
                        for (dia in weekObj.keys()) {
                            put(dia, parseSlots(weekObj.optJSONArray(dia)))
                        }
                    }
                }
                TodayScheduleSnapshot(tableName = obj.optString("tableName"), week = week)
            } catch (e: Exception) {
                vazio
            }
        }

        private fun parseSlots(slotsArray: JSONArray?): List<ScheduleSlot> {
            if (slotsArray == null) return emptyList()
            return buildList {
                for (i in 0 until slotsArray.length()) {
                    val s = slotsArray.getJSONObject(i)
                    add(
                        ScheduleSlot(
                            time = s.optString("time"),
                            sigla = s.optString("sigla"),
                            tipo = s.optString("tipo"),
                            local = if (s.has("local")) s.optString("local") else null,
                            bgLight = s.optString("bgLight", "#FFFFFF"),
                            bgDark = s.optString("bgDark", "#000000"),
                            fgLight = s.optString("fgLight", "#000000"),
                            fgDark = s.optString("fgDark", "#FFFFFF"),
                            barLight = s.optString("barLight", "#00000000"),
                            barDark = s.optString("barDark", "#00000000"),
                            barWidthDp = s.optInt("barWidthDp", 0),
                        ),
                    )
                }
            }
        }
    }
}
