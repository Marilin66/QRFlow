package com.qrflow.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityService.ScreenshotResult
import android.accessibilityservice.AccessibilityService.TakeScreenshotCallback
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Service d'accessibilité utilisé pour la capture d'écran (Android 11+).
 *
 * La bulle flottante envoie un broadcast [ACTION_TAKE_SCREENSHOT] ; ce service
 * prend alors une capture via `AccessibilityService.takeScreenshot()`, la
 * sauvegarde en PNG dans le cache, puis relance l'activité principale pour que
 * Flutter analyse l'image.
 */
class QRFlowAccessibilityService : AccessibilityService() {

    companion object {
        const val ACTION_TAKE_SCREENSHOT = "com.qrflow.app.ACTION_TAKE_SCREENSHOT"
        const val EXTRA_PATH = "screenshot_path"

        private const val TAG = "QRFlowCapture"
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_TAKE_SCREENSHOT) {
                takeScreenshotAndProcess()
            }
        }
    }

    // La compression PNG d'une capture pleine écran peut prendre quelques
    // centaines de ms : on l'exécute hors du thread principal.
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    override fun onServiceConnected() {
        super.onServiceConnected()
        val filter = IntentFilter(ACTION_TAKE_SCREENSHOT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
        Log.d(TAG, "Service d'accessibilité connecté")
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(receiver)
        } catch (_: Exception) {
            // Déjà désenregistré.
        }
        ioExecutor.shutdown()
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Non utilisé, on s'en sert uniquement pour la capture d'écran.
    }

    override fun onInterrupt() {}

    private fun takeScreenshotAndProcess() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            Log.e(TAG, "Capture impossible : Android 11+ requis")
            recordCaptureError("La capture d'écran nécessite Android 11 ou plus.")
            return
        }
        try {
            takeScreenshot(
                0,
                ioExecutor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(screenshot: ScreenshotResult) {
                        handleScreenshot(screenshot)
                    }

                    override fun onFailure(errorCode: Int) {
                        Log.e(TAG, "Échec de la capture d'écran (code $errorCode)")
                        recordCaptureError(
                            "Capture impossible (code $errorCode). " +
                                "Certaines applications bloquent la capture d'écran " +
                                "(banque, DRM…). Utilisez « Depuis une capture »."
                        )
                    }
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "Erreur lors de takeScreenshot", e)
            recordCaptureError("Erreur lors de la capture : ${e.message}")
        }
    }

    private fun handleScreenshot(screenshot: ScreenshotResult) {
        try {
            val hardwareBitmap = Bitmap.wrapHardwareBuffer(
                screenshot.hardwareBuffer,
                screenshot.colorSpace
            ) ?: run {
                Log.e(TAG, "wrapHardwareBuffer a retourné null")
                recordCaptureError("Impossible de lire la capture d'écran.")
                return
            }

            // Les bitmaps « matériels » ne peuvent pas être compressés en PNG
            // (compress() échoue silencieusement ou lève une exception). On
            // copie d'abord les pixels dans un bitmap logiciel classique.
            val bitmap = hardwareBitmap.copy(Bitmap.Config.ARGB_8888, false)
            hardwareBitmap.recycle()

            try {
                screenshot.hardwareBuffer.close()
            } catch (_: Exception) {
                // Certains constructeurs ferment le buffer eux-mêmes.
            }

            val path = saveBitmap(bitmap)
            bitmap.recycle()
            Log.d(TAG, "Capture enregistrée : $path")
            launchFlutterActivity(path)
        } catch (e: Exception) {
            Log.e(TAG, "Erreur lors du traitement de la capture", e)
            recordCaptureError("Erreur lors du traitement de la capture.")
        }
    }

    private fun saveBitmap(bitmap: Bitmap): String {
        val dir = File(cacheDir, "qrflow")
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, "capture_${System.currentTimeMillis()}.png")
        FileOutputStream(file).use { out ->
            val ok = bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            if (!ok) {
                Log.e(TAG, "compress() a échoué, le fichier PNG risque d'être vide")
            }
        }
        return file.absolutePath
    }

    /** Consigne une erreur de capture pour que Flutter puisse l'afficher. */
    private fun recordCaptureError(message: String) {
        getSharedPreferences(ScreenCaptureChannel.PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(ScreenCaptureChannel.KEY_LAST_CAPTURE_ERROR, message)
            .apply()
    }

    private fun launchFlutterActivity(path: String) {
        getSharedPreferences(ScreenCaptureChannel.PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(ScreenCaptureChannel.KEY_PENDING_CAPTURE, path)
            .apply()

        val intent = Intent(this, MainActivity::class.java).apply {
            action = ScreenCaptureChannel.ACTION_CAPTURE
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_PATH, path)
        }
        startActivity(intent)
    }
}
