package com.qrflow.app

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class ScreenCaptureChannel private constructor(
    private val activity: MainActivity,
    private val channel: MethodChannel,
) {
    companion object {
        const val CHANNEL = "com.qrflow.app/screen_capture"
        const val ACTION_CAPTURE = "com.qrflow.app.CAPTURE"
        const val PREFS = "qrflow_prefs"
        const val KEY_PENDING_CAPTURE = "pending_capture_path"
        const val KEY_BUBBLE_ACTIVE = "bubble_active"

        fun register(engine: FlutterEngine, activity: MainActivity): ScreenCaptureChannel {
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            return ScreenCaptureChannel(activity, channel).also { it.attach() }
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val expectedComponentName = ComponentName(context, QRFlowAccessibilityService::class.java)
        val enabledServicesSetting = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledService = ComponentName.unflattenFromString(componentNameString)
            if (enabledService != null && enabledService == expectedComponentName) {
                return true
            }
        }
        return false
    }

    private fun attach() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPlatformState" -> result.success(
                    mapOf(
                        "isAndroid" to true,
                        "supported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R),
                        "overlayPermission" to Settings.canDrawOverlays(activity),
                        "accessibilityPermission" to isAccessibilityServiceEnabled(activity),
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

                "requestAccessibilityPermission" -> {
                    if (!isAccessibilityServiceEnabled(activity)) {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
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
                    if (Settings.canDrawOverlays(activity) && isAccessibilityServiceEnabled(activity)) {
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
                    val intent = Intent(QRFlowAccessibilityService.ACTION_TAKE_SCREENSHOT)
                    activity.sendBroadcast(intent)
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
}
