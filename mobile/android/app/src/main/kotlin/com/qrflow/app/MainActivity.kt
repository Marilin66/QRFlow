package com.qrflow.app

import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    companion object {
        private const val REQ_PROJECTION_CONSENT = 1002
    }

    private var screenCaptureChannel: ScreenCaptureChannel? = null

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
     * Demande le consentement de capture d'écran (MediaProjection). Appelé
     * par le canal natif quand l'utilisateur active la bulle. Le résultat est
     * traité dans [onActivityResult].
     */
    fun launchProjectionConsent() {
        val manager = getSystemService(MediaProjectionManager::class.java)
        startActivityForResult(manager.createScreenCaptureIntent(), REQ_PROJECTION_CONSENT)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_PROJECTION_CONSENT) {
            if (resultCode == RESULT_OK && data != null) {
                Log.i("QRFlow", "Consentement MediaProjection accordé")
                ScreenCaptureProjectionService.start(this, resultCode, data)
                BubbleService.start(this)
                getSharedPreferences(ScreenCaptureChannel.PREFS, MODE_PRIVATE)
                    .edit()
                    .putBoolean(ScreenCaptureChannel.KEY_BUBBLE_ACTIVE, true)
                    .putBoolean(ScreenCaptureChannel.KEY_PROJECTION_ACTIVE, true)
                    .apply()
            } else {
                Log.w("QRFlow", "Consentement MediaProjection refusé")
                recordCaptureError(
                    this,
                    "Autorisation de capture d'écran refusée. Réactivez la bulle pour réessayer."
                )
            }
        }
    }

    /**
     * Quand l'activité est relancée par la bulle flottante (action CAPTURE),
     * on prévient Flutter : la capture est en attente dans les préférences et
     * l'analyse peut démarrer immédiatement (même si l'app est au premier
     * plan, ce qui ne déclencherait aucun événement de cycle de vie).
     *
     * Au démarrage à froid, le signal peut être perdu (Dart pas encore prêt) :
     * Flutter consomme alors la capture en attente au démarrage / au retour au
     * premier plan, ce qui garantit le résultat dans tous les cas.
     */
    private fun handleCaptureIntent(intent: Intent?) {
        if (intent?.action == ScreenCaptureChannel.ACTION_CAPTURE) {
            val path = intent.getStringExtra(QRFlowAccessibilityService.EXTRA_PATH)
            intent.action = null
            Log.i("QRFlow", "Intent CAPTURE reçu, path=$path")
            screenCaptureChannel?.notifyCaptureReady(path)
        }
    }
}
