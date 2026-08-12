package com.qrflow.app

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Capture d'écran par MediaProjection (méthode alternative, plus fiable que
 * le service d'accessibilité).
 *
 * Principe :
 *  - Le consentement MediaProjection est demandé UNE SEULE FOIS, au moment
 *    où l'utilisateur active la bulle (depuis QRFlow, au premier plan).
 *  - La projection reste active en arrière-plan (service foreground de type
 *    mediaProjection) tant que la bulle est active.
 *  - Un appui sur la bulle appelle [captureNow] : l'écran de l'AUTRE
 *    application est capturé instantanément via [ImageReader.acquireLatestImage]
 *    (aucun dialogue à chaque appui, aucun retour à QRFlow avant l'analyse).
 *  - Le bitmap est analysé en mémoire avec MLKit, puis livré à Flutter via
 *    le même canal que la méthode historique (prefs + intent).
 *
 * Android 14+ impose :
 *  - la permission FOREGROUND_SERVICE_MEDIA_PROJECTION,
 *  - foregroundServiceType="mediaProjection",
 *  - startForeground(mediaProjection) AVANT createVirtualDisplay().
 */
class ScreenCaptureProjectionService : Service() {

    companion object {
        const val CHANNEL_ID = "qrflow_projection"
        const val NOTIF_ID = 2

        private const val TAG = "QRFlowProjection"
        private const val EXTRA_RESULT_CODE = "result_code"
        private const val EXTRA_RESULT_DATA = "result_data"

        /** ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION (0x2). */
        private const val FGS_MEDIA_PROJECTION = 0x2

        /** Délai (ms) entre deux tentatives d'acquisition d'une frame. */
        private const val FRAME_RETRY_DELAY_MS = 150L
        private const val FRAME_MAX_ATTEMPTS = 5

        @Volatile
        var instance: ScreenCaptureProjectionService? = null
            private set

        fun start(context: Context, resultCode: Int, data: Intent) {
            val intent = Intent(context, ScreenCaptureProjectionService::class.java).apply {
                putExtra(EXTRA_RESULT_CODE, resultCode)
                putExtra(EXTRA_RESULT_DATA, data)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ScreenCaptureProjectionService::class.java))
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val captureInProgress = AtomicBoolean(false)

    private var mediaProjection: MediaProjection? = null
    private var imageReader: ImageReader? = null
    private var virtualDisplay: VirtualDisplay? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundCompat()
        if (mediaProjection == null) {
            val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
                ?: Activity.RESULT_CANCELED
            val data = getParcelableExtraCompat(intent)
            if (resultCode != Activity.RESULT_OK || data == null) {
                Log.w(TAG, "Consentement absent : arrêt du service")
                stopSelf()
                return START_NOT_STICKY
            }
            setupProjection(resultCode, data)
        }
        return START_STICKY
    }

    private fun getParcelableExtraCompat(intent: Intent?): Intent? {
        if (intent == null || !intent.hasExtra(EXTRA_RESULT_DATA)) return null
        return if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(EXTRA_RESULT_DATA)
        }
    }

    private fun setupProjection(resultCode: Int, data: Intent) {
        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val projection = manager.getMediaProjection(resultCode, data)
        if (projection == null) {
            Log.e(TAG, "getMediaProjection a retourné null")
            recordCaptureError(this, "Impossible de démarrer la capture d'écran. Réessayez.")
            stopSelf()
            return
        }

        mediaProjection = projection
        instance = this

        // Android 14+ : startForeground(mediaProjection) doit précéder
        // createVirtualDisplay, sinon SecurityException.
        startForegroundCompat()

        projection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                Log.w(TAG, "Projection arrêtée par le système ou l'utilisateur")
                recordCaptureError(
                    applicationContext,
                    "La capture d'écran a été arrêtée. Désactivez puis réactivez la bulle."
                )
                stopSelf()
            }
        }, mainHandler)

        val metrics = screenMetrics()
        val reader = ImageReader.newInstance(
            metrics.widthPixels,
            metrics.heightPixels,
            PixelFormat.RGBA_8888,
            2,
        )
        imageReader = reader

        try {
            virtualDisplay = projection.createVirtualDisplay(
                "qrflow_capture",
                metrics.widthPixels,
                metrics.heightPixels,
                metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                reader.surface,
                null,
                mainHandler,
            )
            Log.i(TAG, "Projection prête (${metrics.widthPixels}x${metrics.heightPixels})")
        } catch (e: SecurityException) {
            Log.e(TAG, "createVirtualDisplay refusé (SecurityException)", e)
            recordCaptureError(this, "Capture d'écran refusée par le système.")
            stopSelf()
        } catch (e: Exception) {
            Log.e(TAG, "createVirtualDisplay a échoué", e)
            recordCaptureError(this, "Impossible de démarrer la capture d'écran.")
            stopSelf()
        }
    }

    private fun screenMetrics(): DisplayMetrics {
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        wm.defaultDisplay.getRealMetrics(metrics)
        return metrics
    }

    /**
     * Point d'entrée appelé par la bulle : capture l'écran courant
     * (l'AUTRE application est encore visible) et analyse le bitmap.
     */
    fun captureNow() {
        val reader = imageReader
        if (reader == null) {
            Log.w(TAG, "captureNow appelé avant que la projection soit prête")
            recordCaptureError(this, "La capture d'écran n'est pas prête. Réessayez.")
            launchAppForFeedback(this)
            return
        }
        if (!captureInProgress.compareAndSet(false, true)) {
            Log.w(TAG, "Une capture est déjà en cours")
            return
        }

        executor.execute {
            try {
                var image = reader.acquireLatestImage()
                var attempts = 0
                while (image == null && attempts < FRAME_MAX_ATTEMPTS) {
                    Thread.sleep(FRAME_RETRY_DELAY_MS)
                    image = reader.acquireLatestImage()
                    attempts++
                }
                if (image == null) {
                    recordCaptureError(this, "Aucune image d'écran disponible. Réessayez.")
                    launchAppForFeedback(this)
                    return@execute
                }
                val bitmap = imageToBitmap(image)
                image.close()
                analyzeBitmapAndDeliver(this, bitmap)
            } catch (e: Exception) {
                Log.e(TAG, "Erreur lors de la capture", e)
                recordCaptureError(this, "Erreur lors de la capture d'écran.")
                launchAppForFeedback(this)
            } finally {
                captureInProgress.set(false)
            }
        }
    }

    private fun imageToBitmap(image: Image): Bitmap {
        val plane = image.planes[0]
        val buffer = plane.buffer
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val rowPadding = rowStride - pixelStride * image.width
        val padded = Bitmap.createBitmap(
            image.width + rowPadding / pixelStride,
            image.height,
            Bitmap.Config.ARGB_8888,
        )
        padded.copyPixelsFromBuffer(buffer)
        return if (rowPadding > 0) {
            Bitmap.createBitmap(padded, 0, 0, image.width, image.height)
        } else {
            padded
        }
    }

    override fun onDestroy() {
        Log.i(TAG, "Service de capture arrêté")
        instance = null
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        mediaProjection?.stop()
        mediaProjection = null
        executor.shutdown()
        super.onDestroy()
    }

    // ── Notification foreground ───────────────────────────────────────

    private fun startForegroundCompat() {
        val notification = buildNotification(
            "Scan d'écran QRFlow actif",
            "Appuyez sur la bulle pour scanner un QR code affiché à l'écran.",
        )
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIF_ID, notification, FGS_MEDIA_PROJECTION)
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    private fun buildNotification(title: String, text: String): Notification {
        createNotificationChannel()
        val contentIntent = PendingIntent.getActivity(
            this,
            1,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Capture d'écran QRFlow",
                    NotificationManager.IMPORTANCE_LOW,
                )
            )
        }
    }
}

