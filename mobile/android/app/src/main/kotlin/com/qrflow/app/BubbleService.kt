package com.qrflow.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView

/**
 * Bulle flottante (service au premier plan, notification obligatoire).
 * Déplaçable ; un appui déclenche la capture d'écran et l'overlay de
 * résultat — sans jamais quitter l'app en cours.
 */
class BubbleService : Service() {
    companion object {
        private const val CHANNEL_ID = "qrflow_bubble"
        private const val NOTIFICATION_ID = 1

        @Volatile
        var isActive = false
            private set

        private var bubbleView: FrameLayout? = null

        fun requestStart(context: Context) {
            context.startForegroundService(Intent(context, BubbleService::class.java))
        }

        fun requestStop(context: Context?) {
            context?.stopService(Intent(context, BubbleService::class.java))
        }
    }

    private var windowManager: WindowManager? = null
    private var params: WindowManager.LayoutParams? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        isActive = true
        if (Settings.canDrawOverlays(this)) addBubble()
    }

    override fun onDestroy() {
        removeBubble()
        isActive = false
        super.onDestroy()
    }

    // ── Notification obligatoire (Android 8+) ─────────────────────────────

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Bulle QRFlow",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.setShowBadge(false)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val openApp = Intent(this, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            this, 0, openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("QRFlow — bulle active")
            .setContentText("Touchez la bulle pour scanner l'écran.")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentIntent(pending)
            .setOngoing(true)
            .build()
    }

    // ── Bulle ─────────────────────────────────────────────────────────────

    private fun addBubble() {
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val size = dp(56)
        val lp = WindowManager.LayoutParams(
            size, size,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        )
        lp.gravity = Gravity.TOP or Gravity.START
        lp.x = dp(16)
        lp.y = dp(120)

        val view = FrameLayout(this)
        val icon = ImageView(this).apply {
            setImageDrawable(FinderMarkDrawable(dp(26).toFloat()))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#5B5FEF"))
                setStroke(dp(3), Color.WHITE)
            }
        }
        view.addView(
            icon,
            FrameLayout.LayoutParams(size, size, Gravity.CENTER).apply {
                setMargins(dp(6), dp(6), dp(6), dp(6))
            },
        )
        view.setOnClickListener { ScreenCaptureChannel.captureNow() }
        view.setOnTouchListener(BubbleTouchListener(lp, wm))

        wm.addView(view, lp)
        bubbleView = view
        windowManager = wm
        params = lp
    }

    private fun removeBubble() {
        val view = bubbleView ?: return
        runCatching { windowManager?.removeView(view) }
        bubbleView = null
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    /** Déplacement de la bulle ; un simple appui reste un clic. */
    private class BubbleTouchListener(
        private val params: WindowManager.LayoutParams,
        private val wm: WindowManager,
    ) : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var startRawX = 0f
        private var startRawY = 0f
        private var moved = false

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    startRawX = event.rawX
                    startRawY = event.rawY
                    moved = false
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - startRawX).toInt()
                    val dy = (event.rawY - startRawY).toInt()
                    if (kotlin.math.abs(dx) > 8 || kotlin.math.abs(dy) > 8) moved = true
                    params.x = startX + dx
                    params.y = startY + dy
                    runCatching { wm.updateViewLayout(view, params) }
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    // Un glissement n'est pas un clic ; un appui simple l'est.
                    if (!moved) view.performClick()
                    return true
                }
            }
            return false
        }
    }

    /** Les trois cornières du motif de détection QR — la signature QRFlow. */
    private class FinderMarkDrawable(private val stroke: Float) : Drawable() {
        private val paint = Paint().apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
            isAntiAlias = true
        }

        override fun draw(canvas: Canvas) {
            val s = bounds.width().toFloat()
            val arm = s * 0.34f
            val inset = stroke / 2f
            canvas.drawLine(inset, inset, inset + arm, inset, paint)
            canvas.drawLine(inset, inset, inset, inset + arm, paint)
            canvas.drawLine(s - inset, inset, s - inset - arm, inset, paint)
            canvas.drawLine(s - inset, inset, s - inset, inset + arm, paint)
            canvas.drawLine(inset, s - inset, inset + arm, s - inset, paint)
            canvas.drawLine(inset, s - inset, inset, s - inset - arm, paint)
        }

        override fun setAlpha(alpha: Int) {
            paint.alpha = alpha
        }

        override fun setColorFilter(colorFilter: ColorFilter?) {
            paint.colorFilter = colorFilter
        }

        @Deprecated("Deprecated in Java")
        override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
    }
}
