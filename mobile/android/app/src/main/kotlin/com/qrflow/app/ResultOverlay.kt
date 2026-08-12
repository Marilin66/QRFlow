package com.qrflow.app

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import android.text.TextUtils
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * Fenêtre de résultat du Mode Flash.
 *
 * Une carte compacte (TYPE_APPLICATION_OVERLAY) affichée AU-DESSUS de
 * l'application en cours : l'utilisateur lit ce que contient le QR code, agit
 * ou ferme, sans jamais quitter l'app qu'il était en train d'utiliser.
 *
 * États : LISTE (plusieurs QR) → RÉSULTAT → CONFIRMATION (action sensible).
 * Le contenu affiché est produit côté Dart (source unique de vérité) : ce
 * fichier ne fait qu'interpréter le payload pour le rendre et exécuter les
 * actions (URI, copie, ajout calendrier).
 *
 * Réglages respectés (lu dans FlutterSharedPreferences) : confirmation avant
 * action et détection de plusieurs QR codes.
 */
@SuppressLint("ViewConstructor")
object ResultOverlay {

    private const val TAG = "QRFlowOverlay"

    // ── Design system QRFlow (prompt section 9) ─────────────────────────
    private const val COLOR_PRIMARY = 0xFF5B5FEF.toInt()
    private const val COLOR_SUCCESS = 0xFF2FB380.toInt()
    private const val COLOR_ALERT = 0xFFE2574C.toInt()
    private const val COLOR_DISABLED = 0xFF8A8FA8.toInt()
    private const val COLOR_BG_LIGHT = 0xFFF7F8FC.toInt()
    private const val COLOR_BG_DARK = 0xFF12131A.toInt()
    private const val COLOR_TEXT_LIGHT = 0xFF1B1C2E.toInt()
    private const val COLOR_TEXT_DARK = 0xFFF1F2FA.toInt()
    private const val COLOR_MUTED_LIGHT = 0xFF5A5D75.toInt()
    private const val COLOR_MUTED_DARK = 0xFF9BA0BC.toInt()

    private val mainHandler = Handler(Looper.getMainLooper())

    private var appContext: Context? = null
    private var prefs: SharedPreferences? = null
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var dark = false

    // ── Affichage public ────────────────────────────────────────────────

    /**
     * Point d'entrée appelé après décodage MLKit à l'écran (Mode Flash).
     *
     * Si le moteur Flutter est vivant, Dart analyse les contenus et produit
     * les payloads de la carte ; sinon, repli sur la livraison classique à
     * Flutter (l'application passe au premier plan) : aucun résultat perdu.
     */
    fun showForCandidates(context: Context, candidates: List<String>) {
        val channel = ScreenCaptureChannel.instance
        if (channel == null) {
            deliverTextCandidatesToFlutter(context, candidates)
            return
        }
        channel.analyzeForOverlay(candidates) { payloads ->
            if (payloads.isNullOrEmpty()) {
                deliverTextCandidatesToFlutter(context, candidates)
            } else {
                show(context, payloads)
            }
        }
    }

    /**
     * Affiche la fenêtre de résultat au-dessus de l'application en cours.
     * Appelé depuis le thread d'exécution de la capture : le rendu est posté
     * sur le thread principal. Toute carte déjà affichée est remplacée.
     */
    fun show(context: Context, payloads: List<Map<String, Any?>>) {
        if (payloads.isEmpty()) return
        appContext = context.applicationContext
        prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        dark = isDarkMode(context)
        mainHandler.post {
            val multiQr = readBoolSetting(prefs, "flutter.multi_qr", true)
            if (payloads.size > 1 && multiQr) showList(payloads) else showResult(payloads[0])
        }
    }

    /** Ferme la carte (la bulle flottante reste active). */
    fun dismiss() {
        mainHandler.post {
            overlayView?.let { view ->
                try {
                    windowManager?.removeView(view)
                } catch (_: Exception) {
                    // Vue déjà retirée.
                }
            }
            overlayView = null
        }
    }

    // ── États de la carte ───────────────────────────────────────────────

