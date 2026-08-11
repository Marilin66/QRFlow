package com.qrflow.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityService.TakeScreenshotCallback
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executor

class QRFlowAccessibilityService : AccessibilityService() {

    companion object {
        const val ACTION_TAKE_SCREENSHOT = "com.qrflow.app.ACTION_TAKE_SCREENSHOT"
        const val EXTRA_PATH = "screenshot_path"
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_TAKE_SCREENSHOT) {
                takeScreenshotAndProcess()
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        val filter = IntentFilter(ACTION_TAKE_SCREENSHOT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
        Log.d("QRFlow", "Accessibility Service Connected")
    }

    override fun onDestroy() {
        unregisterReceiver(receiver)
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Non utilisé, on s'en sert uniquement pour la capture d'écran
    }

    override fun onInterrupt() {}

    private fun takeScreenshotAndProcess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            takeScreenshot(0, object : Executor {
                override fun execute(command: Runnable) {
                    command.run()
                }
            }, object : TakeScreenshotCallback {
                override fun onSuccess(screenshot: ScreenshotResult) {
                    val bitmap = Bitmap.wrapHardwareBuffer(screenshot.hardwareBuffer, screenshot.colorSpace)
                    bitmap?.let {
                        val path = saveBitmap(it)
                        launchFlutterActivity(path)
                    }
                }

                override fun onFailure(errorCode: Int) {
                    Log.e("QRFlow", "Screenshot failed with error code: $errorCode")
                }
            })
        }
    }

    private fun saveBitmap(bitmap: Bitmap): String {
        val dir = File(cacheDir, "qrflow")
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, "capture_${System.currentTimeMillis()}.png")
        FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
        return file.absolutePath
    }

    private fun launchFlutterActivity(path: String) {
        getSharedPreferences(ScreenCaptureChannel.PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(ScreenCaptureChannel.KEY_PENDING_CAPTURE, path)
            .apply()

        val intent = Intent(this, MainActivity::class.java).apply {
            action = ScreenCaptureChannel.ACTION_CAPTURE
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_PATH, path)
        }
        startActivity(intent)
    }
}
