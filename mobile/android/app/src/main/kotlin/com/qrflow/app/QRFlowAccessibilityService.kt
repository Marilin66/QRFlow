package com.qrflow.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityService.ScreenshotResult
import android.accessibilityservice.AccessibilityService.TakeScreenshotCallback
import android.graphics.Bitmap
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import java.io.File
import java.io.FileOutputStream
import java.util.ArrayDeque
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Service d'accessibilité QRFlow.
 *
 * Stratégie de scan (appelé depuis la bulle PENDANT que l'autre app est visible) :
 *
 *  1. Lecture directe de l'arbre d'accessibilité : aucune capture d'écran,
 *     instantané. Si des contenus QR plausibles sont trouvés → livraison directe.
 *  2. Si l'arbre ne contient rien d'exploitable : capture d'écran via
 *     AccessibilityService.takeScreenshot() — l'écran de l'autre app est ENCORE
 *     visible (la bulle n'a pas encore relancé QRFlow), on obtient donc bien le
 *     contenu voulu. MLKit analyse le bitmap directement en mémoire.
 *  3. Seulement APRÈS l'analyse, QRFlow est relancé au premier plan avec le résultat.
 */
class QRFlowAccessibilityService : AccessibilityService() {

    companion object {
        const val EXTRA_PATH = "screenshot_path"

        private const val TAG = "QRFlowCapture"

        /** Délai minimum entre deux captures imposé par Android (~1 s). */
        private const val SCREENSHOT_INTERVAL_MS = 1100L

        /** Domaine plausible (ex. mon-site.com/chemin). */
        private val DOMAIN_REGEX = Regex("[a-z0-9][a-z0-9.-]*\\.[a-z]{2,}(/.*)?")

        /** Instance du service quand il est connecté (null sinon). */
        @Volatile
        var instance: QRFlowAccessibilityService? = null
            private set
    }

    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val captureInProgress = AtomicBoolean(false)

    @Volatile
    private var lastCaptureAt = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "Service d'accessibilité connecté")
    }

    override fun onDestroy() {
        instance = null
        ioExecutor.shutdown()
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Aucun événement exploité : le service ne sert qu'à la capture.
    }

    override fun onInterrupt() {}

    /**
     * Point d'entrée principal appelé par la bulle flottante.
     *
     * IMPORTANT : Cette méthode est appelée alors que l'AUTRE application
     * est encore visible à l'écran (avant tout retour vers QRFlow).
     * C'est ici que le scan doit se produire, pas après.
     */
    fun scanScreenNow() {
        ioExecutor.execute {
            // Étape 1 : lecture directe (zéro capture, instantané).
            val texts = extractScreenTexts()
            if (texts.isNotEmpty()) {
                Log.i(TAG, "Lecture directe : ${texts.size} candidat(s) trouvés — livraison sans capture")
                deliverTextCandidatesToFlutter(this, texts)
                return@execute
            }

            Log.i(TAG, "Arbre vide — tentative de capture d'écran immédiate (l'autre app est visible)")
            // Étape 2 : capture immédiate pendant que l'autre app est encore à l'écran.
            captureAndAnalyzeNow()
        }
    }

    /**
     * Capture l'écran EN MÉMOIRE et analyse directement le bitmap avec MLKit.
     * QRFlow n'est relancé au premier plan QU'APRÈS l'analyse pour éviter
     * de capturer son propre écran.
     */
    private fun captureAndAnalyzeNow() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            recordCaptureError(this, "La capture d'écran nécessite Android 11 ou plus.")
            launchAppForFeedback(this)
            return
        }
        if (!captureInProgress.compareAndSet(false, true)) {
            Log.w(TAG, "Une capture est déjà en cours")
            return
        }

        // Respect du délai minimum Android entre deux captures.
        val wait = SCREENSHOT_INTERVAL_MS - (System.currentTimeMillis() - lastCaptureAt)
        if (wait > 0) {
            try { Thread.sleep(wait) } catch (_: InterruptedException) {}
        }

        try {
            takeScreenshot(
                0, // Display par défaut
                ioExecutor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(result: ScreenshotResult) {
                        lastCaptureAt = System.currentTimeMillis()
                        processScreenshotWithMLKit(result)
                    }

                    override fun onFailure(errorCode: Int) {
                        captureInProgress.set(false)
                        Log.e(TAG, "Échec de capture (code $errorCode)")
                        recordCaptureError(
                            this@QRFlowAccessibilityService,
                            "Impossible de capturer l'écran (code $errorCode). " +
                                "Certaines applications bloquent la capture (banque, DRM…)."
                        )
                        launchAppForFeedback(this@QRFlowAccessibilityService)
                    }
                }
            )
        } catch (e: IllegalStateException) {
            captureInProgress.set(false)
            Log.e(TAG, "Service non connecté lors de la capture", e)
            recordCaptureError(this, "Service d'accessibilité déconnecté. Réessayez.")
            launchAppForFeedback(this)
        } catch (e: Exception) {
            captureInProgress.set(false)
            Log.e(TAG, "Erreur inattendue lors de la capture", e)
            recordCaptureError(this, "Erreur lors de la capture : ${e.message}")
            launchAppForFeedback(this)
        }
    }

    /**
     * Analyse le bitmap capturé directement avec MLKit (en mémoire).
     * - Si QR codes trouvés → livraison des valeurs textuelles.
     * - Sinon → sauvegarde PNG et livraison du chemin pour analyse Flutter.
     */
    private fun processScreenshotWithMLKit(result: ScreenshotResult) {
        try {
            val hardwareBitmap = Bitmap.wrapHardwareBuffer(result.hardwareBuffer, result.colorSpace)
                ?: run {
                    captureInProgress.set(false)
                    recordCaptureError(this, "Bitmap null après capture.")
                    launchAppForFeedback(this)
                    return
                }

            // Copie en bitmap logiciel (requis pour MLKit et PNG).
            val bitmap = hardwareBitmap.copy(Bitmap.Config.ARGB_8888, false)
            hardwareBitmap.recycle()
            try { result.hardwareBuffer.close() } catch (_: Exception) {}

            // Vérification rapide : si le bitmap est entièrement noir, inutile de l'analyser.
            if (isBitmapBlack(bitmap)) {
                Log.w(TAG, "Bitmap entièrement noir — l'app cible a peut-être bloqué la capture")
                bitmap.recycle()
                captureInProgress.set(false)
                recordCaptureError(
                    this,
                    "La capture est noire. L'application cible bloque peut-être les captures. " +
                        "Essayez d'appuyer sur la bulle avant de changer d'application."
                )
                launchAppForFeedback(this)
                return
            }

            val inputImage = InputImage.fromBitmap(bitmap, 0)
            val scanner = BarcodeScanning.getClient()

            scanner.process(inputImage)
                .addOnSuccessListener { barcodes ->
                    captureInProgress.set(false)
                    val qrValues = barcodes.mapNotNull { it.rawValue?.takeIf { v -> v.isNotBlank() } }

                    if (qrValues.isNotEmpty()) {
                        Log.i(TAG, "MLKit en mémoire : ${qrValues.size} QR trouvé(s)")
                        bitmap.recycle()
                        // QR trouvés en mémoire : livraison directe sans fichier PNG.
                        deliverTextCandidatesToFlutter(this, qrValues)
                    } else {
                        Log.i(TAG, "MLKit : aucun QR trouvé dans le bitmap — sauvegarde PNG pour Flutter")
                        val path = saveBitmap(bitmap)
                        bitmap.recycle()
                        deliverCaptureToFlutter(this, path)
                    }
                }
                .addOnFailureListener { e ->
                    captureInProgress.set(false)
                    Log.e(TAG, "MLKit a échoué", e)
                    // Repli : livrer le PNG à Flutter.
                    val path = saveBitmap(bitmap)
                    bitmap.recycle()
                    deliverCaptureToFlutter(this, path)
                }
        } catch (e: Exception) {
            captureInProgress.set(false)
            Log.e(TAG, "Erreur lors du traitement de la capture", e)
            recordCaptureError(this, "Erreur de traitement de la capture.")
            launchAppForFeedback(this)
        }
    }

    /**
     * Vérifie rapidement si un bitmap est entièrement (ou quasi) noir.
     * Échantillonne 100 pixels répartis sur l'image.
     */
    private fun isBitmapBlack(bitmap: Bitmap): Boolean {
        val w = bitmap.width
        val h = bitmap.height
        if (w == 0 || h == 0) return true
        var darkCount = 0
        val sampleCount = 100
        for (i in 0 until sampleCount) {
            val x = (w.toLong() * i / sampleCount).toInt().coerceIn(0, w - 1)
            val y = (h.toLong() * i / sampleCount).toInt().coerceIn(0, h - 1)
            val pixel = bitmap.getPixel(x, y)
            val r = (pixel shr 16) and 0xFF
            val g = (pixel shr 8) and 0xFF
            val b = pixel and 0xFF
            if (r < 10 && g < 10 && b < 10) darkCount++
        }
        return darkCount > sampleCount * 0.9 // > 90% de pixels noirs
    }

    /**
     * Parcourt l'arbre d'accessibilité de la fenêtre active et collecte les
     * textes / descriptions qui ressemblent à un contenu de QR code.
     * Ne prend AUCUNE capture d'écran.
     */
    private fun extractScreenTexts(): List<String> {
        val root = getRootInActiveWindow() ?: return emptyList()
        val found = LinkedHashSet<String>()
        val allNodes = ArrayList<AccessibilityNodeInfo>()
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.add(root)
        while (stack.isNotEmpty()) {
            val node = stack.removeLast()
            allNodes.add(node)
            val text = node.text?.toString()?.trim()
            if (text != null && isPlausibleQrText(text)) found.add(text)
            val desc = node.contentDescription?.toString()?.trim()
            if (desc != null && isPlausibleQrText(desc)) found.add(desc)
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { stack.add(it) }
            }
        }
        // Recyclage dans l'ordre inverse (enfants avant parents).
        for (i in allNodes.indices.reversed()) {
            try { allNodes[i].recycle() } catch (_: Exception) {}
        }
        return found.take(10).toList()
    }

    /** Garde les textes qui ressemblent à un contenu de QR (évite le bruit UI). */
    private fun isPlausibleQrText(s: String?): Boolean {
        if (s.isNullOrBlank()) return false
        if (s.length < 2 || s.length > 2000) return false
        val lower = s.lowercase()
        // Signaux forts : préfixes classiques de QR / URL.
        val strongPrefixes = listOf(
            "http://", "https://", "www.", "tel:", "mailto:", "wifi:", "smsto:",
            "sms:", "geo:", "matmsg:", "mecard:", "begin:vcard", "vcard:", "begin:vevent",
            "market://", "intent://", "bitcoin:", "upi://", "otpauth://", "paytm://",
            "ethereum:", "solana:", "wa.me/", "t.me/",
        )
        if (strongPrefixes.any { lower.startsWith(it) }) return true
        // Nom de domaine plausible (ex. mon-site.com/chemin).
        if (s.length <= 200 && DOMAIN_REGEX.matches(lower)) return true
        // Texte court et simple (pavage QR « texte » typique).
        if (s.length in 2..60 && !s.contains('\n') && s.count { it.isWhitespace() } <= 8) {
            return !s.endsWith(".")
        }
        return false
    }

    private fun saveBitmap(bitmap: Bitmap): String {
        val dir = File(cacheDir, "qrflow")
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, "capture_${System.currentTimeMillis()}.png")
        FileOutputStream(file).use { out ->
            val ok = bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            if (!ok) Log.e(TAG, "compress() a échoué, PNG peut être vide")
        }
        return file.absolutePath
    }
}
