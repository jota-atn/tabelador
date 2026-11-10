package com.jota.tabelador

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AgendaChannel.registrar(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
