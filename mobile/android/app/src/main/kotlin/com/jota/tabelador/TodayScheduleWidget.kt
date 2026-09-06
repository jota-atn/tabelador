package com.jota.tabelador

import android.content.Context
import android.graphics.Color as AndroidColor
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.color.ColorProvider as DiaNoite
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
import java.util.Calendar

private const val MAX_ROWS = 12
private const val ROW_HEIGHT_DP = 34
// Linha ganha uma terceira faixa (tipo/local) quando há altura reservada
// pra ela — só faz sentido oferecer esse espaço se a largura também sobra.
private const val ROW_HEIGHT_DETALHADO_DP = 46
private const val LARGURA_MINIMA_DETALHE_DP = 220
private const val HEADER_HEIGHT_DP = 26
private const val WIDGET_CORNER_RADIUS_DP = 16

/**
 * O widget de tela inicial: só o dia de hoje da tabela ativa. Burro de
 * propósito — lê o snapshot já resolvido em `today_schedule_json`, nunca
 * conhece paleta nem densidade (isso é trabalho do Flutter, ver
 * `lib/native_widget/today_schedule_snapshot.dart`).
 */
class TodayScheduleWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<HomeWidgetGlanceState>().preferences
            val snapshot = TodayScheduleSnapshot.parse(prefs.getString("today_schedule_json", null))
            Content(context, snapshot)
        }
    }

    @Composable
    private fun Content(context: Context, snapshot: TodayScheduleSnapshot) {
        // Quantas linhas cabem na altura disponível: pequeno mostra 2-3,
        // grande mostra o dia inteiro — sem layouts XML duplicados por
        // tamanho, só uma conta em cima do espaço que o Glance informa.
        // A largura entra também: alargar o widget (2x2 -> 3x2, por exemplo)
        // só esticava espaço vazio antes — agora libera uma segunda linha de
        // detalhe (tipo/local) por slot, que já vinha no snapshot mas nunca
        // era mostrada.
        val alturaDp = LocalSize.current.height.value.toInt()
        val larguraDp = LocalSize.current.width.value.toInt()
        val mostrarDetalhe = larguraDp >= LARGURA_MINIMA_DETALHE_DP
        val alturaLinha = if (mostrarDetalhe) ROW_HEIGHT_DETALHADO_DP else ROW_HEIGHT_DP
        val linhasVisiveis = ((alturaDp - HEADER_HEIGHT_DP) / alturaLinha)
            .coerceAtLeast(1)
            .coerceAtMost(MAX_ROWS)
            .coerceAtMost(if (snapshot.slots.isEmpty()) 1 else snapshot.slots.size)

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(neutralBackground(context))
                .cornerRadius(WIDGET_CORNER_RADIUS_DP.dp)
                .padding(10.dp)
                .clickable(actionStartActivity<MainActivity>(context)),
        ) {
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                if (snapshot.tableName.isNotBlank()) {
                    Text(
                        text = snapshot.tableName,
                        style = TextStyle(fontSize = 11.sp, color = neutralOnSurfaceVariant(context)),
                    )
                    Spacer(modifier = GlanceModifier.width(6.dp))
                }
                Text(
                    text = snapshot.dayLabel,
                    style = TextStyle(
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = neutralOnSurface(context),
                    ),
                )
            }
            Spacer(modifier = GlanceModifier.height(8.dp))

            if (!snapshot.hasClassesToday) {
                EstadoVazio(context, snapshot.dayLabel)
            } else {
                val agora = Calendar.getInstance()
                for (slot in snapshot.slots.take(linhasVisiveis)) {
                    SlotRow(context, slot, estaNoSlotAgora(slot.time, agora), mostrarDetalhe, alturaLinha)
                }
            }
        }
    }

    @Composable
    private fun EstadoVazio(context: Context, dayLabel: String) {
        val texto = if (dayLabel.isNotBlank()) "Sem aulas — $dayLabel" else "Sem aulas hoje"
        Text(text = texto, style = TextStyle(fontSize = 13.sp, color = neutralOnSurfaceVariant(context)))
    }

    @Composable
    private fun SlotRow(
        context: Context,
        slot: ScheduleSlot,
        agora: Boolean,
        mostrarDetalhe: Boolean,
        alturaLinha: Int,
    ) {
        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .height(alturaLinha.dp)
                .background(corTema(slot.bgLight, slot.bgDark)),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            if (slot.barWidthDp > 0) {
                Spacer(
                    modifier = GlanceModifier
                        .width(slot.barWidthDp.dp)
                        .fillMaxSize()
                        .background(corTema(slot.barLight, slot.barDark)),
                )
                Spacer(modifier = GlanceModifier.width(4.dp))
            }
            Column(modifier = GlanceModifier.padding(horizontal = 4.dp)) {
                Text(
                    text = slot.time,
                    style = TextStyle(
                        fontSize = 9.sp,
                        fontWeight = if (agora) FontWeight.Bold else FontWeight.Normal,
                        color = corTema(slot.fgLight, slot.fgDark),
                    ),
                )
                Text(
                    text = slot.sigla,
                    style = TextStyle(
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = corTema(slot.fgLight, slot.fgDark),
                    ),
                )
                val detalhe = if (mostrarDetalhe) detalheDoSlot(slot) else null
                if (detalhe != null) {
                    Text(
                        text = detalhe,
                        style = TextStyle(fontSize = 9.sp, color = corTema(slot.fgLight, slot.fgDark)),
                    )
                }
            }
        }
    }
}

