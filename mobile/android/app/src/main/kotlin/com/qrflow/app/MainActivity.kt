package com.qrflow.app

import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var screenCaptureChannel: ScreenCaptureChannel? = null

    /**
     * Résultat du consentement MediaProjection demandé à l'activation de la
     * bulle. S'il est accordé, on démarre le service de capture par
     * projection + la bulle flottante.
     */
    private val projectionLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val data = result.data
        if (result.resultCode == RESULT_OK && data != null) {
            Log.i("QRFlow", "Consentement MediaProjection accordé")
            ScreenCaptureProjectionService.start(this, result.resultCode, data)
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
     * traité dans [projectionLauncher].
     */
    fun launchProjectionConsent() {
        val manager = getSystemService(MediaProjectionManager::class.java)
        projectionLauncher.launch(manager.createScreenCaptureIntent())
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
