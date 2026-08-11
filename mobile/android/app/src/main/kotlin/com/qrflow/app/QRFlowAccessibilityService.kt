package com.qrflow.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityService.ScreenshotResult
import android.accessibilityservice.AccessibilityService.TakeScreenshotCallback
import android.graphics.Bitmap
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Service d'accessibilité QRFlow — capture d'écran (Android 11+).
 *
 * Architecture sans point de rupture :
 *  - la bulle flottante appelle [captureScreenNow] DIRECTEMENT sur l'instance
 *    (même processus). Aucun broadcast, aucun receiver dynamique.
 *  - chaque capture est sauvegardée en PNG dans le cache puis remise à Flutter
 *    via [deliverCaptureToFlutter] (SharedPreferences + relance de l'activité).
 *  - toute erreur est consignée pour être affichée dans l'application.
 */
class QRFlowAccessibilityService : AccessibilityService() {

    companion object {
        const val EXTRA_PATH = "screenshot_path"

        private const val TAG = "QRFlowCapture"

        /** Délai minimum entre deux captures imposé par Android (~1 s). */
        private const val SCREENSHOT_INTERVAL_MS = 1100L

        /** Instance du service quand il est connecté (null sinon). */
        @Volatile
        var instance: QRFlowAccessibilityService? = null
            private set
    }

    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val captureInProgress = AtomicBoolean(false)
    @Volatile
    private var lastCaptureAt = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "Service d'accessibilité connecté")
    }

    override fun onDestroy() {
        instance = null
        ioExecutor.shutdown()
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Aucun événement exploité : le service ne sert qu'à la capture.
    }

    override fun onInterrupt() {}

    /** Capture l'écran maintenant. Appelé par la bulle ou le canal natif. */
    fun captureScreenNow() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            recordCaptureError(this, "La capture d'écran nécessite Android 11 ou plus.")
            return
        }
        if (!isConnected) {
            Log.e(TAG, "Service non connecté")
            recordCaptureError(
                this,
                "Le service de capture n'est pas connecté. Vérifiez que QRFlow est " +
                    "activé dans les paramètres d'accessibilité, puis réessayez."
            )
            return
        }
        if (!captureInProgress.compareAndSet(false, true)) {
            Log.w(TAG, "Une capture est déjà en cours")
            return
        }
        ioExecutor.execute {
            try {
                // Android rejette les captures plus rapprochées que ~1 s.
                val wait = SCREENSHOT_INTERVAL_MS - (System.currentTimeMillis() - lastCaptureAt)
                if (wait > 0) Thread.sleep(wait)

                takeScreenshot(
                    0,
                    ioExecutor,
                    object : TakeScreenshotCallback {
                        override fun onSuccess(result: ScreenshotResult) {
                            lastCaptureAt = System.currentTimeMillis()
                            handleScreenshot(result)
                        }

                        override fun onFailure(errorCode: Int) {
                            Log.e(TAG, "Échec de la capture d'écran (code $errorCode)")
                            recordCaptureError(
                                this@QRFlowAccessibilityService,
                                "Capture impossible (code $errorCode). Certaines applications " +
                                    "bloquent la capture (banque, DRM…). " +
                                    "Utilisez « Depuis une capture »."
                            )
                            captureInProgress.set(false)
                        }
                    }
                )
            } catch (e: Exception) {
                Log.e(TAG, "Erreur lors de takeScreenshot", e)
                recordCaptureError(
                    this@QRFlowAccessibilityService,
                    "Erreur lors de la capture : ${e.message}"
                )
                captureInProgress.set(false)
            }
        }
    }

    private fun handleScreenshot(result: ScreenshotResult) {
        try {
            val hardwareBitmap = Bitmap.wrapHardwareBuffer(result.hardwareBuffer, result.colorSpace)
                ?: throw IllegalStateException("wrapHardwareBuffer a retourné null")

            // Un bitmap « matériel » ne peut pas être compressé en PNG : on
            // copie d'abord les pixels dans un bitmap logiciel ARGB_8888.
            val bitmap = hardwareBitmap.copy(Bitmap.Config.ARGB_8888, false)
            hardwareBitmap.recycle()
            try {
                result.hardwareBuffer.close()
            } catch (_: Exception) {
                // Certains constructeurs ferment déjà le buffer.
            }

            val path = saveBitmap(bitmap)
            bitmap.recycle()
            Log.i(TAG, "Capture enregistrée : $path")
            deliverCaptureToFlutter(this, path)
        } catch (e: Exception) {
            Log.e(TAG, "Erreur lors du traitement de la capture", e)
            recordCaptureError(this, "Erreur lors du traitement de la capture.")
        } finally {
            captureInProgress.set(false)
        }
    }

    private fun saveBitmap(bitmap: Bitmap): String {
        val dir = File(cacheDir, "qrflow")
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, "capture_${System.currentTimeMillis()}.png")
        FileOutputStream(file).use { out ->
            val ok = bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            if (!ok) {
                Log.e(TAG, "compress() a échoué, le PNG peut être vide")
            }
        }
        return file.absolutePath
    }
}
