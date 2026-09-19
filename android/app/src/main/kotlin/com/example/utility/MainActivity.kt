package com.example.utility

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private var channel: MethodChannel? = null
    private var statusListener: (() -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTOCLICKER_CHANNEL)
        ch.setMethodCallHandler { call, result -> handleAutoClicker(call, result) }
        channel = ch

        // Push overlay/run changes to Dart as they happen (already on the main thread).
        val listener: () -> Unit = { ch.invokeMethod("status", status()) }
        statusListener = listener
        ClickAccessibilityService.statusListener = listener
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Only unhook if it is still ours; a recreated activity may already have replaced it.
        if (ClickAccessibilityService.statusListener === statusListener) {
            ClickAccessibilityService.statusListener = null
        }
        statusListener = null
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun handleAutoClicker(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(status())

            "updateConfig" -> {
                applyConfig(call)
                result.success(null)
            }

            "showOverlay" -> {
                applyConfig(call)
                val service = ClickAccessibilityService.instance
                if (service == null) {
                    result.error(
                        "SERVICE_NOT_RUNNING",
                        if (isServiceEnabledInSettings()) {
                            "The accessibility service is switched on but not running yet. " +
                                "Switch it off and on again in Accessibility settings."
                        } else {
                            "Turn on \"Utility Auto Clicker\" in Accessibility settings first."
                        },
                        null,
                    )
                    return
                }
                try {
                    service.showOverlay()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("OVERLAY_FAILED", e.message ?: "Couldn't show the floating controls.", null)
                }
            }

            "hideOverlay" -> {
                ClickAccessibilityService.instance?.hideOverlay()
                result.success(null)
            }

            "startClicking" -> {
                val service = ClickAccessibilityService.instance
                if (service == null) {
                    result.error("SERVICE_NOT_RUNNING", "The accessibility service isn't running.", null)
                    return
                }
                val problem = service.startClicking(APP_START_DELAY_MS)
                if (problem != null) result.error("CANNOT_START", problem, null) else result.success(null)
            }

            "stopClicking" -> {
                ClickAccessibilityService.instance?.stopClicking(null)
                result.success(null)
            }

            "moveToBackground" -> {
                moveTaskToBack(true)
                result.success(null)
            }

            "openAccessibilitySettings" -> openSettings(result, Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))

            "openAppInfo" -> openSettings(
                result,
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)),
            )

            "openAutostartSettings" -> {
                val opened = AUTOSTART_ACTIVITIES.any { (pkg, cls) ->
                    try {
                        startActivity(
                            Intent().apply {
                                component = ComponentName(pkg, cls)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            },
                        )
                        true
                    } catch (_: ActivityNotFoundException) {
                        false
                    } catch (_: SecurityException) {
                        false
                    }
                }
                if (opened) {
                    result.success(null)
                } else {
                    result.error(
                        "AUTOSTART_UNAVAILABLE",
                        "Couldn't find the Autostart screen. Open the Security app manually: " +
                            "Permissions → Autostart → Utility.",
                        null,
                    )
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun applyConfig(call: MethodCall) {
        call.argument<Number>("intervalMs")?.let {
            ClickAccessibilityService.intervalMs = maxOf(it.toLong(), ClickAccessibilityService.MIN_INTERVAL_MS)
        }
        call.argument<Number>("maxClicks")?.let {
            ClickAccessibilityService.maxClicks = maxOf(it.toInt(), 0)
        }
    }

    private fun openSettings(result: MethodChannel.Result, intent: Intent) {
        try {
            startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("SETTINGS_UNAVAILABLE", e.message ?: "Couldn't open settings.", null)
        }
    }

    private fun status(): Map<String, Any> {
        val service = ClickAccessibilityService.instance
        return mapOf(
            "serviceConnected" to (service != null),
            "serviceEnabled" to (service != null || isServiceEnabledInSettings()),
            "overlayVisible" to (service?.overlayVisible ?: false),
            "running" to (service?.isRunning ?: false),
            "taps" to (service?.tapCount ?: 0),
            "isXiaomi" to isXiaomiFamily(),
        )
    }

    /**
     * Xiaomi/Redmi/POCO devices (MIUI/HyperOS) kill backgrounded apps to save battery unless
     * "Autostart" is granted — a manufacturer setting with no standard Android equivalent, and the
     * most common reason the accessibility service shows enabled but not connected after a while.
     */
    private fun isXiaomiFamily(): Boolean {
        val brand = Build.MANUFACTURER.lowercase()
        return brand.contains("xiaomi") || brand.contains("redmi") || brand.contains("poco")
    }

    /** True if the user has switched the service on in Settings (it may not have connected yet). */
    private fun isServiceEnabledInSettings(): Boolean {
        val expected = ComponentName(this, ClickAccessibilityService::class.java)
        val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        while (splitter.hasNext()) {
            if (ComponentName.unflattenFromString(splitter.next()) == expected) return true
        }
        return false
    }

    private companion object {
        const val AUTOCLICKER_CHANNEL = "com.example.utility/autoclicker"

        /** When started from this app, wait for it to finish leaving the screen before the first tap. */
        const val APP_START_DELAY_MS = 1500L

        /** Tried in order; the activity name has moved across MIUI/HyperOS versions. */
        val AUTOSTART_ACTIVITIES = listOf(
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            "com.miui.securitycenter" to "com.miui.autostart.AutoStartManagementActivity",
        )
    }
}
