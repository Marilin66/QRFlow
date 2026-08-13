package com.qrflow.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.view.WindowManager
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Capture d'écran par MediaProjection (une seule confirmation par session).
 * Décodage ML Kit natif : le résultat est ensuite analysé côté Dart.
 *
 * Robustesse Android 14/15/16 :
 * - `startForeground` avec le type explicite `mediaProjection` ;
 * - les ressources de la session précédente sont libérées avant chaque
 *   nouvelle activation (Android 14+ interdit de rappeler
 *   `createVirtualDisplay` sur un MediaProjection déjà consommé) ;
 * - un `MediaProjection.Callback.onStop` libère tout quand le système met
 *   fin à la session (écran verrouillé, chip d'état…) ;
 * - aucune création de capture ne peut faire planter l'application : en cas
 *   d'échec, le service s'arrête proprement.
 */
class ScreenCaptureProjectionService : Service() {
    companion object {
        private const val CHANNEL_ID = "qrflow_capture"
        private const val NOTIFICATION_ID = 2

        private var instance: ScreenCaptureProjectionService? = null
        private var mediaProjection: MediaProjection? = null
        private var virtualDisplay: VirtualDisplay? = null
        private var imageReader: ImageReader? = null
        private var executor: ExecutorService? = null
        private var handler: Handler? = null

        fun start(context: Context, resultCode: Int, data: Intent) {
            val intent = Intent(context, ScreenCaptureProjectionService::class.java)
                .putExtra("resultCode", resultCode)
                .putExtra("data", data)
            context.startForegroundService(intent)
        }

        fun stop(context: Context?) {
            context?.stopService(Intent(context, ScreenCaptureProjectionService::class.java))
        }

        /** Capture la dernière image de l'écran et la décode (ML Kit). */
        fun captureNow(callback: (values: List<String>, failed: Boolean) -> Unit) {
            val service = instance ?: run { callback(emptyList(), true); return }
            val ex = executor ?: run { callback(emptyList(), true); return }
            ex.execute { service.scanLastFrame(callback) }
        }
    }

    // ── Cycle de vie du service avant-plan ──────────────────────────────

    override fun onCreate() {
        super.onCreate()
        instance = this
        handler = Handler(Looper.getMainLooper())
        executor = Executors.newSingleThreadExecutor()
        createChannel()
        startAsForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        val resultCode = intent?.getIntExtra("resultCode", 0) ?: 0
        @Suppress("DEPRECATION")
        val data = intent?.getParcelableExtra("data") as? Intent
        if (resultCode == 0 || data == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        // Nouvelle activation (consentement renouvelé) : on libère d'abord
        // la session précédente pour ne jamais réutiliser un MediaProjection
        // ou un VirtualDisplay déjà consommé (SecurityException sur
        // Android 14+).
        releaseCapture()
        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = manager.getMediaProjection(resultCode, data)
        mediaProjection?.registerCallback(projectionCallback, handler)
        setupVirtualDisplay()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseCapture()
        if (instance === this) instance = null
        super.onDestroy()
    }

    /** Libère la session de capture en cours (appelable plusieurs fois). */
    private fun releaseCapture() {
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        val projection = mediaProjection
        // Null avant stop() : onStop() (déclenché par stop()) ne peut pas
        // re-entrer dans releaseCapture().
        mediaProjection = null
        projection?.unregisterCallback(projectionCallback)
        projection?.stop()
    }

    // ── Arrêt externe de la session (verrouillage, chip d'état…) ────────

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            // La session a été terminée par le système : on libère tout et on
            // arrête aussi la bulle, devenue inutile sans capture.
            handler?.post {
                releaseCapture()
                BubbleService.requestStop(this@ScreenCaptureProjectionService)
                ScreenCaptureChannel.notifyProjectionStopped()
            }
        }
    }

    // ── Capture ─────────────────────────────────────────────────────────

    private fun scanLastFrame(callback: (values: List<String>, failed: Boolean) -> Unit) {
        val reader = imageReader
        if (reader == null) {
            handler?.post { callback(emptyList(), true) }
            return
        }
        val scanner = BarcodeScanning.getClient(
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                .build(),
        )
        val image = reader.acquireLatestImage()
        if (image == null) {
            scanner.close()
            handler?.post { callback(emptyList(), false) }
            return
        }
        val input = InputImage.fromMediaImage(image, 0)
        scanner.process(input)
            .addOnSuccessListener { barcodes ->
                val values = barcodes
                    .mapNotNull { it.rawValue ?: it.displayValue }
                    .filter { it.isNotBlank() }
                    .distinct()
                handler?.post { callback(values, false) }
            }
            .addOnFailureListener {
                handler?.post { callback(emptyList(), true) }
            }
            .addOnCompleteListener {
                image.close()
                scanner.close()
            }
    }

    private fun setupVirtualDisplay() {
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getRealMetrics(metrics)
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi

        imageReader = ImageReader.newInstance(width, height, android.graphics.PixelFormat.RGBA_8888, 2)
        val projection = mediaProjection
        if (projection == null) {
            stopSelf()
            return
        }
        try {
            virtualDisplay = projection.createVirtualDisplay(
                "QRFlowCapture",
                width, height, density,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                imageReader?.surface,
                null,
                null,
            )
        } catch (e: Exception) {
            // Session déjà consommée, écran verrouillé, permission retirée :
            // repli propre, jamais de crash.
            stopSelf()
        }
    }

    // ── Notification obligatoire (Android 8+) ───────────────────────────

    private fun startAsForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Capture QRFlow", NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    private fun buildNotification(): Notification {
        val openApp = Intent(this, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            this, 1, openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("QRFlow — capture prête")
            .setContentText("La bulle peut scanner l'écran.")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentIntent(pending)
            .setOngoing(true)
            .build()
    }
}
