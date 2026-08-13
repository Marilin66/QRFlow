package com.qrflow.app

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Pont natif du Mode Flash. Les contenus décodés par la bulle sont analysés
 * côté Dart (source unique de vérité) via [ANALYZE_METHOD] ; l'overlay de
 * résultat n'est affiché que si le moteur Flutter répond. Sinon, repli :
 * ouverture de QRFlow au premier plan.
 */
object ScreenCaptureChannel {
    private const val CHANNEL = "qrflow/screen_capture"
    private const val ANALYZE_METHOD = "prepareOverlayResult"
    private const val OPEN_IN_APP = "openInApp"
    private const val START_FAILED = "startBubbleFailed"
    private const val PROJECTION_STOPPED = "projectionStopped"

    private var channel: MethodChannel? = null
    private var context: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun attach(engine: FlutterEngine, context: Context) {
        this.context = context.applicationContext
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result -> onMethodCall(call, result) }
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startBubble" -> {
                MainActivity.current?.beginBubble()
                result.success(true)
            }
            "stopBubble" -> {
                BubbleService.requestStop(context)
                ScreenCaptureProjectionService.stop(context)
                result.success(true)
            }
            "isBubbleActive" -> result.success(BubbleService.isActive)
            else -> result.notImplemented()
        }
    }

    /** Appelé par la bulle : capture, décode, puis route vers l'overlay. */
    fun captureNow() {
        ScreenCaptureProjectionService.captureNow { values, failed ->
            if (failed) {
                deliverToFlutter(emptyList())
                return@captureNow
            }
            if (values.isEmpty()) {
                deliverToFlutter(emptyList())
                return@captureNow
            }
            analyzeForOverlay(values)
        }
    }

    /** Analyse côté Dart ; si le moteur répond, affiche l'overlay natif. */
    private fun analyzeForOverlay(values: List<String>) {
        val ch = channel ?: run { deliverToFlutter(values); return }
        mainHandler.post {
            ch.invokeMethod(
                ANALYZE_METHOD,
                values,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        @Suppress("UNCHECKED_CAST")
                        val payloads = result as? List<Map<String, Any?>>
                        if (payloads != null && payloads.isNotEmpty()) {
                            ResultOverlay.show(context, payloads)
                        } else {
                            deliverToFlutter(values)
                        }
                    }

                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?,
                    ) {
                        deliverToFlutter(values)
                    }

                    override fun notImplemented() {
                        deliverToFlutter(values)
                    }
                },
            )
        }
    }

    /** Préviens Dart d'un échec de démarrage (message clair, pas de crash). */
    fun notifyStartFailed(message: String) {
        val ch = channel ?: return
        mainHandler.post { ch.invokeMethod(START_FAILED, message) }
    }

    /** La session MediaProjection a été arrêtée par le système. */
    fun notifyProjectionStopped() {
        val ch = channel ?: return
        mainHandler.post { ch.invokeMethod(PROJECTION_STOPPED, null) }
    }

    /** Repli ou « Voir dans QRFlow » : ouvre QRFlow et livre le contenu. */
    fun deliverToFlutter(values: List<String>) {
        val ctx = context ?: return
        BubbleService.requestStop(ctx)
        ScreenCaptureProjectionService.stop(ctx)
        val intent = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            ?: return
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
        )
        ctx.startActivity(intent)
        if (values.isEmpty()) {
            openInApp("")
        } else {
            openInApp(values.first())
        }
    }

    fun openInApp(raw: String) {
        val ch = channel ?: return
        mainHandler.post { ch.invokeMethod(OPEN_IN_APP, raw) }
    }
}
