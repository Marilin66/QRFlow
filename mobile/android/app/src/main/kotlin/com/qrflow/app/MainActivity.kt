package com.qrflow.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    companion object {
        @Volatile
        var current: MainActivity? = null
            private set

        private const val REQ_OVERLAY = 1001
        private const val REQ_PROJECTION = 1002
        private const val REQ_NOTIFICATION = 1003
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ScreenCaptureChannel.attach(flutterEngine, this)
    }

    override fun onResume() {
        super.onResume()
        current = this
    }

    override fun onPause() {
        super.onPause()
        if (current === this) current = null
    }

    /** Démarre le Mode Flash : permission overlay puis consentement capture. */
    fun beginBubble() {
        if (!Settings.canDrawOverlays(this)) {
            startActivityForResult(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName"),
                ),
                REQ_OVERLAY,
            )
            return
        }
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIFICATION)
        }
        requestProjection()
    }

    private fun requestProjection() {
        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(manager.createScreenCaptureIntent(), REQ_PROJECTION)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQ_OVERLAY -> {
                if (Settings.canDrawOverlays(this)) requestProjection()
            }
            REQ_PROJECTION -> {
                if (resultCode == RESULT_OK && data != null) {
                    startFlashServices(resultCode, data)
                }
            }
        }
    }

    /**
     * Démarre les deux services avant-plan de la capture (MediaProjection)
     * et de la bulle. Toute exception — en particulier
     * ForegroundServiceStartNotAllowedException, lancée par Android 12+ quand
     * un service avant-plan démarre alors que l'application n'est pas
     * considérée comme étant au premier plan (et Android 15+, restriction
     * renforcée pour les apps tenant SYSTEM_ALERT_WINDOW) — est interceptée
     * et remontée à l'interface : un message clair plutôt qu'un crash
     * « QRFlow s'arrête systématiquement ».
     */
    private fun startFlashServices(resultCode: Int, data: Intent) {
        try {
            ScreenCaptureProjectionService.start(this, resultCode, data)
            BubbleService.requestStart(this)
        } catch (e: Exception) {
            ScreenCaptureChannel.notifyStartFailed(
                "Impossible de démarrer la bulle : Android l'a refusé car " +
                    "QRFlow n'était pas au premier plan. Réessayez depuis " +
                    "l'écran « Scanner l'écran ».",
            )
        }
    }
}
