package com.jota.tabelador

import android.content.ContentUris
import android.content.ContentValues
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Ponte própria pra agenda do Android (CalendarContract), lado nativo de
 * `lib/agenda/agendas_do_aparelho.dart`.
 *
 * Existe porque o plugin `device_calendar` não expõe duas coisas de que o
 * app precisa: a chave "baixar eventos" de cada agenda (`SYNC_EVENTS` —
 * turmas do Classroom vêm com ela desligada, e aí não têm evento nenhum no
 * aparelho) e a leitura de ocorrências com controle sobre evento de dia
 * inteiro (que o Android guarda em meia-noite UTC). O plugin continua só
 * pra pedir a permissão em runtime.
 *
 * Toda consulta roda fora da main thread; resposta volta na main, como o
 * MethodChannel exige.
 */
object AgendaChannel {
    private const val NOME = "tabelador/agenda"
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun registrar(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, NOME).setMethodCallHandler { call, result ->
            executor.execute {
                try {
                    val resposta: Any? = when (call.method) {
                        "listarAgendas" -> listarAgendas(app)
                        "definirSincronizacao" -> {
                            definirSincronizacao(
                                app,
                                call.argument<String>("id")!!.toLong(),
                                call.argument<Boolean>("ativa")!!,
                            )
                            null
                        }
                        "gravarEvento" -> gravarEvento(
                            app,
                            call.argument<String>("eventoId")?.toLong(),
                            call.argument<String>("agendaId")!!.toLong(),
                            call.argument<Map<String, Any?>>("campos")!!,
                        ).toString()
                        "apagarEvento" -> {
                            apagarEvento(app, call.argument<String>("eventoId")!!.toLong())
                            null
                        }
                        "abrirLink" -> abrirLink(
                            app,
                            call.argument<String>("url")!!,
                            call.argument<String>("pacote"),
                        )
                        "appInstalado" -> appInstalado(app, call.argument<String>("pacote")!!)
                        "abrirApp" -> abrirApp(app, call.argument<String>("pacote")!!)
                        "iconeDoApp" -> iconeDoApp(app, call.argument<String>("pacote")!!)
                        "geocodificar" -> geocodificar(app, call.argument<String>("endereco")!!)
                        "lerEventos" -> lerEventos(
                            app,
                            call.argument<List<String>>("ids")!!.map { it.toLong() },
                            call.argument<Number>("de")!!.toLong(),
                            call.argument<Number>("ate")!!.toLong(),
                        )
                        else -> {
                            main.post { result.notImplemented() }
                            return@execute
                        }
                    }
                    main.post { result.success(resposta) }
                } catch (e: SecurityException) {
                    main.post { result.error("sem_permissao", e.message, null) }
                } catch (e: Exception) {
                    main.post { result.error("erro", e.message, null) }
                }
            }
        }
    }

    /**
     * Abre um link no app que cuida dele (Meet, Zoom, Teams) ou no
     * navegador. Mora aqui pra não precisar de plugin novo só pra isso.
     */
    private fun abrirLink(context: Context, url: String, pacote: String? = null): Boolean {
        fun tentar(comPacote: Boolean): Boolean =
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (comPacote && pacote != null) intent.setPackage(pacote)
                context.startActivity(intent)
                true
            } catch (e: ActivityNotFoundException) {
                false
            }
        // Com pacote (Uber), vai direto pro app; se ele não abrir o link,
        // cai no navegador.
        return (pacote != null && tentar(true)) || tentar(false)
    }

    /** Precisa do pacote em `<queries>` no manifesto (Android 11+). */
    private fun appInstalado(context: Context, pacote: String): Boolean =
        context.packageManager.getLaunchIntentForPackage(pacote) != null

    /** Ícone do app instalado em PNG (bytes), pro botão usar o dele. */
    private fun iconeDoApp(context: Context, pacote: String): ByteArray? {
        val icone = try {
            context.packageManager.getApplicationIcon(pacote)
        } catch (e: android.content.pm.PackageManager.NameNotFoundException) {
            return null
        }
        val lado = 96
        val bitmap = android.graphics.Bitmap.createBitmap(lado, lado, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        icone.setBounds(0, 0, lado, lado)
        icone.draw(canvas)
        val saida = java.io.ByteArrayOutputStream()
        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, saida)
        return saida.toByteArray()
    }

    private fun abrirApp(context: Context, pacote: String): Boolean {
        val intent = context.packageManager.getLaunchIntentForPackage(pacote) ?: return false
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return true
    }

    /**
     * Endereço digitado -> coordenadas, pelo localizador do próprio Android
     * (sem chave nem conta). Null se não achar ou o aparelho não tiver o
     * serviço. Roda no executor, fora da main thread.
     */
    @Suppress("DEPRECATION")
    private fun geocodificar(context: Context, endereco: String): Map<String, Double>? {
        if (!android.location.Geocoder.isPresent()) return null
        val r = try {
            android.location.Geocoder(context, java.util.Locale("pt", "BR"))
                .getFromLocationName(endereco, 1)
        } catch (e: java.io.IOException) {
            null
        }
        val a = r?.firstOrNull() ?: return null
        return mapOf("lat" to a.latitude, "lng" to a.longitude)
    }

    private fun listarAgendas(context: Context): List<Map<String, Any?>> {
        val projecao = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.ACCOUNT_TYPE,
            CalendarContract.Calendars.CALENDAR_COLOR,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
            CalendarContract.Calendars.VISIBLE,
            CalendarContract.Calendars.SYNC_EVENTS,
            CalendarContract.Calendars.OWNER_ACCOUNT,
        )
        val resultado = mutableListOf<Map<String, Any?>>()
        context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI, projecao, null, null, null,
        )?.use { cur ->
            while (cur.moveToNext()) {
                resultado.add(
                    mapOf(
                        "id" to cur.getLong(0).toString(),
                        "nome" to (cur.getString(1) ?: ""),
                        "conta" to (cur.getString(2) ?: ""),
                        "tipoConta" to (cur.getString(3) ?: ""),
                        "cor" to if (cur.isNull(4)) null else cur.getInt(4),
                        "nivelAcesso" to cur.getInt(5),
                        "visivel" to (cur.getInt(6) == 1),
                        "sincroniza" to (cur.getInt(7) == 1),
                        "dono" to (cur.getString(8) ?: ""),
                    ),
                )
            }
        }
        return resultado
    }

    /**
     * `SYNC_EVENTS` é uma das colunas de Calendars que app comum (não sync
     * adapter) pode gravar. Ligar faz o adaptador do Google baixar os eventos
     * daquela agenda na próxima sincronização.
     */
    private fun definirSincronizacao(context: Context, id: Long, ativa: Boolean) {
        val valores = ContentValues().apply {
            put(CalendarContract.Calendars.SYNC_EVENTS, if (ativa) 1 else 0)
        }
        context.contentResolver.update(
            ContentUris.withAppendedId(CalendarContract.Calendars.CONTENT_URI, id),
            valores,
            null,
            null,
        )
    }

    /**
     * Cria (sem [eventoId]) ou atualiza um evento na agenda [agendaId]. O
     * adaptador do Google sobe a mudança pra conta na próxima
     * sincronização — é assim que evento criado no app chega no Google
     * Agenda, sem API nem login.
     *
     * `campos`: titulo, inicio/fim (ms), diaInteiro, local, descricao, rrule.
     * Dia inteiro vai em meia-noite UTC com fuso UTC, como o Android exige;
     * recorrente usa DURATION em vez de DTEND (também exigência do
     * provider). Sem lembrete: quem avisa é o próprio tabelador, e um
     * lembrete do Google em cima daria aviso duplicado.
     */
    private fun gravarEvento(
        context: Context,
        eventoId: Long?,
        agendaId: Long,
        campos: Map<String, Any?>,
    ): Long {
        val diaInteiro = campos["diaInteiro"] as? Boolean ?: false
        val inicio = (campos["inicio"] as Number).toLong()
        val fim = (campos["fim"] as Number).toLong()
        val rrule = campos["rrule"] as? String

        val valores = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, agendaId)
            put(CalendarContract.Events.TITLE, campos["titulo"] as? String ?: "")
            put(CalendarContract.Events.EVENT_LOCATION, campos["local"] as? String)
            put(CalendarContract.Events.DESCRIPTION, campos["descricao"] as? String)
            put(CalendarContract.Events.DTSTART, inicio)
            put(CalendarContract.Events.ALL_DAY, if (diaInteiro) 1 else 0)
            put(
                CalendarContract.Events.EVENT_TIMEZONE,
                if (diaInteiro) "UTC" else java.util.TimeZone.getDefault().id,
            )
            if (rrule != null) {
                put(CalendarContract.Events.RRULE, rrule)
                putNull(CalendarContract.Events.DTEND)
                val segundos = ((fim - inicio) / 1000).coerceAtLeast(0)
                put(
                    CalendarContract.Events.DURATION,
                    if (diaInteiro) "P${(segundos / 86400).coerceAtLeast(1)}D" else "P${segundos}S",
                )
            } else {
                putNull(CalendarContract.Events.RRULE)
                putNull(CalendarContract.Events.DURATION)
                put(CalendarContract.Events.DTEND, fim)
            }
        }

        val resolver = context.contentResolver
        if (eventoId != null) {
            val linhas = resolver.update(
                ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventoId),
                valores,
                null,
                null,
            )
            // Apagado do lado do Google desde a última gravação: recria em vez
            // de perder a edição em silêncio.
            if (linhas > 0) return eventoId
        }
        val uri = resolver.insert(CalendarContract.Events.CONTENT_URI, valores)
            ?: throw IllegalStateException("A agenda recusou o evento")
        return ContentUris.parseId(uri)
    }

    private fun apagarEvento(context: Context, eventoId: Long) {
        context.contentResolver.delete(
            ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventoId),
            null,
            null,
        )
    }

    /**
     * Ocorrências (tabela Instances — recorrência já expandida pelo Android)
     * das agendas [ids] que se sobrepõem a `[de, ate)`, em milissegundos.
     */
    private fun lerEventos(
        context: Context,
        ids: List<Long>,
        de: Long,
        ate: Long,
    ): List<Map<String, Any?>> {
        if (ids.isEmpty()) return emptyList()
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, de)
            ContentUris.appendId(it, ate)
        }.build()
        val projecao = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.CALENDAR_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.ALL_DAY,
            CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.DESCRIPTION,
            CalendarContract.Instances.STATUS,
        )
        val selecao = "${CalendarContract.Instances.CALENDAR_ID} IN (${ids.joinToString(",")})"
        val resultado = mutableListOf<Map<String, Any?>>()
        context.contentResolver.query(uri, projecao, selecao, null, null)?.use { cur ->
            while (cur.moveToNext()) {
                // Evento cancelado (recusado, ou ocorrência apagada de uma
                // série) continua em Instances com esse status.
                if (!cur.isNull(8) && cur.getInt(8) == CalendarContract.Events.STATUS_CANCELED) continue
                resultado.add(
                    mapOf(
                        "eventoId" to cur.getLong(0).toString(),
                        "agendaId" to cur.getLong(1).toString(),
                        "titulo" to (cur.getString(2) ?: ""),
                        "inicio" to cur.getLong(3),
                        "fim" to cur.getLong(4),
                        "diaInteiro" to (cur.getInt(5) == 1),
                        "local" to cur.getString(6),
                        "descricao" to cur.getString(7),
                    ),
                )
            }
        }
        return resultado
    }
}
