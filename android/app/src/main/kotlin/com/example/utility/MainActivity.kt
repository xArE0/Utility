package com.example.utility

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "floating_dot"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        // Check if accessibility service is enabled first
                        if (isAccessibilityServiceEnabled()) {
                            // Send broadcast to show the dot
                            val intent = Intent(ClickAccessibilityService.ACTION_SHOW_DOT)
                            sendBroadcast(intent)
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
                        val intent = Intent(ClickAccessibilityService.ACTION_START_AUTOCLICK).apply {
                            putExtra("x", x)
                            putExtra("y", y)
                            putExtra("delay", delay)
                        }
                        sendBroadcast(intent)
                        result.success(true)
                    }
                    "stopAutoclick" -> {
                        val intent = Intent(ClickAccessibilityService.ACTION_STOP_AUTOCLICK)
                        sendBroadcast(intent)
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
