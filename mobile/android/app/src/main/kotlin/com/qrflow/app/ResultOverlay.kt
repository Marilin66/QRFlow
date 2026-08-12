package com.qrflow.app

import android.app.AlertDialog
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.net.Uri
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

/**
 * Fenêtre de résultat TYPE_APPLICATION_OVERLAY : affichée au-dessus de l'app
 * en cours, sans jamais quitter celle-ci. Liste des QR détectés → détail →
 * actions (toujours avec confirmation pour tout ce qui quitte QRFlow).
 */
class ResultOverlay private constructor(private val context: Context) {
    companion object {
        private var current: ResultOverlay? = null

        fun show(context: Context?, payloads: List<Map<String, Any?>>) {
            val ctx = context ?: return
            dismiss()
            current = ResultOverlay(ctx).showInternal(payloads)
        }

        fun dismiss() {
            current?.remove()
            current = null
        }
    }

    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var root: LinearLayout? = null
    private var params: WindowManager.LayoutParams? = null

    // ── Palette du cahier des charges ─────────────────────────────────────
    private val primary = Color.parseColor("#5B5FEF")
    private val success = Color.parseColor("#2FB380")
    private val alert = Color.parseColor("#E2574C")
    private val isDark: Boolean =
        (context.resources.configuration.uiMode and
            android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
            android.content.res.Configuration.UI_MODE_NIGHT_YES
    private val bg = hex(if (isDark) "#12131A" else "#F7F8FC")
    private val ink = hex(if (isDark) "#F2F3FA" else "#1C1D2E")
    private val muted = hex(if (isDark) "#9A9DB4" else "#6B6E85")
    private val border = hex(if (isDark) "#2A2C3C" else "#E4E6F2")

    private fun hex(value: String): Int = Color.parseColor(value)

    private fun showInternal(payloads: List<Map<String, Any?>>): ResultOverlay {
        val width = displayWidth() - dp(32)
        val lp = WindowManager.LayoutParams(
            width,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        )
        lp.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        lp.y = dp(96)
        params = lp

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
            background = rounded(bg, dp(20), border)
            elevation = dp(12).toFloat()
        }

        if (payloads.size == 1) {
            container.addView(buildDetail(payloads.first(), withOpenInApp = true))
        } else {
            container.addView(
                sectionTitle("${payloads.size} QR codes détectés"),
            )
            payloads.forEach { payload ->
                container.addView(buildListItem(payload))
            }
        }

        wm.addView(container, lp)
        root = container
        return this
    }

    private fun remove() {
        val view = root ?: return
        runCatching { wm.removeView(view) }
        root = null
    }

    // ── Liste ─────────────────────────────────────────────────────────────

