package com.qrflow.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import androidx.core.content.ContextCompat
import androidx.core.app.NotificationCompat
import kotlin.math.abs

/**
 * Bulle flottante affichée par-dessus les autres applications.
 *
 * La bulle est déplaçable. Un appui sur la bulle lance [MainActivity] avec
 * l'action [ScreenCaptureChannel.ACTION_CAPTURE], ce qui déclenche le
 * consentement de capture d'écran puis l'analyse.
 *
 * Règles respectées :
 *  - permission SYSTEM_ALERT_WINDOW accordée par l'utilisateur ;
 *  - service au premier plan déclaré avec le type `specialUse` (Android 14+) ;
 *  - aucune action automatique : l'appui sur la bulle est nécessaire.
 */
class BubbleService : Service() {

    companion object {
        private const val CHANNEL_ID = "qrflow_bubble"
        private const val NOTIF_ID = 1
        private const val FGS_SPECIAL_USE = 0x40000000 // ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE

        fun start(context: Context) {
            val intent = Intent(context, BubbleService::class.java)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, BubbleService::class.java))
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var bubbleView: View? = null
    private var params: WindowManager.LayoutParams? = null

    private val showBubbleRunnable = object : Runnable {
        override fun run() {
            if (Settings.canDrawOverlays(this@BubbleService)) {
                showBubble()
            } else {
                stopSelf()
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundCompat()
        handler.removeCallbacks(showBubbleRunnable)
        handler.postDelayed(showBubbleRunnable, 300)
        return START_STICKY
    }

    private fun startForegroundCompat() {
        val notification = buildNotification(
            "Bulle QRFlow active",
            "Appuyez sur la bulle pour scanner un QR code affiché à l'écran.",
        )
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF_ID, notification, FGS_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    private fun showBubble() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val size = prefs.getFloat("flutter.bubble_size", 100f).toInt().coerceIn(56, 160)
        val opacity = prefs.getFloat("flutter.bubble_opacity", 0.90f).coerceIn(0.4f, 1f)

        val view = ImageView(this).apply {
            setImageResource(R.drawable.ic_bubble_logo)
            scaleType = ImageView.ScaleType.FIT_CENTER
            setPadding(12, 12, 12, 12)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.WHITE)
                setStroke(3, Color.parseColor("#2D3B8C"))
            }
            alpha = opacity
            elevation = 8f
            setOnTouchListener(dragListener)
            setOnClickListener {
                val intent = Intent(QRFlowAccessibilityService.ACTION_TAKE_SCREENSHOT)
                sendBroadcast(intent)
            }
        }

        params = WindowManager.LayoutParams(
            size,
            size,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 40
            y = 220
        }

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        try {
            windowManager?.addView(view, params)
            bubbleView = view
        } catch (e: Exception) {
            stopSelf()
        }
    }

    private val dragListener = object : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var touchX = 0f
        private var touchY = 0f
        private var moved = false

        override fun onTouch(v: View, e: MotionEvent): Boolean {
            val p = params ?: return false
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = p.x
                    startY = p.y
                    touchX = e.rawX
                    touchY = e.rawY
                    moved = false
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (e.rawX - touchX).toInt()
                    val dy = (e.rawY - touchY).toInt()
                    if (abs(dx) + abs(dy) > 8) moved = true
                    p.x = startX + dx
                    p.y = startY + dy
                    windowManager?.updateViewLayout(v, p)
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) v.performClick()
                    return true
                }
            }
            return false
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(showBubbleRunnable)
        bubbleView?.let { view ->
            try {
                windowManager?.removeView(view)
            } catch (_: Exception) {
                // Vue déjà retirée.
            }
        }
        bubbleView = null
        super.onDestroy()
    }

    // ── Notifications ────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Bulle QRFlow",
                    NotificationManager.IMPORTANCE_LOW,
                )
            )
        }
    }

    private fun buildNotification(title: String, text: String): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
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
}