/** Vérifie si un bitmap est (quasi) entièrement noir : capture bloquée. */
fun isBitmapBlack(bitmap: Bitmap): Boolean {
    val w = bitmap.width
    val h = bitmap.height
    if (w == 0 || h == 0) return true
    var darkCount = 0
    val sampleCount = 100
    for (i in 0 until sampleCount) {
        val x = (w.toLong() * i / sampleCount).toInt().coerceIn(0, w - 1)
        val y = (h.toLong() * i / sampleCount).toInt().coerceIn(0, h - 1)
        val pixel = bitmap.getPixel(x, y)
        val r = (pixel shr 16) and 0xFF
        val g = (pixel shr 8) and 0xFF
        val b = pixel and 0xFF
        if (r < 10 && g < 10 && b < 10) darkCount++
    }
    return darkCount > sampleCount * 0.9
}

/**
 * Analyse un bitmap avec MLKit et le livre à Flutter :
 * QR trouvés → livraison directe des valeurs ; sinon → sauvegarde PNG et
 * livraison du chemin pour analyse Flutter (repli).
 */
fun analyzeBitmapAndDeliver(context: Context, bitmap: Bitmap) {
    if (isBitmapBlack(bitmap)) {
        bitmap.recycle()
        recordCaptureError(
            context,
            "La capture est noire. L'application cible bloque les captures d'écran " +
                "(banque, DRM…). Faites une capture classique et importez-la."
        )
        launchAppForFeedback(context)
        return
    }

    val inputImage = InputImage.fromBitmap(bitmap, 0)
    val scanner = BarcodeScanning.getClient()
    try {
        scanner.process(inputImage)
            .addOnSuccessListener { barcodes ->
                val qrValues = barcodes.mapNotNull { it.rawValue?.takeIf { v -> v.isNotBlank() } }
                if (qrValues.isNotEmpty()) {
                    bitmap.recycle()
                    deliverTextCandidatesToFlutter(context, qrValues)
                } else {
                    val path = saveBitmapPng(context, bitmap)
                    bitmap.recycle()
                    deliverCaptureToFlutter(context, path)
                }
            }
            .addOnFailureListener { e ->
                Log.e("QRFlowProjection", "MLKit a échoué", e)
                val path = saveBitmapPng(context, bitmap)
                bitmap.recycle()
                deliverCaptureToFlutter(context, path)
            }
    } catch (e: Exception) {
        Log.e("QRFlowProjection", "MLKit process a échoué", e)
        val path = saveBitmapPng(context, bitmap)
        bitmap.recycle()
        deliverCaptureToFlutter(context, path)
    }
}

/** Sauvegarde un bitmap en PNG dans le cache de l'application. */
fun saveBitmapPng(context: Context, bitmap: Bitmap): String {
    val dir = File(context.cacheDir, "qrflow")
    if (!dir.exists()) dir.mkdirs()
    val file = File(dir, "capture_${System.currentTimeMillis()}.png")
    FileOutputStream(file).use { out ->
        val ok = bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        if (!ok) Log.e("QRFlowProjection", "compress() a échoué, PNG peut être vide")
    }
    return file.absolutePath
}
