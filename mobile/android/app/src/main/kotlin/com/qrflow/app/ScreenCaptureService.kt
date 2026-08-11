package com.qrflow.app

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.WindowManager
import androidx.core.app.NotificationCompat

/**
 * Service au premier plan qui capture l'écran via MediaProjection.
 *
 * Flux (respectant l'ordre exigé par Android 14+) :
 *  1. L'utilisateur donne son consentement (intent système) ;
 *  2. le service au premier plan de type `mediaProjection` démarre ;
 *  3. le VirtualDisplay est créé à partir du jeton obtenu ;
 *  4. une image est capturée, enregistrée en PNG et son chemin est placé
 *     dans les préférences pour être récupéré par Flutter.
 *
 * Note Android 14 : le jeton MediaProjection est à usage unique. Le service
 * reste actif avec un VirtualDisplay persistant ; chaque nouvel appui sur la
 * bulle capture une nouvelle image sans redemander le consentement tant que
 * le service est vivant.
 */
class ScreenCaptureService : Service() {

    companion object {
        private const val CHANNEL_ID = "qrflow_capture"
        private const val NOTIF_ID = 2

        private const val ACTION_START = "com.qrflow.app.START_CAPTURE"
        private const val ACTION_CAPTURE_NOW = "com.qrflow.app.CAPTURE_NOW"
        private const val EXTRA_RESULT_CODE = "result_code"
        private const val EXTRA_RESULT_DATA = "result_data"

        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context, resultCode: Int, data: Intent) {
            val intent = Intent(context, ScreenCaptureService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_RESULT_CODE, resultCode)
                putExtra(EXTRA_RESULT_DATA, data)
            }
            androidx.core.content.ContextCompat.startForegroundService(context, intent)
        }

        fun requestCaptureNow(context: Context) {
            val intent = Intent(context, ScreenCaptureService::class.java).apply {
                action = ACTION_CAPTURE_NOW
            }
            context.startService(intent)
        }
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CAPTURE_NOW) {
            captureFrame()
            return START_NOT_STICKY
        }

        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
            ?: Activity.RESULT_CANCELED
        @Suppress("DEPRECATION")
        val data: Intent? = intent?.getParcelableExtra(EXTRA_RESULT_DATA)

        if (resultCode != Activity.RESULT_OK || data == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        // Ordre exigé par Android 14 : consentement puis service au premier plan.
        startForegroundCompat()

        val mpm = getSystemService(MediaProjectionManager::class.java)
        val projection = mpm.getMediaProjection(resultCode, data)
        if (projection == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        mediaProjection = projection
        projection.registerCallback(
            object : MediaProjection.Callback() {
                override fun onStop() {
                    stopSelf()
                }
            },
            mainHandler,
        )

        setupVirtualDisplay(projection)
        captureFrame()
        isRunning = true
        return START_STICKY
    }

    private fun setupVirtualDisplay(projection: MediaProjection) {
        val bounds = displayBounds()
        val width = bounds.width()
        val height = bounds.height()
        val density = resources.displayMetrics.densityDpi

        val reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        imageReader = reader

        @Suppress("DEPRECATION")
        virtualDisplay = projection.createVirtualDisplay(
            "QRFlowCapture",
            width,
            height,
            density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            reader.surface,
            null,
            null,
        )
    }

    private fun displayBounds(): Rect {
        if (Build.VERSION.SDK_INT >= 30) {
            val wm = getSystemService(WindowManager::class.java)
            return wm.currentWindowMetrics.bounds
        }
        @Suppress("DEPRECATION")
        val dm = resources.displayMetrics
        return Rect(0, 0, dm.widthPixels, dm.heightPixels)
    }

    /** Capture une image depuis le VirtualDisplay et l'enregistre en PNG. */
    private fun captureFrame() {
        val reader = imageReader ?: return
        
        // Petit délai pour s'assurer que le contenu est bien rendu
        mainHandler.postDelayed({
            val image = reader.acquireLatestImage() ?: return@postDelayed
            try {
                val plane = image.planes[0]
                val buffer = plane.buffer
                val pixelStride = plane.pixelStride
                val rowStride = plane.rowStride
                val rowPadding = rowStride - pixelStride * image.width

                val bitmap = Bitmap.createBitmap(
                    image.width + rowPadding / pixelStride,
                    image.height,
                    Bitmap.Config.ARGB_8888,
                )
                bitmap.copyPixelsFromBuffer(buffer)
                val crop = Bitmap.createBitmap(bitmap, 0, 0, image.width, image.height)
                bitmap.recycle()

                savePng(crop)
                crop.recycle()
            } catch (e: Exception) {
                android.util.Log.e("ScreenCaptureService", "Erreur capture: ${e.message}", e)
            } finally {
                image.close()
            }
        }, 200) // Délai de 200ms pour garantir le rendu
    }

    private fun savePng(bitmap: Bitmap) {
        try {
            val dir = java.io.File(cacheDir, "qrflow")
            if (!dir.exists()) dir.mkdirs()
            val file = java.io.File(dir, "capture_${System.currentTimeMillis()}.png")
            file.outputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
            val path = file.absolutePath
            android.util.Log.d("ScreenCaptureService", "Capture enregistrée: $path")
            
            getSharedPreferences(ScreenCaptureChannel.PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(ScreenCaptureChannel.KEY_PENDING_CAPTURE, path)
                .apply()
                
            android.util.Log.d("ScreenCaptureService", "Chemin enregistré dans SharedPreferences")
        } catch (e: Exception) {
            android.util.Log.e("ScreenCaptureService", "Erreur sauvegarde: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        isRunning = false
        virtualDisplay?.release()
        imageReader?.close()
        mediaProjection?.stop()
        virtualDisplay = null
        imageReader = null
        mediaProjection = null
        super.onDestroy()
    }

    // ── Notifications ────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Capture d'écran",
                    NotificationManager.IMPORTANCE_LOW,
                )
            )
        }
    }

    private fun startForegroundCompat() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(
                NOTIF_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            1,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentTitle("Capture d'écran active")
            .setContentText("QRFlow analyse le QR code affiché à l'écran.")
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .build()
    }
}
