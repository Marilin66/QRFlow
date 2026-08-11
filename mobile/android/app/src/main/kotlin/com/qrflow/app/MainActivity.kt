package com.qrflow.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private lateinit var screenCaptureChannel: ScreenCaptureChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        screenCaptureChannel = ScreenCaptureChannel.register(flutterEngine, this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent.action == ScreenCaptureChannel.ACTION_CAPTURE) {
            val path = intent.getStringExtra(QRFlowAccessibilityService.EXTRA_PATH)
            intent.action = null
            // Flutter va récupérer le chemin stocké
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ScreenCaptureChannel.ACTION_CAPTURE) {
            val path = intent.getStringExtra(QRFlowAccessibilityService.EXTRA_PATH)
            intent.action = null
            // Flutter va récupérer le chemin stocké, on peut aussi l'envoyer via le channel si besoin
        }
    }
}
