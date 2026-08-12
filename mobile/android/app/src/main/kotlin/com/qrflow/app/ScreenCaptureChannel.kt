package com.qrflow.app

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import org.json.JSONArray
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
        const val KEY_PROJECTION_ACTIVE = "projection_active"
        const val KEY_PENDING_TEXT_CANDIDATES = "pending_text_candidates"
        const val KEY_FROM_OVERLAY = "from_overlay"

        /** Méthode envoyée côté Dart quand une capture est prête. */
        const val METHOD_CAPTURE_READY = "captureReady"

        /** Méthode Dart appelée pour produire le payload de la carte overlay. */
        const val METHOD_PREPARE_OVERLAY_RESULT = "prepareOverlayResult"

        /** Délai avant repli si Dart ne répond pas (moteur Flutter arrêté). */
        private const val OVERLAY_ANALYSIS_TIMEOUT_MS = 2000L

        /**
         * Instance vivante tant que MainActivity (et son moteur Flutter)
         * existent : c'est le test de disponibilité de Dart pour l'overlay.
         */
        @Volatile
        var instance: ScreenCaptureChannel? = null
            private set

        fun register(engine: FlutterEngine, activity: MainActivity): ScreenCaptureChannel {
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            return ScreenCaptureChannel(activity, channel).also {
                instance = it
                it.attach()
            }
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

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
                        // La capture MediaProjection fonctionne dès API 21 ;
                        // l'accessibilité (repli) reste limitée à Android 11+.
                        "supported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP),
                        "overlayPermission" to Settings.canDrawOverlays(activity),
                        "accessibilityPermission" to isAccessibilityServiceEnabled(activity),
                        "bubbleActive" to prefs().getBoolean(KEY_BUBBLE_ACTIVE, false),
                        "projectionActive" to prefs().getBoolean(KEY_PROJECTION_ACTIVE, false),
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
                    // Nouvelle méthode : la superposition est requise, puis
                    // le consentement MediaProjection est demandé UNE FOIS
                    // (depuis QRFlow, au premier plan). Le service de capture
                    // démarre à la réception du résultat (MainActivity).
                    // L'accessibilité n'est plus requise.
                    // On ne considère la bulle comme active que si le service
                    // de capture tourne réellement : un flag périmé (mise à
                    // jour depuis l'ancienne version, processus tué) doit
                    // déclencher à nouveau le consentement.
                    val bubbleReallyActive = prefs().getBoolean(KEY_BUBBLE_ACTIVE, false) &&
                        ScreenCaptureProjectionService.instance != null
                    if (!Settings.canDrawOverlays(activity)) {
                        result.success(false)
                    } else if (bubbleReallyActive) {
                        result.success(true)
                    } else {
                        activity.launchProjectionConsent()
                        result.success(true)
                    }
                }

                "stopBubble" -> {
                    BubbleService.stop(activity)
                    ScreenCaptureProjectionService.stop(activity)
                    prefs().edit()
                        .putBoolean(KEY_BUBBLE_ACTIVE, false)
                        .putBoolean(KEY_PROJECTION_ACTIVE, false)
                        .apply()
                    result.success(null)
                }

                "captureScreen" -> {
                    // Capture via la projection MediaProjection d'abord
                    // (fiable), repli sur le service d'accessibilité sinon.
                    val projection = ScreenCaptureProjectionService.instance
                    if (projection != null) {
                        projection.captureNow()
                        result.success(true)
                    } else {
                        val service = QRFlowAccessibilityService.instance
                        if (service != null) {
                            service.scanScreenNow()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
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

                "getPendingTextCandidates" -> {
                    val json = prefs().getString(KEY_PENDING_TEXT_CANDIDATES, null)
                    if (json != null) {
                        prefs().edit().remove(KEY_PENDING_TEXT_CANDIDATES).apply()
                    }
                    val list = mutableListOf<String>()
                    if (json != null) {
                        try {
                            val arr = JSONArray(json)
                            for (i in 0 until arr.length()) list.add(arr.getString(i))
                        } catch (_: Exception) {
                            // Valeur corrompue : ignorée.
                        }
                    }
                    result.success(list)
                }

                "getFromOverlayFlag" -> {
                    val flag = prefs().getBoolean(KEY_FROM_OVERLAY, false)
                    if (flag) {
                        prefs().edit().remove(KEY_FROM_OVERLAY).apply()
                    }
                    result.success(flag)
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

    /**
     * Demande à Dart d'analyser les contenus décodés et de produire les
     * payloads de la carte overlay (Mode Flash).
     *
     * Doit être appelé sur le thread principal. Si Dart ne répond pas dans
     * un délai raisonnable (moteur arrêté), [callback] reçoit null : l'appelant
     * replie alors sur la livraison classique à Flutter (aucun résultat perdu).
     */
    fun analyzeForOverlay(candidates: List<String>, callback: (List<Map<String, Any?>>?) -> Unit) {
        val timeout = Runnable { callback(null) }
        mainHandler.post {
            mainHandler.postDelayed(timeout, OVERLAY_ANALYSIS_TIMEOUT_MS)
            channel.invokeMethod(
                METHOD_PREPARE_OVERLAY_RESULT,
                candidates,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        mainHandler.removeCallbacks(timeout)
                        @Suppress("UNCHECKED_CAST")
                        val list = result as? List<Map<String, Any?>>
                            ?: emptyList<Map<String, Any?>>()
                        callback(if (list.isEmpty()) null else list)
                    }

                    override fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
                        mainHandler.removeCallbacks(timeout)
                        callback(null)
                    }

                    override fun notImplemented() {
                        mainHandler.removeCallbacks(timeout)
                        callback(null)
                    }
                },
            )
        }
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

/**
 * Sauvegarde les contenus textuels lus directement à l'écran (sans capture)
 * puis ramène l'application au premier plan pour les proposer à l'utilisateur.
 */
fun deliverTextCandidatesToFlutter(context: Context, texts: List<String>) {
    val json = JSONArray().apply {
        texts.forEach { put(it) }
    }.toString()
    context.getSharedPreferences(ScreenCaptureChannel.PREFS, Context.MODE_PRIVATE)
        .edit()
        .putString(ScreenCaptureChannel.KEY_PENDING_TEXT_CANDIDATES, json)
        .apply()

    val intent = Intent(context, MainActivity::class.java).apply {
        action = ScreenCaptureChannel.ACTION_CAPTURE
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
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
