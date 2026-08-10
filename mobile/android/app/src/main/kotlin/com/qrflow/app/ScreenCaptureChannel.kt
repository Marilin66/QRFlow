package com.qrflow.app

import android.Manifest
import android.app.Activity
import android.app.Activity.RESULT_OK
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Pont entre Dart et le code natif Android.
 *
 * Canal : [CHANNEL]
 * Méthodes : getPlatformState, requestOverlayPermission, ensureNotificationPermission,
 * startBubble, stopBubble, captureScreen, getPendingCapture.
 */
class ScreenCaptureChannel private constructor(
    private val activity: MainActivity,
    private val channel: MethodChannel,
) {
    companion object {
        const val CHANNEL = "com.qrflow.app/screen_capture"

        /** Action lancée lorsque l'utilisateur appuie sur la bulle flottante. */
        const val ACTION_CAPTURE = "com.qrflow.app.CAPTURE"

        const val PREFS = "qrflow_prefs"
        const val KEY_PENDING_CAPTURE = "pending_capture_path"
        const val KEY_BUBBLE_ACTIVE = "bubble_active"

        fun register(engine: FlutterEngine, activity: MainActivity): ScreenCaptureChannel {
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            return ScreenCaptureChannel(activity, channel).also { it.attach() }
        }
    }

    private fun attach() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPlatformState" -> result.success(
                    mapOf(
                        "isAndroid" to true,
                        "supported" to true,
                        "overlayPermission" to Settings.canDrawOverlays(activity),
                        "bubbleActive" to prefs().getBoolean(KEY_BUBBLE_ACTIVE, false),
                    )
                )

                "requestOverlayPermission" -> {
                    if (!Settings.canDrawOverlays(activity)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:${activity.packageName}"),
                        )
                        activity.startActivity(intent)
                    }
                    result.success(null)
                }

                "ensureNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        val granted = activity.checkSelfPermission(
                            Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        if (!granted) {
                            activity.requestPermissions(
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                1001,
                            )
                        }
                    }
                    result.success(null)
                }

                "startBubble" -> {
                    if (Settings.canDrawOverlays(activity)) {
                        BubbleService.start(activity)
                        prefs().edit().putBoolean(KEY_BUBBLE_ACTIVE, true).apply()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }

                "stopBubble" -> {
                    BubbleService.stop(activity)
                    prefs().edit().putBoolean(KEY_BUBBLE_ACTIVE, false).apply()
                    result.success(null)
                }

                "captureScreen" -> {
                    if (ScreenCaptureService.isRunning) {
                        ScreenCaptureService.requestCaptureNow(activity)
                    } else {
                        activity.requestScreenCapture()
                    }
                    result.success(null)
                }

                "getPendingCapture" -> {
                    val path = prefs().getString(KEY_PENDING_CAPTURE, null)
                    if (path != null) {
                        prefs().edit().remove(KEY_PENDING_CAPTURE).apply()
                    }
                    result.success(path)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun prefs(): SharedPreferences =
        activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * Appelé par [MainActivity] quand l'utilisateur répond à la demande de
     * consentement MediaProjection.
     */
    fun onProjectionResult(resultCode: Int, data: Intent?) {
        if (resultCode == RESULT_OK && data != null) {
            ScreenCaptureService.start(activity, resultCode, data)
        }
        // Résultat refusé : on ne fait rien, l'interface propose le repli
        // vers l'import d'une capture.
    }
}