    private fun buildListItem(payload: Map<String, Any?>): View {
        val label = payload["typeLabel"] as? String ?: "Contenu"
        val display = payload["display"] as? String ?: ""
        val suspicious = payload["suspicious"] as? Boolean == true

        val row = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(12), 0, dp(12))
            background = null
        }
        row.addView(
            TextView(context).apply {
                text = if (suspicious) "⚠" else "•"
                textSize = 18f
                setTextColor(if (suspicious) alert else primary)
            },
        )
        val textCol = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL }
        textCol.addView(
            TextView(context).apply {
                text = label
                textSize = 14f
                setTypeface(null, Typeface.BOLD)
                setTextColor(ink)
            },
        )
        textCol.addView(
            TextView(context).apply {
                text = display
                textSize = 12f
                maxLines = 2
                setTextColor(muted)
                typeface = Typeface.MONOSPACE
            },
        )
        row.addView(textCol, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        row.setOnClickListener { showDetail(payload) }
        return row
    }

    // ── Détail ────────────────────────────────────────────────────────────

    private fun showDetail(payload: Map<String, Any?>) {
        remove()
        val lp = params
        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
            background = rounded(bg, dp(20), border)
            elevation = dp(12).toFloat()
        }
        container.addView(buildDetail(payload, withOpenInApp = true))
        if (lp != null) wm.addView(container, lp)
        root = container
    }

    private fun buildDetail(payload: Map<String, Any?>, withOpenInApp: Boolean): View {
        val label = payload["typeLabel"] as? String ?: "Contenu"
        val raw = payload["raw"] as? String ?: ""
        val display = payload["display"] as? String ?: raw
        val domain = payload["domain"] as? String
        val suspicious = payload["suspicious"] as? Boolean == true
        val details = (payload["details"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()

        val col = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL }

        // Type
        col.addView(
            TextView(context).apply {
                text = label
                textSize = 14f
                setTypeface(null, Typeface.BOLD)
                setTextColor(if (suspicious) alert else primary)
            },
        )

        // Domaine (URL) toujours visible en clair
        if (domain != null) {
            col.addView(
                TextView(context).apply {
                    text = "Domaine : $domain"
                    textSize = 12f
                    setTextColor(if (suspicious) alert else success)
                    setPadding(0, dp(4), 0, 0)
                },
            )
        }

        // Contenu principal (mono)
        col.addView(
            TextView(context).apply {
                text = display
                textSize = 15f
                typeface = Typeface.MONOSPACE
                setTextColor(ink)
                setPadding(0, dp(10), 0, 0)
            },
        )

        // Détails supplémentaires
        details.forEach { line ->
            col.addView(
                TextView(context).apply {
                    text = line
                    textSize = 12f
                    setTextColor(muted)
                    setPadding(0, dp(2), 0, 0)
                },
            )
        }

        // Bandeau lien dangereux
        if (suspicious) {
            col.addView(
                TextView(context).apply {
                    text = "⚠ Lien potentiellement dangereux : vérifiez avant d'ouvrir."
                    textSize = 12f
                    setPadding(dp(10), dp(10), dp(10), dp(10))
                    background = rounded(hex("#3E1F1B"), dp(10), hex("#3E1F1B"))
                    setTextColor(Color.parseColor("#F5C6C2"))
                },
            )
        }

        // Boutons
        col.addView(spacer(dp(14)))
        col.addView(primaryButton(payload))
        col.addView(spacer(dp(8)))
        val secondRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        secondRow.addView(ghostButton("Copier") { copy(raw) }, weight(1f))
        if (withOpenInApp) {
            secondRow.addView(spacer(dp(8), horizontal = true))
            secondRow.addView(ghostButton("Voir dans QRFlow") { openInApp(raw) }, weight(1f))
        }
        col.addView(secondRow)
        col.addView(spacer(dp(6)))
        col.addView(
            TextView(context).apply {
                text = "Fermer"
                gravity = Gravity.CENTER
                textSize = 13f
                setTextColor(muted)
                setPadding(0, dp(8), 0, dp(2))
                setOnClickListener { dismiss() }
            },
        )

        val scroll = ScrollView(context).apply {
            isFillViewport = false
            addView(col)
        }
        return scroll
    }

    // ── Boutons ───────────────────────────────────────────────────────────

    private fun primaryButton(payload: Map<String, Any?>): Button {
        val code = payload["primaryCode"] as? String ?: "copy"
        val label = payload["primaryLabel"] as? String ?: "Copier"
        val suspicious = payload["suspicious"] as? Boolean == true

        return Button(context).apply {
            text = label
            setTextColor(Color.WHITE)
            background = rounded(
                if (suspicious) alert else primary,
                dp(24),
                null,
            )
            setOnClickListener {
                when (code) {
                    "openUrl" -> openUrl(payload)
                    "dial" -> confirmAction(
                        "Appeler ce numéro ?",
                        payload["number"] as? String ?: "",
                        "Appeler",
                    ) { dial(payload["number"] as? String ?: "") }
                    "email" -> email(payload["address"] as? String ?: "")
                    "sms" -> sms(payload["number"] as? String ?: "", payload["message"] as? String)
                    "copyPassword" -> {
                        copy(payload["password"] as? String ?: "")
                        toast("Mot de passe copié")
                    }
                    "maps" -> maps(
                        (payload["latitude"] as? Double) ?: 0.0,
                        (payload["longitude"] as? Double) ?: 0.0,
                    )
                    else -> copy(payload["raw"] as? String ?: "")
                }
            }
        }
    }

    private fun ghostButton(label: String, action: () -> Unit): Button =
        Button(context).apply {
            text = label
            setTextColor(primary)
            background = rounded(
                hex(if (isDark) "#2A2B5E" else "#E9E9FF"),
                dp(24),
                null,
            )
            setOnClickListener { action() }
        }

    // ── Actions (toujours avec confirmation) ──────────────────────────────

    private fun openUrl(payload: Map<String, Any?>) {
        val url = payload["raw"] as? String ?: ""
        val suspicious = payload["suspicious"] as? Boolean == true
        confirmAction(
            "Ouvrir ce lien ?",
            url,
            "Ouvrir le lien",
            danger = suspicious,
        ) {
            runCatching {
                context.startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            }.onFailure { toast("Impossible d'ouvrir ce lien") }
        }
    }

    private fun dial(number: String) {
        runCatching {
            context.startActivity(
                Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    private fun email(address: String) {
        runCatching {
            context.startActivity(
                Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$address")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    private fun sms(number: String, message: String?) {
        val uri = Uri.parse("sms:$number")
        val intent = Intent(Intent.ACTION_SENDTO, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (message != null) intent.putExtra("sms_body", message)
        runCatching { context.startActivity(intent) }
    }

    private fun maps(lat: Double, lng: Double) {
        runCatching {
            context.startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse("geo:$lat,$lng?q=$lat,$lng"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    private fun copy(text: String) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("QRFlow", text))
        toast("Copié ✓")
    }

    private fun openInApp(raw: String) {
        dismiss()
        val ctx = context
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            ctx.startActivity(launch)
        }
        ScreenCaptureChannel.openInApp(raw)
    }

    private fun confirmAction(
        title: String,
        message: String,
        actionLabel: String,
        danger: Boolean = false,
        onConfirm: () -> Unit,
    ) {
        AlertDialog.Builder(context)
            .setTitle(title)
            .setMessage(message)
            .setNegativeButton("Annuler", null)
            .setPositiveButton(actionLabel) { _, _ -> onConfirm() }
            .apply {
                if (danger) {
                    val dialog = create()
                    dialog.setOnShowListener {
                        dialog.getButton(AlertDialog.BUTTON_POSITIVE).setTextColor(alert)
                    }
                    dialog.show()
                } else {
                    show()
                }
            }
    }

    private fun toast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    // ── Helpers UI ────────────────────────────────────────────────────────

    private fun sectionTitle(title: String): TextView =
        TextView(context).apply {
            text = title
            textSize = 14f
            setTypeface(null, Typeface.BOLD)
            setTextColor(ink)
            setPadding(0, 0, 0, dp(4))
        }

    private fun spacer(heightDp: Int, horizontal: Boolean = false): View =
        View(context).apply {
            layoutParams = if (horizontal) {
                LinearLayout.LayoutParams(dp(heightDp), 1)
            } else {
                LinearLayout.LayoutParams(1, dp(heightDp))
            }
        }

    private fun weight(weight: Float): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, weight)

    private fun rounded(color: Int, radiusDp: Int, stroke: Int?): android.graphics.drawable.GradientDrawable =
        android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            cornerRadius = dp(radiusDp).toFloat()
            setColor(color)
            if (stroke != null) {
                setStroke(dp(1), stroke)
            }
        }

    private fun displayWidth(): Int {
        val metrics = android.util.DisplayMetrics()
        wm.defaultDisplay.getRealMetrics(metrics)
        return metrics.widthPixels
    }

    private fun dp(value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()
}
