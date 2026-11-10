package com.jota.tabelador

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
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
