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
import androidx.glance.LocalSize
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
import java.time.Duration
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
private const val PADDING_DP = 12
private const val ALTURA_LINHA_DEPOIS_DP = 15

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
        val principal = neutralOnSurface(context)
        // Altura que sobra depois do bloco principal vira a lista "Depois".
        val tamanho = LocalSize.current
        var sobra = tamanho.height.value.toInt() - 2 * PADDING_DP
        // Largura do texto: tira margens e a barra lateral.
        val larguraTexto = tamanho.width.value.toInt() - 2 * PADDING_DP - 14
        Row(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(neutralBackground(context))
                .cornerRadius(16.dp)
                .padding(PADDING_DP.dp)
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
                    sobra -= 22
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
                    style = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.Bold, color = principal),
                )
                Spacer(modifier = GlanceModifier.height(2.dp))
                Text(
                    text = faixa(proximo),
                    maxLines = 1,
                    style = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Medium, color = principal),
                )
                // "Amanhã · em ~9 h" ou "Hoje · em 24:59" (contagem do sistema).
                val estiloQuando = TextStyle(fontSize = 12.sp, color = neutralOnSurfaceVariant(context))
                val falta = Duration.between(agora, proximo.inicio).toMinutes()
                Row(verticalAlignment = Alignment.Vertical.CenterVertically) {
                    Text(text = "${rotuloDoDia(proximo.data, hoje)} · ", style = estiloQuando)
                    if (falta < MINUTOS_CONTAGEM) {
                        Contagem(context, proximo.inicio)
                    } else {
                        Text(text = faltaAproximada(falta), style = estiloQuando)
                    }
                }
                sobra -= linhas(proximo.titulo, 17, larguraTexto, 2) * 23 + 2 + 18 + 16
                val detalhe = listOfNotNull(proximo.tipo, proximo.local?.takeIf { it.isNotBlank() }).joinToString(" · ")
                if (detalhe.isNotEmpty()) {
                    Spacer(modifier = GlanceModifier.height(4.dp))
                    Text(text = detalhe, maxLines = 2, style = secundario)
                    sobra -= 4 + linhas(detalhe, 11, larguraTexto, 2) * 15
                }
                // "Depois": o resto do mesmo dia, quantos couberem.
                val cabem = ((sobra - 10 - 14) / ALTURA_LINHA_DEPOIS_DP).coerceAtLeast(0)
                val depois = p.depois.take(cabem)
                if (depois.isNotEmpty()) {
                    Spacer(modifier = GlanceModifier.height(10.dp))
                    Text(
                        text = if (p.depois.size > depois.size) "Depois (+${p.depois.size - depois.size})" else "Depois",
                        style = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Bold, color = neutralOnSurfaceVariant(context)),
                    )
                    for (m in depois) {
                        Text(
                            text = "${horaMin(m.inicioMin)}  ${m.titulo}",
                            maxLines = 1,
                            style = TextStyle(fontSize = 11.sp, color = principal),
                        )
                    }
                }
            }
        }
    }

    /** Linhas que [texto] ocupa em [sp] numa largura de [largura] dp
     *  (estimativa: caractere médio ~0,55 do tamanho da fonte). */
    private fun linhas(texto: String, sp: Int, largura: Int, max: Int): Int {
        if (largura <= 0) return max
        val porLinha = (largura / (sp * 0.55)).toInt().coerceAtLeast(1)
        return ((texto.length + porLinha - 1) / porLinha).coerceIn(1, max)
    }

    /** "10:00–12:00", ou só o começo se não tiver fim. */
    private fun faixa(m: Momento): String =
        if (m.fimMin > m.inicioMin) "${horaMin(m.inicioMin)}–${horaMin(m.fimMin)}" else horaMin(m.inicioMin)

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
