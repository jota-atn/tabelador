package com.jota.tabelador

import org.json.JSONObject

/** Uma célula ocupada de hoje, já com as cores resolvidas em hex pelo Flutter. */
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
 * `lib/native_widget/today_schedule_snapshot.dart`). O widget é burro de
 * propósito: só faz parse, nunca resolve cor nem densidade.
 */
data class TodayScheduleSnapshot(
    val tableName: String,
    val dayLabel: String,
    val hasClassesToday: Boolean,
    val slots: List<ScheduleSlot>,
) {
    companion object {
        val vazio = TodayScheduleSnapshot(
            tableName = "",
            dayLabel = "",
            hasClassesToday = false,
            slots = emptyList(),
        )

        /** JSON ausente ou corrompido vira o snapshot vazio, nunca derruba o widget. */
        fun parse(json: String?): TodayScheduleSnapshot {
            if (json.isNullOrBlank()) return vazio

            return try {
                val obj = JSONObject(json)
                val slotsArray = obj.optJSONArray("slots")
                val slots = buildList {
                    if (slotsArray != null) {
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
                TodayScheduleSnapshot(
                    tableName = obj.optString("tableName"),
                    dayLabel = obj.optString("dayLabel"),
                    hasClassesToday = obj.optBoolean("hasClassesToday", false),
                    slots = slots,
                )
            } catch (e: Exception) {
                vazio
            }
        }
    }
}