    private fun showList(payloads: List<Map<String, Any?>>) {
        val ctx = requireContext()
        val root = cardRoot(ctx)
        headerRow(root, "Plusieurs QR codes détectés") { dismiss() }

        val scroll = ScrollView(ctx)
        val list = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }
        payloads.take(5).forEachIndexed { index, payload ->
            if (index > 0) list.addView(divider(ctx))
            val summary = (payload["summary"] as? String) ?: ""
            val row = LinearLayout(ctx).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(ctx, 6), dp(ctx, 8), dp(ctx, 6), dp(ctx, 8))
                isClickable = true
                isFocusable = true
                setOnClickListener { showResult(payload) }
            }
            row.addView(
                chip(ctx, (payload["typeLabel"] as? String) ?: "Contenu"),
                LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT),
            )
            row.addView(
                textView(ctx, summary, 14f, textColor(), bold = true, maxLines = 1),
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                    marginStart = dp(ctx, 10)
                },
            )
            list.addView(row)
        }
        if (payloads.size > 5) {
            list.addView(divider(ctx))
            list.addView(
                textView(
                    ctx,
                    "… et ${payloads.size - 5} autre(s) QR code(s), consultables dans QRFlow",
                    11.5f,
                    mutedColor(),
                    maxLines = 1,
                ),
                vParams(dp(ctx, 8)),
            )
        }
        scroll.addView(list)
        // Hauteur bornée quand la liste est longue (petits écrans).
        val scrollParams = if (payloads.size > 3) {
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(ctx, 260))
        } else {
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        }
        root.addView(scroll, scrollParams)
        showWindow(root)
    }

    private fun showResult(payload: Map<String, Any?>) {
        val ctx = requireContext()
        val root = cardRoot(ctx)
        headerRow(root, (payload["typeLabel"] as? String) ?: "Contenu") { dismiss() }

        // Contenu principal.
        root.addView(
            textView(ctx, (payload["summary"] as? String) ?: "", 19f, textColor(), bold = true, maxLines = 2),
            vParams(dp(ctx, 12)),
        )
        root.addView(
            textView(ctx, (payload["raw"] as? String) ?: "", 12f, mutedColor(), mono = true, maxLines = 3),
            vParams(dp(ctx, 6)),
        )
        val subtitle = payload["subtitle"] as? String
        if (!subtitle.isNullOrEmpty()) {
            root.addView(textView(ctx, subtitle, 11.5f, mutedColor()), vParams(dp(ctx, 6)))
        }

        // Avertissement de sécurité (liens suspects).
        if (payload["suspicious"] == true) {
            val reasons = (payload["reasons"] as? List<*>)
                ?.mapNotNull { it as? String }
                .orEmpty()
            root.addView(warningBanner(ctx, reasons), vParams(dp(ctx, 12)))
        }

        // Note pédagogique : Wi-Fi sans mot de passe.
        if (payload["type"] == "wifi" && payload["hasPassword"] != true) {
            root.addView(
                infoNote(
                    ctx,
                    "QRFlow ne se connecte jamais automatiquement à un réseau Wi-Fi.",
                ),
                vParams(dp(ctx, 10)),
            )
        }

        // Action principale.
        val primary = payload["primaryAction"] as? Map<*, *>
        val primaryLabel = primary?.get("label") as? String
        if (primaryLabel != null) {
            val actionable = primary["uri"] != null ||
                primary["copyText"] != null ||
                primary["calendar"] != null
            // Copie pure (texte, mot de passe Wi-Fi…) : feedback sans fermer
            // la carte, pour rester disponible immédiatement.
            val copyOnly = primary["copyText"] != null &&
                primary["uri"] == null &&
                primary["calendar"] == null
            lateinit var primaryButton: Button
            primaryButton = actionButton(
                ctx,
                primaryLabel,
                filled = true,
                color = COLOR_PRIMARY,
                enabled = actionable,
            ) {
                if (copyOnly) {
                    copyWithFeedback(primaryButton, primaryLabel, (primary["copyText"] as? String) ?: "")
                    return@actionButton
                }
                val confirmMessage = primary["confirmMessage"] as? String
                val confirm = readBoolSetting(prefs, "flutter.confirm_actions", true)
                if (confirm && !confirmMessage.isNullOrEmpty()) {
                    showConfirm(payload, confirmMessage)
                } else {
                    performPrimaryAction(payload)
                }
            }
            root.addView(primaryButton, vParams(dp(ctx, 12)))
        }

        // Ligne secondaire : Copier + Voir dans QRFlow.
        val copy = payload["copyAction"] as? Map<*, *>
        val row = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL }
        if (copy != null) {
            val copyLabel = (copy["label"] as? String) ?: "Copier"
            val copyTextValue = (copy["copyText"] as? String) ?: ""
            lateinit var copyButton: Button
            copyButton = actionButton(ctx, copyLabel, filled = false, color = COLOR_PRIMARY) {
                copyWithFeedback(copyButton, copyLabel, copyTextValue)
            }
            row.addView(copyButton, LinearLayout.LayoutParams(0, dp(ctx, 48), 1f))
        }
        row.addView(
            actionButton(ctx, "Voir dans QRFlow", filled = false, color = COLOR_PRIMARY) {
                openDetails((payload["raw"] as? String) ?: "")
            },
            LinearLayout.LayoutParams(0, dp(ctx, 48), 1f).apply { marginStart = dp(ctx, 10) },
        )
        root.addView(row, vParams(dp(ctx, 10)))

        showWindow(root)
    }

    private fun showConfirm(payload: Map<String, Any?>, message: String) {
        val ctx = requireContext()
        val root = cardRoot(ctx)
        val primary = payload["primaryAction"] as? Map<*, *>
        val label = (primary?.get("label") as? String) ?: "Confirmer"
        headerRow(root, (payload["typeLabel"] as? String) ?: "Contenu") { dismiss() }

        root.addView(
            textView(ctx, "Confirmer cette action ?", 16f, textColor(), bold = true),
            vParams(dp(ctx, 12)),
        )
        root.addView(
            textView(ctx, message, 13f, mutedColor(), maxLines = 8),
            vParams(dp(ctx, 6)),
        )

        val row = LinearLayout(ctx).apply { orientation = LinearLayout.HORIZONTAL }
        row.addView(
            actionButton(ctx, "Annuler", filled = false, color = COLOR_PRIMARY) { showResult(payload) },
            LinearLayout.LayoutParams(0, dp(ctx, 48), 1f),
        )
        row.addView(
            actionButton(ctx, label, filled = true, color = COLOR_PRIMARY) { performPrimaryAction(payload) },
            LinearLayout.LayoutParams(0, dp(ctx, 48), 1f).apply { marginStart = dp(ctx, 10) },
        )
        root.addView(row, vParams(dp(ctx, 12)))

        showWindow(root)
    }

    // ── Actions ─────────────────────────────────────────────────────────

    private fun performPrimaryAction(payload: Map<String, Any?>) {
        val ctx = appContext ?: return
        val primary = payload["primaryAction"] as? Map<*, *> ?: return
        val uri = primary["uri"] as? String
        val calendar = primary["calendar"] as? Map<*, *>
        val copyText = primary["copyText"] as? String
        when {
            uri != null -> openUri(ctx, uri)
            calendar != null -> openCalendar(ctx, calendar)
            copyText != null -> copy(ctx, copyText)
            else -> return
        }
        dismiss()
    }

    private fun openUri(ctx: Context, uri: String) {
        try {
            val parsed = Uri.parse(uri)
            val intent = when {
                uri.startsWith("mailto:") || uri.startsWith("sms:") ->
                    Intent(Intent.ACTION_SENDTO, parsed)
                uri.startsWith("tel:") ->
                    // ACTION_DIAL ouvre le composeur pré-rempli : aucun appel
                    // automatique, l'utilisateur reste décisionnaire.
                    Intent(Intent.ACTION_DIAL, parsed)
                else -> Intent(Intent.ACTION_VIEW, parsed)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Impossible d'ouvrir $uri", e)
            recordCaptureError(ctx, "Impossible d'ouvrir cette destination.")
            launchAppForFeedback(ctx)
        }
    }

    private fun openCalendar(ctx: Context, cal: Map<*, *>) {
        try {
            val intent = Intent(Intent.ACTION_INSERT)
                .setData(CalendarContract.Events.CONTENT_URI)
                .putExtra(CalendarContract.Events.TITLE, (cal["title"] as? String) ?: "Événement")
            val start = parseIso(cal["start"] as? String)
            val end = parseIso(cal["end"] as? String)
            if (start != null) intent.putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, start)
            if (end != null) intent.putExtra(CalendarContract.EXTRA_EVENT_END_TIME, end)
            (cal["location"] as? String)?.let {
                intent.putExtra(CalendarContract.Events.EVENT_LOCATION, it)
            }
            (cal["description"] as? String)?.let {
                intent.putExtra(CalendarContract.Events.DESCRIPTION, it)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Impossible d'ajouter l'événement au calendrier", e)
            recordCaptureError(ctx, "Impossible d'ajouter l'événement au calendrier.")
            launchAppForFeedback(ctx)
        }
    }

    private fun copy(ctx: Context, text: String): Boolean = try {
        val cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("QRFlow", text))
        true
    } catch (_: Exception) {
        false
    }

    /** Copie avec retour visuel « Copié ✓ » (1,4 s) sans fermer la carte. */
    private fun copyWithFeedback(button: Button, label: String, text: String) {
        if (copy(requireContext(), text)) {
            button.text = "Copié ✓"
            button.setTextColor(COLOR_SUCCESS)
            button.isEnabled = false
            mainHandler.postDelayed({
                button.text = label
                button.setTextColor(COLOR_PRIMARY)
                button.isEnabled = true
            }, 1400L)
        }
    }

    /** Ouvre le résultat complet dans QRFlow (l'écran de résultat habituel). */
    private fun openDetails(raw: String) {
        val ctx = appContext ?: return
        dismiss()
        // L'analyse a déjà été enregistrée dans l'historique quand la carte a
        // été affichée : on marque la livraison pour éviter le doublon.
        ctx.getSharedPreferences(ScreenCaptureChannel.PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(ScreenCaptureChannel.KEY_FROM_OVERLAY, true)
            .apply()
        deliverTextCandidatesToFlutter(ctx, listOf(raw))
    }

    // ── Construction des vues ───────────────────────────────────────────

    private fun cardRoot(ctx: Context): LinearLayout = LinearLayout(ctx).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(ctx, 18), dp(ctx, 14), dp(ctx, 18), dp(ctx, 16))
        background = roundedBackground(if (dark) COLOR_BG_DARK else COLOR_BG_LIGHT, dp(ctx, 22))
        elevation = dp(ctx, 18).toFloat()
        isClickable = true
        isFocusable = true
        clipToOutline = true
    }

    private fun headerRow(root: LinearLayout, title: String, onClose: () -> Unit) {
        val ctx = requireContext()
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        row.addView(
            chip(ctx, title.uppercase()),
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
        )
        val close = TextView(ctx).apply {
            text = "×"
            textSize = 22f
            setTextColor(mutedColor())
            setPadding(dp(ctx, 10), dp(ctx, 0), dp(ctx, 4), dp(ctx, 2))
            isClickable = true
            isFocusable = true
            contentDescription = "Fermer"
            setOnClickListener { onClose() }
        }
        row.addView(close, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        root.addView(row)
    }

    private fun chip(ctx: Context, label: String): TextView = TextView(ctx).apply {
        text = label
        textSize = 10.5f
        setTextColor(COLOR_PRIMARY)
        typeface = Typeface.DEFAULT_BOLD
        setPadding(dp(ctx, 10), dp(ctx, 4), dp(ctx, 10), dp(ctx, 4))
        background = roundedBackground(Color.argb(0x16, 0x5B, 0x5F, 0xEF), dp(ctx, 20))
        maxLines = 1
    }

    private fun textView(
        ctx: Context,
        text: String,
        sizeSp: Float,
        color: Int,
        bold: Boolean = false,
        mono: Boolean = false,
        maxLines: Int = Int.MAX_VALUE,
    ): TextView = TextView(ctx).apply {
        this.text = text
        textSize = sizeSp
        setTextColor(color)
        typeface = when {
            mono -> Typeface.MONOSPACE
            bold -> Typeface.DEFAULT_BOLD
            else -> Typeface.DEFAULT
        }
        this.maxLines = maxLines
        ellipsize = if (maxLines < Int.MAX_VALUE) TextUtils.TruncateAt.END else null
    }

    private fun actionButton(
        ctx: Context,
        label: String,
        filled: Boolean,
        color: Int,
        enabled: Boolean = true,
        onClick: () -> Unit,
    ): Button = Button(ctx).apply {
        text = label
        textSize = 14f
        isAllCaps = false
        letterSpacing = 0f
        setPadding(0, 0, 0, 0)
        minHeight = 0
        minimumHeight = 0
        minWidth = 0
        minimumWidth = 0
        background = if (filled) {
            roundedBackground(if (enabled) color else COLOR_DISABLED, dp(ctx, 14))
        } else {
            outlinedBackground(ctx, color)
        }
        setTextColor(if (filled) Color.WHITE else color)
        this.isEnabled = enabled
        stateListAnimator = null
        setOnClickListener { onClick() }
    }

    private fun warningBanner(ctx: Context, reasons: List<String>): LinearLayout =
        LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(ctx, 12), dp(ctx, 10), dp(ctx, 12), dp(ctx, 10))
            background = roundedBackground(Color.argb(0x18, 0xE2, 0x57, 0x4C), dp(ctx, 12))
            addView(textView(ctx, "Lien potentiellement dangereux", 12.5f, COLOR_ALERT, bold = true))
            reasons.take(3).forEach { reason ->
                addView(
                    textView(ctx, "• $reason", 11.5f, COLOR_ALERT),
                    vParams(dp(ctx, 4)),
                )
            }
            if (reasons.size > 3) {
                addView(
                    textView(ctx, "… et ${reasons.size - 3} autre(s) signal(s)", 11.5f, COLOR_ALERT),
                    vParams(dp(ctx, 4)),
                )
            }
        }

    private fun infoNote(ctx: Context, text: String): LinearLayout = LinearLayout(ctx).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(ctx, 12), dp(ctx, 9), dp(ctx, 12), dp(ctx, 9))
        background = roundedBackground(
            Color.argb(0x14, 0x2F, 0xB3, 0x80),
            dp(ctx, 12),
        )
        addView(textView(ctx, text, 11.5f, COLOR_SUCCESS, maxLines = 3))
    }

    private fun divider(ctx: Context): View = View(ctx).apply {
        background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(if (dark) Color.parseColor("#2A2D45") else Color.parseColor("#E3E6F0"))
        }
    }

    private fun showWindow(card: View) {
        val ctx = requireContext()
        if (overlayView != null) {
            try {
                windowManager?.removeView(overlayView)
            } catch (_: Exception) {
                // Vue déjà retirée.
            }
            overlayView = null
        }
        val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            width = ctx.resources.displayMetrics.widthPixels - dp(ctx, 40)
            y = dp(ctx, 28)
        }
        windowManager = wm
        try {
            wm.addView(card, params)
            overlayView = card
        } catch (e: Exception) {
            Log.e(TAG, "Impossible d'afficher la carte de résultat", e)
            recordCaptureError(
                ctx,
                "Impossible d'afficher le résultat par-dessus l'application. " +
                    "Ouvrez QRFlow pour le consulter.",
            )
            launchAppForFeedback(ctx)
        }
    }

    // ── Divers ──────────────────────────────────────────────────────────

    private fun requireContext(): Context =
        appContext ?: throw IllegalStateException("ResultOverlay non initialisé")

    @Suppress("DEPRECATION")
    private fun overlayType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }

    private fun isDarkMode(context: Context): Boolean {
        val mode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return mode == Configuration.UI_MODE_NIGHT_YES
    }

    private fun readBoolSetting(prefs: SharedPreferences?, key: String, default: Boolean): Boolean {
        if (prefs == null) return default
        return try {
            prefs.getBoolean(key, default)
        } catch (_: Exception) {
            default
        }
    }

    private fun textColor(): Int = if (dark) COLOR_TEXT_DARK else COLOR_TEXT_LIGHT

    private fun mutedColor(): Int = if (dark) COLOR_MUTED_DARK else COLOR_MUTED_LIGHT

    private fun dp(context: Context, value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()

    private fun vParams(topMargin: Int): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply { this.topMargin = topMargin }

    private fun roundedBackground(color: Int, radius: Int): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(color)
            cornerRadius = radius.toFloat()
        }

    private fun outlinedBackground(ctx: Context, color: Int): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(Color.TRANSPARENT)
            cornerRadius = dp(ctx, 14).toFloat()
            setStroke(dp(ctx, 1), color)
        }

    private fun parseIso(value: String?): Long? {
        if (value.isNullOrEmpty()) return null
        val formats = arrayOf(
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US),
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US),
            SimpleDateFormat("yyyy-MM-dd", Locale.US),
        )
        for (format in formats) {
            try {
                format.parse(value)?.let { return it.time }
            } catch (_: Exception) {
                // Format suivant.
            }
        }
        return null
    }
}
