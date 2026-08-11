package com.qrflow.app

import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Activité principale de QRFlow.
 *
 * Gère le consentement MediaProjection (capture d'écran) déclenché soit depuis
 * Flutter (canal [ScreenCaptureChannel.CHANNEL]), soit par un appui sur la
 * bulle flottante (action [ScreenCaptureChannel.ACTION_CAPTURE]).
 */
class MainActivity : FlutterActivity() {

    private lateinit var screenCaptureChannel: ScreenCaptureChannel
    private val SCREEN_CAPTURE_REQUEST_CODE = 1000

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        screenCaptureChannel = ScreenCaptureChannel.register(flutterEngine, this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // L'intent peut porter l'action CAPTURE si l'app a été lancée depuis
        // la bulle flottante après un arrêt complet.
        if (intent.action == ScreenCaptureChannel.ACTION_CAPTURE) {
            intent.action = null
            requestScreenCapture()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ScreenCaptureChannel.ACTION_CAPTURE) {
            intent.action = null
            requestScreenCapture()
        }
    }

    /** Déclenche la demande de consentement pour la capture d'écran. */
    fun requestScreenCapture() {
        val mpm = getSystemService(MediaProjectionManager::class.java)
        startActivityForResult(mpm.createScreenCaptureIntent(), SCREEN_CAPTURE_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_CAPTURE_REQUEST_CODE) {
            screenCaptureChannel.onProjectionResult(resultCode, data)
        }
    }
}
