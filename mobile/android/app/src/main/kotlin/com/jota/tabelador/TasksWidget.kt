package com.jota.tabelador

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.CheckBox
import androidx.glance.appwidget.CheckboxDefaults
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
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
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextDecoration
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.actionStartActivity
import java.time.LocalDateTime
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONArray

/** Chaves gravadas pelo widget; o app conclui de verdade e limpa
 *  (`HomeWidgetSync._aplicarFeitasNoWidget`). */
internal const val TAREFAS_RISCADAS = "tarefas_riscadas_widget"
internal const val TAREFAS_FEITAS = "tarefas_feitas_widget"

/** Quanto a tarefa fica riscada antes de sumir (como no app). */
private const val MS_RISCADA = 2_000L

private val CHAVE = ActionParameters.Key<String>("chave")

/** Toques rápidos em tarefas diferentes rodam em paralelo: a trava evita
 *  que um sobrescreva a lista do outro. */
private val trava = Mutex()

internal fun lerChaves(prefs: SharedPreferences, nome: String): Set<String> {
    val bruto = prefs.getString(nome, null) ?: return emptySet()
    return try {
        val lista = JSONArray(bruto)
        buildSet { for (i in 0 until lista.length()) add(lista.optString(i)) }
    } catch (e: Exception) {
        emptySet()
    }
}

private fun salvarChaves(prefs: SharedPreferences, nome: String, chaves: Set<String>) {
    prefs.edit().apply {
        if (chaves.isEmpty()) remove(nome) else putString(nome, JSONArray(chaves.toList()).toString())
    }.commit()
}

/**
 * Widget de Tarefas: as pendentes por seção, como na página do app.
 * Tocar na caixinha risca; ~2 s depois some. A conclusão de verdade
 * (com repetição, avisos, Google) o app faz quando abre — até lá o widget
 * guarda a chave e esconde a tarefa.
 */
class TasksWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()
    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<HomeWidgetGlanceState>().preferences
            val snapshot = TodayScheduleSnapshot.parse(prefs.getString("today_schedule_json", null))
            Content(
                context,
                snapshot,
                riscadas = lerChaves(prefs, TAREFAS_RISCADAS),
                feitas = lerChaves(prefs, TAREFAS_FEITAS),
            )
        }
    }

    private sealed class Linha {
        data class Secao(val secao: SecaoWidget, val total: Int) : Linha()
        data class Tarefa(val tarefa: ScheduleTask, val secao: SecaoWidget) : Linha()
    }

    @Composable
    private fun Content(context: Context, snapshot: TodayScheduleSnapshot, riscadas: Set<String>, feitas: Set<String>) {
        val agora = LocalDateTime.now()
        val grupos = organizarNoWidget(snapshot.tasks, agora, snapshot.firstDay, feitas)
        val linhas = buildList {
            for ((secao, lista) in grupos) {
                add(Linha.Secao(secao, lista.size))
                lista.forEach { add(Linha.Tarefa(it, secao)) }
            }
        }
        val paraHoje = grupos.filter { it.first == SecaoWidget.ATRASADAS || it.first == SecaoWidget.HOJE }
            .sumOf { (_, l) -> l.count { it.key !in riscadas } }
        val abrir = actionStartActivity<MainActivity>(context)
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(neutralBackground(context))
                .cornerRadius(16.dp)
                .padding(horizontal = 12.dp, vertical = 10.dp),
        ) {
            Row(
                modifier = GlanceModifier.fillMaxWidth().clickable(abrir),
                verticalAlignment = Alignment.Vertical.CenterVertically,
            ) {
                Text(
                    text = "Tarefas",
                    style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Bold, color = neutralOnSurface(context)),
                )
                Spacer(modifier = GlanceModifier.defaultWeight())
                if (paraHoje > 0) {
                    Text(
                        text = "$paraHoje pra hoje",
                        style = TextStyle(fontSize = 11.sp, color = neutralOnSurfaceVariant(context)),
                    )
                }
            }
            Spacer(modifier = GlanceModifier.height(6.dp))
            if (linhas.isEmpty()) {
                Text(
                    text = "Nada pendente",
                    modifier = GlanceModifier.clickable(abrir),
                    style = TextStyle(fontSize = 13.sp, color = neutralOnSurfaceVariant(context)),
                )
                return@Column
            }
            LazyColumn(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
                items(linhas) { linha ->
                    when (linha) {
                        is Linha.Secao -> Text(
                            text = linha.secao.rotulo,
                            modifier = GlanceModifier.padding(top = 6.dp, bottom = 2.dp),
                            style = TextStyle(
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Medium,
                                color = if (linha.secao == SecaoWidget.ATRASADAS) atrasada(context) else neutralOnSurfaceVariant(context),
                            ),
                        )
                        is Linha.Tarefa -> LinhaDeTarefa(context, linha.tarefa, linha.secao, linha.tarefa.key in riscadas, agora)
                    }
                }
            }
        }
    }

    @Composable
    private fun LinhaDeTarefa(context: Context, t: ScheduleTask, secao: SecaoWidget, riscada: Boolean, agora: LocalDateTime) {
        val quando = quandoDaTarefa(t, secao, agora.toLocalDate())
        Row(
            modifier = GlanceModifier.fillMaxWidth().padding(vertical = 1.dp),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            Spacer(
                modifier = GlanceModifier
                    .width(3.dp)
                    .height(if (quando != null) 34.dp else 24.dp)
                    .cornerRadius(2.dp)
                    .background(corTema(t.barLight, t.barDark)),
            )
            CheckBox(
                checked = riscada,
                onCheckedChange = actionRunCallback<AlternarTarefa>(actionParametersOf(CHAVE to t.key)),
                colors = CheckboxDefaults.colors(
                    checkedColor = accent(context),
                    uncheckedColor = neutralOnSurfaceVariant(context),
                ),
            )
            Column(modifier = GlanceModifier.defaultWeight().clickable(actionStartActivity<MainActivity>(context))) {
                Text(
                    text = t.title,
                    maxLines = 2,
                    style = TextStyle(
                        fontSize = 13.sp,
                        fontWeight = if (t.high && !riscada) FontWeight.Medium else FontWeight.Normal,
                        color = if (riscada) neutralOnSurfaceVariant(context) else neutralOnSurface(context),
                        textDecoration = if (riscada) TextDecoration.LineThrough else TextDecoration.None,
                    ),
                )
                if (quando != null) {
                    Text(
                        text = quando,
                        style = TextStyle(
                            fontSize = 10.sp,
                            color = if (secao == SecaoWidget.ATRASADAS && !riscada) atrasada(context) else neutralOnSurfaceVariant(context),
                        ),
                    )
                }
            }
        }
    }
}

/** Marca/desmarca no widget: risca na hora, esconde depois de ~2 s. */
class AlternarTarefa : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val chave = parameters[CHAVE] ?: return
        val prefs = HomeWidgetPlugin.getData(context)
        val desfez = trava.withLock {
            val riscadas = lerChaves(prefs, TAREFAS_RISCADAS)
            // Segundo toque dentro dos 2 s: desfaz.
            if (chave in riscadas) {
                salvarChaves(prefs, TAREFAS_RISCADAS, riscadas - chave)
                true
            } else {
                salvarChaves(prefs, TAREFAS_RISCADAS, riscadas + chave)
                false
            }
        }
        TasksWidget().update(context, glanceId)
        if (desfez) return
        delay(MS_RISCADA)
        val sumiu = trava.withLock {
            val riscadas = lerChaves(prefs, TAREFAS_RISCADAS)
            if (chave !in riscadas) return@withLock false
            salvarChaves(prefs, TAREFAS_FEITAS, lerChaves(prefs, TAREFAS_FEITAS) + chave)
            salvarChaves(prefs, TAREFAS_RISCADAS, riscadas - chave)
            true
        }
        if (sumiu) TasksWidget().update(context, glanceId)
    }
}

class TasksWidgetReceiver : HomeWidgetGlanceWidgetReceiver<TasksWidget>() {
    override val glanceAppWidget = TasksWidget()
}
