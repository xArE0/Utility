package com.example.utility

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.content.edit
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "floating_dot"
    private val mainHandler = Handler(Looper.getMainLooper())

    private fun sendAutoClickBroadcast(intent: Intent) {
        // Keep the broadcast inside this app so the AccessibilityService receiver gets it reliably.
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    private fun markShowDotPending() {
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE).edit {
            putBoolean("flutter.autoclick_show_dot_pending", true)
        }
    }

    private fun clearShowDotPending() {
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE).edit {
            putBoolean("flutter.autoclick_show_dot_pending", false)
        }
    }

    private fun sendWithRetry(intent: Intent, retries: Int = 5, stepMs: Long = 250L) {
        for (i in 0..retries) {
            mainHandler.postDelayed({
                sendAutoClickBroadcast(Intent(intent))
            }, i * stepMs)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        // Check if accessibility service is enabled first
                        if (isAccessibilityServiceEnabled()) {
                            markShowDotPending()
                            // Send broadcast to show the dot
                            val intent = Intent(ClickAccessibilityService.ACTION_SHOW_DOT)
                            sendWithRetry(intent)
                            result.success("Dot show command sent")
                        } else {
                            result.error("NOT_ENABLED", "Accessibility service is not enabled. Please enable it in settings first.", null)
                        }
                    }
                    "startAutoclick" -> {
                        if (!isAccessibilityServiceEnabled()) {
                            result.error("NOT_ENABLED", "Accessibility service is not enabled. Please enable it in settings first.", null)
                            return@setMethodCallHandler
                        }
                        val args = call.arguments as Map<*, *>
                        val x = (args["x"] as Number).toInt()
                        val y = (args["y"] as Number).toInt()
                        val delay = (args["delay"] as Number).toLong()
                        markShowDotPending()
                        // Ensure the dot is shown before starting click loop.
                        sendWithRetry(Intent(ClickAccessibilityService.ACTION_SHOW_DOT), retries = 3, stepMs = 180L)

                        val intent = Intent(ClickAccessibilityService.ACTION_START_AUTOCLICK).apply {
                            putExtra("x", x)
                            putExtra("y", y)
                            putExtra("delay", delay)
                        }
                        mainHandler.postDelayed({
                            sendWithRetry(intent, retries = 2, stepMs = 120L)
                        }, 160)
                        result.success(true)
                    }
                    "stopAutoclick" -> {
                        clearShowDotPending()
                        val intent = Intent(ClickAccessibilityService.ACTION_STOP_AUTOCLICK)
                        sendAutoClickBroadcast(intent)
                        result.success(true)
                    }
                    "openAccessibilitySettings" -> {
                        val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    }
                    "isAccessibilityEnabled" -> {
                        val expectedComponentName = android.content.ComponentName(this, ClickAccessibilityService::class.java)
                        val enabledServicesSetting = android.provider.Settings.Secure.getString(contentResolver, android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
                        val colonSplitter = android.text.TextUtils.SimpleStringSplitter(':')
                        colonSplitter.setString(enabledServicesSetting)
                        var enabled = false
                        while (colonSplitter.hasNext()) {
                            val componentNameString = colonSplitter.next()
                            val enabledComponent = android.content.ComponentName.unflattenFromString(componentNameString)
                            if (enabledComponent != null && enabledComponent == expectedComponentName) {
                                enabled = true
                                break
                            }
                        }
                        result.success(enabled)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponentName = ComponentName(this, ClickAccessibilityService::class.java)
        val enabledServicesSetting = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledComponent = ComponentName.unflattenFromString(componentNameString)
            if (enabledComponent != null && enabledComponent == expectedComponentName) {
                return true
            }
        }
        return false
    }
}
