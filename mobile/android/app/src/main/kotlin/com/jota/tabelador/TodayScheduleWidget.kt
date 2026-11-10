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
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
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

private const val ROW_HEIGHT_DP = 34
// Linha ganha uma terceira faixa (tipo/local) quando há altura reservada
// pra ela — só faz sentido oferecer esse espaço se a largura também sobra.
private const val ROW_HEIGHT_DETALHADO_DP = 46
private const val LARGURA_MINIMA_DETALHE_DP = 220
private const val WIDGET_CORNER_RADIUS_DP = 16

/**
 * O widget de tela inicial: só o dia de hoje da tabela ativa. Burro de
 * propósito — lê o snapshot já resolvido em `today_schedule_json`, nunca
 * conhece paleta nem densidade (isso é trabalho do Flutter, ver
 * `lib/native_widget/today_schedule_snapshot.dart`).
 */
class TodayScheduleWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    // Default é SizeMode.Single: LocalSize.current fica travado num tamanho
    // mínimo fixo, ignorando o tamanho real que o usuário deu ao widget na
    // tela — é por isso que redimensionar não liberava mais linhas antes.
    // Exact recompõe com o tamanho real a cada redimensionamento.
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<HomeWidgetGlanceState>().preferences
            val snapshot = TodayScheduleSnapshot.parse(prefs.getString("today_schedule_json", null))
            Content(context, snapshot)
        }
    }

    @Composable
    private fun Content(context: Context, snapshot: TodayScheduleSnapshot) {
        // "Hoje" é resolvido aqui, não no snapshot: o Flutter manda a semana
        // inteira e este cálculo roda de novo a cada redesenho (inclusive os
        // automáticos do Android, sem o app rodar), então o widget nunca
        // fica preso no dia de quando foi sincronizado por último.
        val agora = Calendar.getInstance()
        val dayLabel = nomeDoDiaAtual(agora)
        val slotsDeHoje = snapshot.week[dayLabel] ?: emptyList()

        // A largura decide só o nível de detalhe agora: alargar o widget
        // (2x2 -> 3x2, por exemplo) libera uma segunda linha de detalhe
        // (tipo/local) por slot, que já vinha no snapshot mas nunca era
        // mostrada. A altura não precisa mais de conta nenhuma — o que não
        // cabe fica disponível arrastando pra baixo dentro do `LazyColumn`.
        val larguraDp = LocalSize.current.width.value.toInt()
        val mostrarDetalhe = larguraDp >= LARGURA_MINIMA_DETALHE_DP
        val alturaLinha = if (mostrarDetalhe) ROW_HEIGHT_DETALHADO_DP else ROW_HEIGHT_DP

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
                    text = dayLabel,
                    style = TextStyle(
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = neutralOnSurface(context),
                    ),
                )
            }
            Spacer(modifier = GlanceModifier.height(8.dp))

            if (slotsDeHoje.isEmpty()) {
                EstadoVazio(context, dayLabel)
            } else {
                // LazyColumn em vez de Column: o mesmo mecanismo de scroll
                // (RemoteViews ListView por baixo) que widgets como o do
                // Gmail usam — dia cheio de horários vira scroll, não corte.
                LazyColumn(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
                    items(slotsDeHoje) { slot ->
                        SlotRow(context, slot, estaNoSlotAgora(slot.time, agora), mostrarDetalhe, alturaLinha)
                    }
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
                .background(corTema(slot.bgLight, slot.bgDark))
                // Item dentro de um LazyColumn precisa do próprio clique —
                // a lista consome o gesto de arrastar, então o clickable do
                // container só cobre header/margens, não as linhas.
                .clickable(actionStartActivity<MainActivity>(context)),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            if (slot.barWidthDp > 0) {
                Spacer(
                    modifier = GlanceModifier
                        .width(slot.barWidthDp.dp)
                        .fillMaxHeight()
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
 * Nome do dia de hoje, nas mesmas chaves que o Flutter usa como chave do mapa
 * `week` (ver `kTodosDias` em `lib/model/tabela.dart`). `Calendar.DAY_OF_WEEK`
 * é 1-based com domingo primeiro (`SUNDAY=1`..`SATURDAY=7`), por isso o mapa
 * explícito em vez de aritmética de índice.
 */
private val NOMES_DIA_POR_CALENDAR = mapOf(
    Calendar.SUNDAY to "DOMINGO",
    Calendar.MONDAY to "SEGUNDA",
    Calendar.TUESDAY to "TERÇA",
    Calendar.WEDNESDAY to "QUARTA",
    Calendar.THURSDAY to "QUINTA",
    Calendar.FRIDAY to "SEXTA",
    Calendar.SATURDAY to "SÁBADO",
)

private fun nomeDoDiaAtual(agora: Calendar): String =
    NOMES_DIA_POR_CALENDAR[agora.get(Calendar.DAY_OF_WEEK)] ?: ""

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
