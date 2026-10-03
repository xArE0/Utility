package com.example.utility

import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
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
    private var volumeChannel: MethodChannel? = null
    private var volumeReceiver: BroadcastReceiver? = null
    private var widgetChannel: MethodChannel? = null
    private var widgetListener: (() -> Unit)? = null
    private var statusListener: (() -> Unit)? = null
    private var systemChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTOCLICKER_CHANNEL)
        ch.setMethodCallHandler { call, result -> handleAutoClicker(call, result) }
        channel = ch

        // Push overlay/run changes to Dart as they happen (already on the main thread).
        val listener: () -> Unit = { ch.invokeMethod("status", status()) }
        statusListener = listener
        ClickAccessibilityService.statusListener = listener

        val volume = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL)
        volume.setMethodCallHandler { call, result -> handleVolume(call, result) }
        volumeChannel = volume

        // Catch up on changes missed while the app was force-stopped (which also clears alarms).
        VolumeScheduler.sync(applicationContext)

        val widget = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
        widget.setMethodCallHandler { call, result -> handleWidget(call, result) }
        widgetChannel = widget
        UtilityWidget.restore(applicationContext, dropExpired = true)
        val onWidgetChanged: () -> Unit = { widget.invokeMethod("changed", null) }
        widgetListener = onWidgetChanged
        UtilityWidget.listener = onWidgetChanged

        val system = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL)
        val systemHandler = SystemChannel(this)
        system.setMethodCallHandler { call, result -> systemHandler.handle(call, result) }
        systemChannel = system
    }

    override fun onResume() {
        super.onResume()
        // Permission granted in Settings meanwhile? Swap the widget's stay-awake button over.
        UtilityWidget.render(applicationContext)
        widgetListener?.invoke()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Only unhook if it is still ours; a recreated activity may already have replaced it.
        if (ClickAccessibilityService.statusListener === statusListener) {
            ClickAccessibilityService.statusListener = null
        }
        statusListener = null
        channel?.setMethodCallHandler(null)
        channel = null
        stopVolumeListening()
        volumeChannel?.setMethodCallHandler(null)
        volumeChannel = null
        if (UtilityWidget.listener === widgetListener) UtilityWidget.listener = null
        widgetListener = null
        widgetChannel?.setMethodCallHandler(null)
        widgetChannel = null
        systemChannel?.setMethodCallHandler(null)
        systemChannel = null
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

            "startRecording" -> {
                val service = ClickAccessibilityService.instance
                if (service == null) {
                    result.error("SERVICE_NOT_RUNNING", "The accessibility service isn't running.", null)
                    return
                }
                val problem = service.startRecording(APP_START_DELAY_MS)
                if (problem != null) result.error("CANNOT_RECORD", problem, null) else result.success(null)
            }

            "stopRecording" -> {
                ClickAccessibilityService.instance?.stopRecording(save = true)
                result.success(null)
            }

            "getRecordings" -> result.success(RecordingStore.all(applicationContext).map { it.summary() })

            "renameRecording" -> {
                RecordingStore.rename(applicationContext, call.argument<String>("id") ?: "", call.argument<String>("name") ?: "")
                ClickAccessibilityService.recordingsVersion++
                result.success(null)
            }

            "deleteRecording" -> {
                val id = call.argument<String>("id") ?: ""
                RecordingStore.delete(applicationContext, id)
                if (ClickAccessibilityService.recordingId == id) ClickAccessibilityService.recordingId = null
                ClickAccessibilityService.recordingsVersion++
                ClickAccessibilityService.instance?.onConfigChanged()
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

            "openAutostartSettings" -> openAutostartSettings(result)

            else -> result.notImplemented()
        }
    }

    private fun handleVolume(call: MethodCall, result: MethodChannel.Result) {
        val ctx = applicationContext
        when (call.method) {
            "getRules" -> result.success(VolumeScheduler.getRulesJson(ctx))

            "saveRules" -> {
                try {
                    VolumeScheduler.saveRules(ctx, call.argument<String>("json") ?: "[]")
                    result.success(null)
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message ?: "Couldn't save the volume schedule.", null)
                }
            }

            "applyNow" -> {
                val problem = VolumeScheduler.applyRuleNow(ctx, call.argument<String>("id") ?: "")
                if (problem != null) result.error("APPLY_FAILED", problem, null) else result.success(null)
            }

            "getState" -> result.success(
                mapOf(
                    "streams" to VolumeScheduler.streamInfo(ctx),
                    "ringerMode" to VolumeScheduler.ringerMode(ctx),
                    "nextChangeMs" to VolumeScheduler.nextChangeMs(ctx),
                    "log" to VolumeScheduler.getLogJson(ctx),
                    "isXiaomi" to isXiaomiFamily(),
                    "autostart" to autostartState(),
                ),
            )

            "openAutostartSettings" -> openAutostartSettings(result)

            "startListening" -> {
                startVolumeListening()
                result.success(null)
            }

            "stopListening" -> {
                stopVolumeListening()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun handleWidget(call: MethodCall, result: MethodChannel.Result) {
        val ctx = applicationContext
        when (call.method) {
            "getState" -> result.success(UtilityWidget.state(ctx))

            "configure" -> {
                UtilityWidget.configure(
                    ctx,
                    call.argument<Int>("timer1") ?: 5,
                    call.argument<Int>("timer2") ?: 15,
                    call.argument<Int>("awakeMinutes") ?: 10,
                )
                result.success(null)
            }

            "setAqi" -> {
                UtilityWidget.setAqi(ctx, call.argument<String>("text") ?: "")
                result.success(null)
            }

            "cancelTimer" -> {
                UtilityWidget.cancelTimer(ctx)
                result.success(null)
            }

            "openWriteSettings" -> openSettings(
                result,
                Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, Uri.parse("package:$packageName")),
            )

            else -> result.notImplemented()
        }
    }

    /**
     * Pushes "changed" to Dart on any volume or ringer mode change, so the Volume Schedule screen
     * stays live. Registered only while that screen is visible.
     */
    private fun startVolumeListening() {
        if (volumeReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                volumeChannel?.invokeMethod("changed", null)
            }
        }
        val filter = IntentFilter().apply {
            addAction(VOLUME_CHANGED_ACTION)
            addAction(AudioManager.RINGER_MODE_CHANGED_ACTION)
        }
        // System broadcasts still arrive with NOT_EXPORTED; the flag is mandatory on API 34+.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
        volumeReceiver = receiver
    }

    private fun stopVolumeListening() {
        volumeReceiver?.let { unregisterReceiver(it) }
        volumeReceiver = null
    }

    private fun openAutostartSettings(result: MethodChannel.Result) {
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

    private fun applyConfig(call: MethodCall) {
        call.argument<Number>("intervalMs")?.let {
            ClickAccessibilityService.intervalMs = maxOf(it.toLong(), ClickAccessibilityService.MIN_INTERVAL_MS)
        }
        call.argument<Number>("maxClicks")?.let {
            ClickAccessibilityService.maxClicks = maxOf(it.toInt(), 0)
        }
        call.argument<String>("mode")?.let { ClickAccessibilityService.mode = it }
        call.argument<String>("scrollDirection")?.let { ClickAccessibilityService.scrollDirection = it }
        call.argument<Number>("scrollDistancePct")?.let { ClickAccessibilityService.scrollDistancePct = it.toInt() }
        call.argument<Number>("swipeMs")?.let { ClickAccessibilityService.swipeMs = it.toLong() }
        if (call.hasArgument("recordingId")) ClickAccessibilityService.recordingId = call.argument<String>("recordingId")
        ClickAccessibilityService.instance?.onConfigChanged()
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
            "recording" to (service?.isRecording ?: false),
            "recordedCount" to (service?.recordedCount ?: 0),
            "mode" to ClickAccessibilityService.mode,
            "recordingId" to (ClickAccessibilityService.recordingId ?: ""),
            "recordingsVersion" to ClickAccessibilityService.recordingsVersion,
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

    /**
     * MIUI/HyperOS keeps Autostart as a private app-op (10008) with no public API. Reading it via
     * reflection is the only way to know; returns "allowed", "denied", or "unknown" (not Xiaomi,
     * or the ROM changed and the check failed).
     */
    private fun autostartState(): String {
        if (!isXiaomiFamily()) return "unknown"
        return try {
            val appOps = getSystemService(android.app.AppOpsManager::class.java)
            val method = android.app.AppOpsManager::class.java.getMethod(
                "checkOpNoThrow",
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
                String::class.java,
            )
            val mode = method.invoke(appOps, MIUI_OP_AUTO_START, applicationInfo.uid, packageName) as Int
            if (mode == android.app.AppOpsManager.MODE_ALLOWED) "allowed" else "denied"
        } catch (_: Exception) {
            "unknown"
        }
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
        const val VOLUME_CHANNEL = "com.example.utility/volume"
        const val WIDGET_CHANNEL = "com.example.utility/widget"
        const val SYSTEM_CHANNEL = "com.example.utility/system"

        const val MIUI_OP_AUTO_START = 10008

        /** Not in the public SDK, but sent by every Android version on any stream volume change. */
        const val VOLUME_CHANGED_ACTION = "android.media.VOLUME_CHANGED_ACTION"

        /** When started from this app, wait for it to finish leaving the screen before the first tap. */
        const val APP_START_DELAY_MS = 1500L

        /** Tried in order; the activity name has moved across MIUI/HyperOS versions. */
        val AUTOSTART_ACTIVITIES = listOf(
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            "com.miui.securitycenter" to "com.miui.autostart.AutoStartManagementActivity",
        )
    }
}
