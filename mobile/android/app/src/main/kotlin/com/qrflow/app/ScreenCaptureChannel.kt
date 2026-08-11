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

/**
 * Canal MethodChannel entre Flutter et le code natif.
 *
 * Fournit : état des permissions, démarrage/arrêt de la bulle, déclenchement
 * de la capture, et récupération des captures / erreurs en attente.
 */
class ScreenCaptureChannel private constructor(
    private val activity: MainActivity,
    private val channel: MethodChannel,
) {
    companion object {
        const val CHANNEL = "com.qrflow.app/screen_capture"
        const val ACTION_CAPTURE = "com.qrflow.app.CAPTURE"
        const val PREFS = "qrflow_prefs"
        const val KEY_PENDING_CAPTURE = "pending_capture_path"
        const val KEY_LAST_CAPTURE_ERROR = "last_capture_error"
        const val KEY_BUBBLE_ACTIVE = "bubble_active"

        /** Méthode envoyée côté Dart quand une capture est prête. */
        const val METHOD_CAPTURE_READY = "captureReady"

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
                    // La capture via l'accessibilité nécessite Android 11+,
                    // la superposition et le service d'accessibilité activé.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                        Settings.canDrawOverlays(activity) &&
                        isAccessibilityServiceEnabled(activity)
                    ) {
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
                    // Capture directe via le service d'accessibilité
                    // (appelé quand l'app est au premier plan).
                    val service = QRFlowAccessibilityService.instance
                    if (service != null) {
                        service.captureScreenNow()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }

                "getPendingCapture" -> {
                    val path = prefs().getString(KEY_PENDING_CAPTURE, null)
                    if (path != null) {
                        prefs().edit().remove(KEY_PENDING_CAPTURE).apply()
                    }
                    result.success(path)
                }

                "getCaptureError" -> {
                    val error = prefs().getString(KEY_LAST_CAPTURE_ERROR, null)
                    if (error != null) {
                        prefs().edit().remove(KEY_LAST_CAPTURE_ERROR).apply()
                    }
                    result.success(error)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun prefs(): SharedPreferences =
        activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * Préviens Flutter qu'une capture vient d'être prise et est en attente.
     * Appelé par [MainActivity] quand l'intent [ACTION_CAPTURE] est reçu.
     */
    fun notifyCaptureReady(path: String?) {
        channel.invokeMethod(METHOD_CAPTURE_READY, path, null)
    }
}

/** Consigne une erreur de capture pour que Flutter puisse l'afficher. */
fun recordCaptureError(context: Context, message: String) {
    context.getSharedPreferences(ScreenCaptureChannel.PREFS, Context.MODE_PRIVATE)
        .edit()
        .putString(ScreenCaptureChannel.KEY_LAST_CAPTURE_ERROR, message)
        .apply()
}

/**
 * Sauvegarde la capture en attente puis ramène l'application au premier plan
 * pour que Flutter puisse l'analyser.
 */
fun deliverCaptureToFlutter(context: Context, path: String) {
    context.getSharedPreferences(ScreenCaptureChannel.PREFS, Context.MODE_PRIVATE)
        .edit()
        .putString(ScreenCaptureChannel.KEY_PENDING_CAPTURE, path)
        .apply()

    val intent = Intent(context, MainActivity::class.java).apply {
        action = ScreenCaptureChannel.ACTION_CAPTURE
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        putExtra(QRFlowAccessibilityService.EXTRA_PATH, path)
    }
    context.startActivity(intent)
}

/** Ramène l'application au premier plan (pour afficher un message). */
fun launchAppForFeedback(context: Context) {
    val intent = Intent(context, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
    }
    context.startActivity(intent)
}
