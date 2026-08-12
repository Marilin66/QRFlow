package com.qrflow.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
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

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        handler = Handler(Looper.getMainLooper())
        executor = Executors.newSingleThreadExecutor()
        createChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
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
        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = manager.getMediaProjection(resultCode, data)
        setupVirtualDisplay()
        return START_NOT_STICKY
    }

    private fun setupVirtualDisplay() {
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        wm.defaultDisplay.getRealMetrics(metrics)
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi

        imageReader = ImageReader.newInstance(width, height, android.graphics.PixelFormat.RGBA_8888, 2)
        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "QRFlowCapture",
            width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            null,
        )
    }

    override fun onDestroy() {
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        mediaProjection?.stop()
        mediaProjection = null
        executor?.shutdown()
        executor = null
        if (instance === this) instance = null
        super.onDestroy()
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
