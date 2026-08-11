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
        handleCaptureIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCaptureIntent(intent)
    }

    /**
     * Quand l'activité est relancée par la bulle flottante (action CAPTURE),
     * on prévient Flutter : la capture est en attente dans les préférences et
     * l'analyse peut démarrer immédiatement (même si l'app est au premier
     * plan, ce qui ne déclencherait aucun événement de cycle de vie).
     */
    private fun handleCaptureIntent(intent: Intent?) {
        if (intent?.action == ScreenCaptureChannel.ACTION_CAPTURE) {
            val path = intent.getStringExtra(QRFlowAccessibilityService.EXTRA_PATH)
            intent.action = null
            screenCaptureChannel.notifyCaptureReady(path)
        }
    }
}
