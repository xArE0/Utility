package com.example.utility

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.os.SystemClock
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone
import kotlin.math.roundToLong

/**
 * Small platform services for the Dart side ("com.example.utility/system"):
 * - timezone: the device's IANA zone, so reminders follow the phone rather than a fixed zone.
 * - currentLocation: one coarse fix for the weather location. A recent cached fix is used when
 *   there is one; otherwise a single network/fused request with a timeout — never GPS, never
 *   continuous, nothing left running.
 * - copySensitive: clipboard copy flagged as sensitive (hidden from previews on Android 13+) and
 *   cleared again after [CLIPBOARD_CLEAR_MS], unless something else was copied meanwhile.
 * - setSecure: FLAG_SECURE on/off, blocking screenshots and the recents thumbnail (vault).
 */
class SystemChannel(private val activity: Activity) {
    private val main = Handler(Looper.getMainLooper())
    private var clipboardListener: ClipboardManager.OnPrimaryClipChangedListener? = null
    private var clearClipboard: Runnable? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "timezone" -> result.success(TimeZone.getDefault().id)
            "currentLocation" -> currentLocation(result)
            "copySensitive" -> {
                copySensitive(call.argument<String>("text") ?: "")
                result.success(null)
            }
            "setSecure" -> {
                if (call.argument<Boolean>("secure") == true) {
                    activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ── Location ──────────────────────────────────────────────────────────────

    private fun currentLocation(result: MethodChannel.Result) {
        if (activity.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            result.error("NO_PERMISSION", "Location permission not granted.", null)
            return
        }
        val lm = activity.getSystemService(LocationManager::class.java) ?: run {
            result.error("LOCATION_OFF", "No location service.", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && !lm.isLocationEnabled) {
            result.error("LOCATION_OFF", "Location is switched off.", null)
            return
        }
        val providers = lm.getProviders(true).filter { it != LocationManager.GPS_PROVIDER }

        // A fix another app (or the system) got recently costs nothing to reuse.
        val cached = providers
            .mapNotNull { p -> try { lm.getLastKnownLocation(p) } catch (_: SecurityException) { null } }
            .filter { SystemClock.elapsedRealtimeNanos() - it.elapsedRealtimeNanos < MAX_CACHED_AGE_NS }
            .maxByOrNull { it.elapsedRealtimeNanos }
        if (cached != null) {
            result.success(coarse(cached))
            return
        }

        val provider = when {
            "fused" in providers -> "fused"
            LocationManager.NETWORK_PROVIDER in providers -> LocationManager.NETWORK_PROVIDER
            else -> {
                result.error("LOCATION_OFF", "No network location available.", null)
                return
            }
        }

        var done = false
        fun finish(location: Location?) {
            if (done) return
            done = true
            if (location != null) {
                result.success(coarse(location))
            } else {
                result.error("TIMEOUT", "Couldn't get a location fix.", null)
            }
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val cancel = CancellationSignal()
                main.postDelayed({ cancel.cancel(); finish(null) }, FIX_TIMEOUT_MS)
                lm.getCurrentLocation(provider, cancel, activity.mainExecutor) { finish(it) }
            } else {
                val listener = object : LocationListener {
                    override fun onLocationChanged(location: Location) = finish(location)
                    @Deprecated("Deprecated in Java")
                    override fun onStatusChanged(p: String?, s: Int, e: android.os.Bundle?) {}
                    override fun onProviderEnabled(p: String) {}
                    override fun onProviderDisabled(p: String) {}
                }
                main.postDelayed({ lm.removeUpdates(listener); finish(null) }, FIX_TIMEOUT_MS)
                @Suppress("DEPRECATION")
                lm.requestSingleUpdate(provider, listener, Looper.getMainLooper())
            }
        } catch (e: SecurityException) {
            done = true
            result.error("NO_PERMISSION", e.message ?: "Location permission not granted.", null)
        }
    }

    /** Rounded to 2 decimals (~1 km): enough for weather, and no more precise than it needs to be. */
    private fun coarse(location: Location) = mapOf(
        "lat" to (location.latitude * 100).roundToLong() / 100.0,
        "lon" to (location.longitude * 100).roundToLong() / 100.0,
    )

    // ── Clipboard ─────────────────────────────────────────────────────────────

    private fun copySensitive(text: String) {
        val clipboard = activity.getSystemService(ClipboardManager::class.java) ?: return
        cancelPendingClear(clipboard)

        val clip = ClipData.newPlainText("Utility", text)
        clip.description.extras = PersistableBundle().apply {
            // ClipDescription.EXTRA_IS_SENSITIVE on API 33+; the literal also works on some older ROMs.
            putBoolean("android.content.extra.IS_SENSITIVE", true)
        }
        clipboard.setPrimaryClip(clip)

        // Registered after our own copy, so any change it sees is someone else's.
        val listener = ClipboardManager.OnPrimaryClipChangedListener { cancelPendingClear(clipboard) }
        clipboard.addPrimaryClipChangedListener(listener)
        clipboardListener = listener
        val clear = Runnable {
            cancelPendingClear(clipboard)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    clipboard.clearPrimaryClip()
                } else {
                    clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
                }
            } catch (_: Exception) {
            }
        }
        clearClipboard = clear
        main.postDelayed(clear, CLIPBOARD_CLEAR_MS)
    }

    private fun cancelPendingClear(clipboard: ClipboardManager) {
        clearClipboard?.let { main.removeCallbacks(it) }
        clearClipboard = null
        clipboardListener?.let { clipboard.removePrimaryClipChangedListener(it) }
        clipboardListener = null
    }

    private companion object {
        const val FIX_TIMEOUT_MS = 20_000L
        const val MAX_CACHED_AGE_NS = 30L * 60 * 1_000_000_000 // 30 min
        const val CLIPBOARD_CLEAR_MS = 30_000L
    }
}
