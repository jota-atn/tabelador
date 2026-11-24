package com.jota.tabelador

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
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
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.actionStartActivity
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * Widget "Próximo" (2×2): o próximo horário ou evento, bem descritivo.
 * Lê o mesmo snapshot do widget Hoje (`today_schedule_json`) e decide
 * sozinho, a cada redesenho, o que está acontecendo e o que vem depois.
 *
 * O Android não redesenha widget de minuto em minuto, então a contagem
 * ("em 24:59") é um `Chronometer` regressivo, que o próprio sistema
 * desenha; e um alarme inexato redesenha quando algo começa ou termina.
 */
class NextUpWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<HomeWidgetGlanceState>().preferences
            val snapshot = TodayScheduleSnapshot.parse(prefs.getString("today_schedule_json", null))
            val agora = LocalDateTime.now()
            val p = calcularProximo(snapshot, agora)
            LaunchedEffect(p.mudaEm) { agendarRedesenho(context, p.mudaEm) }
            Content(context, p, agora)
        }
    }

    @Composable
    private fun Content(context: Context, p: Proximo, agora: LocalDateTime) {
        val secundario = TextStyle(fontSize = 11.sp, color = neutralOnSurfaceVariant(context))
        Row(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(neutralBackground(context))
                .cornerRadius(16.dp)
                .padding(12.dp)
                .clickable(actionStartActivity<MainActivity>(context)),
            verticalAlignment = Alignment.Vertical.Top,
        ) {
            val proximo = p.proximo
            if (proximo != null) {
                Spacer(
                    modifier = GlanceModifier
                        .width(4.dp)
                        .fillMaxHeight()
                        .cornerRadius(2.dp)
                        .background(corTema(proximo.barLight, proximo.barDark)),
                )
                Spacer(modifier = GlanceModifier.width(10.dp))
            }
            Column(modifier = GlanceModifier.fillMaxWidth()) {
                val emAndamento = p.agora
                if (emAndamento != null) {
                    Text(
                        text = "Agora: ${emAndamento.titulo} · até ${horaMin(emAndamento.fimMin)}",
                        maxLines = 1,
                        style = secundario,
                    )
                    Spacer(modifier = GlanceModifier.height(6.dp))
                }
                if (proximo == null) {
                    Text(
                        text = "Nada pela frente",
                        style = TextStyle(fontSize = 15.sp, color = neutralOnSurfaceVariant(context)),
                    )
                    return@Column
                }
                val hoje = agora.toLocalDate()
                Text(
                    text = proximo.titulo,
                    maxLines = 2,
                    style = TextStyle(
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                        color = neutralOnSurface(context),
                    ),
                )
                Spacer(modifier = GlanceModifier.height(2.dp))
                val quando = if (proximo.data == hoje) {
                    "às ${horaMin(proximo.inicioMin)}"
                } else {
                    "${rotuloDoDia(proximo.data, hoje)} às ${horaMin(proximo.inicioMin)}"
                }
                Text(
                    text = quando,
                    style = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Medium, color = neutralOnSurface(context)),
                )
                if (proximo.data == hoje) Contagem(context, proximo.inicio)
                val detalhe = proximo.local?.takeIf { it.isNotBlank() }?.let { "Local: $it" } ?: proximo.tipo
                if (detalhe != null) {
                    Spacer(modifier = GlanceModifier.height(6.dp))
                    Text(text = detalhe, maxLines = 2, style = secundario)
                }
            }
        }
    }

    /** "em 24:59", contando sozinho até [inicio]. */
    @Composable
    private fun Contagem(context: Context, inicio: LocalDateTime) {
        val falta = inicio.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli() - System.currentTimeMillis()
        val views = RemoteViews(context.packageName, R.layout.next_up_chronometer).apply {
            setChronometer(R.id.contagem, SystemClock.elapsedRealtime() + falta, "em %s", true)
            setChronometerCountDown(R.id.contagem, true)
        }
        AndroidRemoteViews(views)
    }
}

/**
 * Redesenha o widget Próximo em [quando] (inexato: o Android pode atrasar
 * um pouco, mas não precisa de permissão de alarme exato). Substitui o
 * alarme anterior.
 */
private fun agendarRedesenho(context: Context, quando: LocalDateTime?) {
    val alarmes = context.getSystemService(AlarmManager::class.java) ?: return
    val gerenciador = AppWidgetManager.getInstance(context)
    val ids = gerenciador.getAppWidgetIds(ComponentName(context, NextUpWidgetReceiver::class.java))
    val intent = Intent(context, NextUpWidgetReceiver::class.java)
        .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
    val pendente = PendingIntent.getBroadcast(
        context,
        0,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    alarmes.cancel(pendente)
    if (quando == null || ids.isEmpty()) return
    val em = quando.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli() + 1_000
    alarmes.setWindow(AlarmManager.RTC, em, 60_000, pendente)
}

class NextUpWidgetReceiver : HomeWidgetGlanceWidgetReceiver<NextUpWidget>() {
    override val glanceAppWidget = NextUpWidget()
}