/// "Aula · Bloco C, sala 204" — mesma junção que o editor do dia usa no
/// Flutter (tipo e local, o que houver). Null se não tiver nenhum dos dois.
private fun detalheDoSlot(slot: ScheduleSlot): String? {
    val partes = listOfNotNull(slot.tipo.takeIf { it.isNotBlank() }, slot.local)
    return if (partes.isEmpty()) null else partes.joinToString(" · ")
}

private fun corTema(hexClaro: String, hexEscuro: String): ColorProvider =
    DiaNoite(day = parseColor(hexClaro), night = parseColor(hexEscuro))

private fun parseColor(hex: String): Color =
    try {
        Color(AndroidColor.parseColor(hex))
    } catch (e: IllegalArgumentException) {
        Color.Gray
    }

/**
 * Slot ocupa uma faixa "H:00-H:00" (ver `Tabela.horarios`). O JSON não carrega
 * um flag "é agora": recalcular aqui é o que mantém o destaque certo mesmo se
 * o widget não atualizar no minuto exato.
 */
private fun estaNoSlotAgora(time: String, agora: Calendar): Boolean {
    val inicio = time.substringBefore('-').substringBefore(':').trim().toIntOrNull() ?: return false
    val fim = time.substringAfter('-').substringBefore(':').trim().toIntOrNull() ?: return false
    val hora = agora.get(Calendar.HOUR_OF_DAY)
    return hora in inicio until fim
}

// Chrome neutro: usa a rampa neutra do sistema (Monet) no Android 12+, cai
// numa aproximação cinza fixa antes disso. Croma fica só nas linhas dos itens.
private fun neutralBackground(context: Context): ColorProvider =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        DiaNoite(
            day = Color(context.getColor(android.R.color.system_neutral1_10)),
            night = Color(context.getColor(android.R.color.system_neutral1_900)),
        )
    } else {
        DiaNoite(day = Color(0xFFFAFAFA), night = Color(0xFF1C1C1C))
    }

private fun neutralOnSurface(context: Context): ColorProvider =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        DiaNoite(
            day = Color(context.getColor(android.R.color.system_neutral1_900)),
            night = Color(context.getColor(android.R.color.system_neutral1_50)),
        )
    } else {
        DiaNoite(day = Color(0xFF1C1C1C), night = Color(0xFFF2F2F2))
    }

private fun neutralOnSurfaceVariant(context: Context): ColorProvider =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        DiaNoite(
            day = Color(context.getColor(android.R.color.system_neutral2_700)),
            night = Color(context.getColor(android.R.color.system_neutral2_200)),
        )
    } else {
        DiaNoite(day = Color(0xFF5C5C5C), night = Color(0xFFB0B0B0))
    }
