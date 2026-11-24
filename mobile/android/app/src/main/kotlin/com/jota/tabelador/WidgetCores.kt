package com.jota.tabelador

import android.content.Context
import android.graphics.Color as AndroidColor
import android.os.Build
import androidx.compose.ui.graphics.Color
import androidx.glance.color.ColorProvider as DiaNoite
import androidx.glance.unit.ColorProvider

// Cores compartilhadas pelos widgets (Hoje e Próximo).

internal fun corTema(hexClaro: String, hexEscuro: String): ColorProvider =
    DiaNoite(day = parseColor(hexClaro), night = parseColor(hexEscuro))

internal fun parseColor(hex: String): Color =
    try {
        Color(AndroidColor.parseColor(hex))
    } catch (e: IllegalArgumentException) {
        Color.Gray
    }

// Chrome neutro: usa a rampa neutra do sistema (Monet) no Android 12+, cai
// numa aproximação cinza fixa antes disso. Croma fica só nas linhas dos itens.
internal fun neutralBackground(context: Context): ColorProvider =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        DiaNoite(
            day = Color(context.getColor(android.R.color.system_neutral1_10)),
            night = Color(context.getColor(android.R.color.system_neutral1_900)),
        )
    } else {
        DiaNoite(day = Color(0xFFFAFAFA), night = Color(0xFF1C1C1C))
    }

internal fun neutralSurfaceVariant(context: Context): ColorProvider =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        DiaNoite(
            day = Color(context.getColor(android.R.color.system_neutral1_50)),
            night = Color(context.getColor(android.R.color.system_neutral1_800)),
        )
    } else {
        DiaNoite(day = Color(0xFFF0F0F0), night = Color(0xFF2A2A2A))
    }

internal fun neutralOnSurface(context: Context): ColorProvider =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        DiaNoite(
            day = Color(context.getColor(android.R.color.system_neutral1_900)),
            night = Color(context.getColor(android.R.color.system_neutral1_50)),
        )
    } else {
        DiaNoite(day = Color(0xFF1C1C1C), night = Color(0xFFF2F2F2))
    }

internal fun neutralOnSurfaceVariant(context: Context): ColorProvider =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        DiaNoite(
            day = Color(context.getColor(android.R.color.system_neutral2_700)),
            night = Color(context.getColor(android.R.color.system_neutral2_200)),
        )
    } else {
        DiaNoite(day = Color(0xFF5C5C5C), night = Color(0xFFB0B0B0))
    }
