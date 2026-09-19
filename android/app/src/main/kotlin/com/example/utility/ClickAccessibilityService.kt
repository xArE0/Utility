package com.example.utility

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.graphics.Point
import android.graphics.Rect
import android.graphics.Path
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.view.doOnNextLayout
import kotlin.math.hypot
import kotlin.math.max

/**
 * Tap engine + floating controls for the Auto Clicker.
 *
 * Two overlay windows are drawn with TYPE_ACCESSIBILITY_OVERLAY (needs no "draw over other apps"
 * permission): a small draggable [TargetView] marking where taps land, and a [PanelView] that is a
 * tiny bubble until tapped, then expands to start/stop/close. The notification offers the same
 * start/stop/close. The taps themselves are injected with [dispatchGesture].
 *
 * Runs in the same process as MainActivity, so the activity talks to it directly through [instance]
 * instead of broadcasts.
 */
class ClickAccessibilityService : AccessibilityService() {

    companion object {
        /** Injected taps take a few ms to dispatch, so anything faster would overlap and be dropped. */
        const val MIN_INTERVAL_MS = 50L

        private const val TAP_DURATION_MS = 30L
        private const val TARGET_SIZE_DP = 48
        private const val PANEL_TOP_DP = 120
        private const val PANEL_EDGE_MARGIN_DP = 8

        /** After pressing start on the expanded panel, fold it back into the bubble. */
        private const val AUTO_COLLAPSE_MS = 700L

        /**
         * Delay before the first tap after pressing start. Flipping the target to non-touchable is
         * applied asynchronously by the window manager; tapping right away could land on the marker.
         */
        private const val START_GRACE_MS = 300L
        private const val MAX_CONSECUTIVE_CANCELS = 5

        private const val TAG = "AutoClicker"
        private const val PREFS = "autoclicker_overlay"
        private const val CHANNEL_ID = "autoclicker_overlay"
        private const val NOTIFICATION_ID = 4711

        /** Non-null only while Android has the service enabled and connected. */
        @Volatile
        var instance: ClickAccessibilityService? = null
            private set

        var intervalMs: Long = 500L
        /** 0 means keep going until stopped. */
        var maxClicks: Int = 0

        /** Fired on the main thread whenever overlay/run state or the tap count changes. */
        var statusListener: (() -> Unit)? = null
    }

    private val wm: WindowManager by lazy { getSystemService(Context.WINDOW_SERVICE) as WindowManager }
    private val handler = Handler(Looper.getMainLooper())
    private val tick = Runnable { performTap() }
    private val density get() = resources.displayMetrics.density

    private var target: TargetView? = null
    private var panel: PanelView? = null
    private var targetLp: WindowManager.LayoutParams? = null
    private var panelLp: WindowManager.LayoutParams? = null

    private var cancelStreak = 0
    private var lastNotifyAt = 0L

    /** Bumped on every start so a late gesture callback from a previous run can't revive the loop. */
    private var runId = 0

    var isRunning = false
        private set
    var tapCount = 0
        private set
    val overlayVisible: Boolean get() = target != null

    // ── Lifecycle ──────────────────────────────────────────────────────────

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "service connected")
        notifyStatus()
    }

    override fun onUnbind(intent: Intent?): Boolean {
        teardown()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        teardown()
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // Rotating another app changes the screen size; pull the overlays back on-screen.
        handler.post { keepOnScreen() }
    }

    private fun teardown() {
        hideOverlay()
        if (instance === this) instance = null
        notifyStatus()
    }

    // ── Overlay ────────────────────────────────────────────────────────────

    /** Shows the target + control panel. Throws [IllegalStateException] if Android refuses. */
    fun showOverlay() {
        if (target != null) return
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val screen = screenSize()

        val t = TargetView(this)
        val tSize = Point((TARGET_SIZE_DP * density).toInt(), (TARGET_SIZE_DP * density).toInt())
        // Positions are stored as the tap point (centre), so resizing the marker never shifts it.
        val tlp = overlayParams(tSize.x, tSize.y).apply {
            x = prefs.getInt("tcx", screen.x / 2) - tSize.x / 2
            y = prefs.getInt("tcy", screen.y / 2) - tSize.y / 2
        }
        clamp(tlp, tSize)

        val p = PanelView(this)
        val pSize = sizeOf(p)
        val plp = overlayParams(WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT).apply {
            x = prefs.getInt("px", screen.x - pSize.x - (PANEL_EDGE_MARGIN_DP * density).toInt())
            y = prefs.getInt("py", (PANEL_TOP_DP * density).toInt())
        }
        clamp(plp, pSize)

        try {
            wm.addView(t, tlp)
            wm.addView(p, plp) // added last so it always sits above the target
        } catch (e: Exception) {
            runCatching { wm.removeView(t) }
            runCatching { wm.removeView(p) }
            throw IllegalStateException("Couldn't draw the floating controls: ${e.message}", e)
        }

        attachDrag(handle = t, window = t, lp = tlp)
        attachDrag(handle = p.handle, window = p, lp = plp, onTap = { setExpanded(!p.expanded) })
        p.toggle.setOnClickListener {
            if (toggleClicking()) {
                handler.postDelayed({ if (isRunning) setExpanded(false) }, AUTO_COLLAPSE_MS)
            }
        }
        p.close.setOnClickListener { hideOverlay() }

        target = t
        panel = p
        targetLp = tlp
        panelLp = plp
        Log.i(TAG, "overlay shown: screen=${screen.x}x${screen.y} target=(${tlp.x},${tlp.y}) panel=(${plp.x},${plp.y})")
        postNotification()
        notifyStatus()
    }

    fun hideOverlay() {
        stopClicking(null)
        target?.let { runCatching { wm.removeView(it) } }
        panel?.let { runCatching { wm.removeView(it) } }
        target = null
        panel = null
        targetLp = null
        panelLp = null
        NotificationManagerCompat.from(this).cancel(NOTIFICATION_ID)
        notifyStatus()
    }

    private fun overlayParams(w: Int, h: Int) = WindowManager.LayoutParams(
        w, h,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.TOP or Gravity.LEFT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    /**
     * Drags [window] by touching [handle]. If [onTap] is given, a touch that stays within the touch
     * slop counts as a tap instead of a drag; without it, dragging starts immediately (precise).
     */
    private fun attachDrag(
        handle: View,
        window: View,
        lp: WindowManager.LayoutParams,
        onTap: (() -> Unit)? = null,
    ) {
        val slop = if (onTap != null) ViewConfiguration.get(this).scaledTouchSlop else 0
        var startX = 0
        var startY = 0
        var downX = 0f
        var downY = 0f
        var moved = false
        handle.setOnTouchListener { _, e ->
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = lp.x
                    startY = lp.y
                    downX = e.rawX
                    downY = e.rawY
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX
                    val dy = e.rawY - downY
                    if (!moved && hypot(dx, dy) <= slop) return@setOnTouchListener true
                    moved = true
                    lp.x = startX + dx.toInt()
                    lp.y = startY + dy.toInt()
                    clamp(lp, sizeOf(window))
                    runCatching { wm.updateViewLayout(window, lp) }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (moved || onTap == null) savePositions() else onTap()
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    if (moved) savePositions()
                    true
                }
                else -> false
            }
        }
    }

    private fun setExpanded(expanded: Boolean) {
        val p = panel ?: return
        if (p.expanded == expanded) return
        p.expanded = expanded
        // The window resizes on its next layout; once it has, pull it back on-screen if it now overhangs.
        p.doOnNextLayout { handler.post { keepOnScreen() } }
    }

    private fun keepOnScreen() {
        val t = target
        val tlp = targetLp
        if (t != null && tlp != null) {
            clamp(tlp, sizeOf(t))
            runCatching { wm.updateViewLayout(t, tlp) }
        }
        val p = panel
        val plp = panelLp
        if (p != null && plp != null) {
            clamp(plp, sizeOf(p))
            runCatching { wm.updateViewLayout(p, plp) }
        }
    }

    private fun savePositions() {
        val t = targetLp ?: return
        val p = panelLp ?: return
        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
            .putInt("tcx", t.x + t.width / 2).putInt("tcy", t.y + t.height / 2)
            .putInt("px", p.x).putInt("py", p.y)
            .apply()
    }

    private fun setTargetTouchable(touchable: Boolean) {
        val t = target ?: return
        val lp = targetLp ?: return
        lp.flags = if (touchable) {
            lp.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        } else {
            lp.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        runCatching { wm.updateViewLayout(t, lp) }
    }

    // ── Tapping ────────────────────────────────────────────────────────────

    /** Starts or stops clicking (panel and notification share this). True if this call started it. */
    fun toggleClicking(graceMs: Long = START_GRACE_MS): Boolean {
        if (isRunning) {
            stopClicking(null)
            return false
        }
        val problem = startClicking(graceMs)
        if (problem != null) toast(problem)
        return problem == null
    }

    /**
     * Starts tapping after [graceMs]. Returns a user-facing reason if it can't start, else null.
     * A longer grace is used when started from the app, so it has left the screen before tap one.
     */
    fun startClicking(graceMs: Long = START_GRACE_MS): String? {
        val t = target ?: return "Show the floating controls first."
        if (isRunning) return null

        // The panel stays touchable, so a target hidden beneath it would tap the panel itself.
        val at = tapPoint(t)
        panel?.let { p ->
            val pad = (8 * density).toInt()
            val rect = screenRect(p).apply { inset(-pad, -pad) }
            if (rect.contains(at.x, at.y)) return "Move the bubble away from the ring first."
        }

        Log.i(TAG, "start: tap=(${at.x},${at.y}) interval=${intervalMs}ms max=$maxClicks grace=${graceMs}ms")
        isRunning = true
        runId++
        tapCount = 0
        cancelStreak = 0
        // Non-touchable, so the injected taps pass through the marker to the app underneath.
        setTargetTouchable(false)
        t.running = true
        panel?.render(running = true, taps = 0)
        postNotification()
        notifyStatus()
        handler.postDelayed(tick, graceMs)
        return null
    }

    fun stopClicking(reason: String?) {
        if (!isRunning) return
        Log.i(TAG, "stop: taps=$tapCount reason=${reason ?: "user"}")
        isRunning = false
        handler.removeCallbacks(tick)
        setTargetTouchable(true)
        target?.running = false
        panel?.render(running = false, taps = tapCount)
        if (target != null) postNotification()
        notifyStatus()
        if (reason != null) toast(reason, long = true)
    }

    private fun performTap() {
        if (!isRunning) return
        val t = target ?: return stopClicking(null)

        // Read the marker's real on-screen centre instead of trusting layout params, so the tap
        // lands exactly under the crosshair whatever the status bar, cutout or density.
        val at = tapPoint(t)
        val path = Path().apply { moveTo(at.x.toFloat(), at.y.toFloat()) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0L, TAP_DURATION_MS))
            .build()

        val startedAt = SystemClock.uptimeMillis()
        val thisRun = runId
        val accepted = dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) =
                onTapFinished(thisRun, startedAt, true)

            override fun onCancelled(gestureDescription: GestureDescription?) =
                onTapFinished(thisRun, startedAt, false)
        }, handler)

        if (!accepted) Log.w(TAG, "dispatchGesture refused at (${at.x},${at.y})")
        if (!accepted) {
            stopClicking("Android refused the tap. Turn the accessibility service off and on, then try again.")
        }
    }

    /** Schedules the next tap only once the previous one has finished, so taps never overlap. */
    private fun onTapFinished(run: Int, startedAt: Long, completed: Boolean) {
        if (!isRunning || run != runId) return
        // Log the first few taps and then every 50th, so logcat shows it working without flooding.
        if (tapCount < 3 || tapCount % 50 == 0 || !completed) {
            Log.d(TAG, "tap #${tapCount + 1} ${if (completed) "completed" else "CANCELLED"}")
        }
        if (completed) {
            tapCount++
            cancelStreak = 0
        } else if (++cancelStreak >= MAX_CONSECUTIVE_CANCELS) {
            stopClicking("Taps keep getting cancelled. Is something else touching the screen?")
            return
        }
        panel?.render(running = true, taps = tapCount)
        notifyStatus(force = false)

        if (maxClicks > 0 && tapCount >= maxClicks) {
            // You're in another app by now, so say it's finished.
            stopClicking("Auto Clicker done: $tapCount taps")
            return
        }
        val nextAt = startedAt + max(intervalMs, MIN_INTERVAL_MS)
        handler.removeCallbacks(tick)
        handler.postDelayed(tick, max(0L, nextAt - SystemClock.uptimeMillis()))
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    private fun tapPoint(v: View): Point {
        val loc = IntArray(2)
        v.getLocationOnScreen(loc)
        return Point(loc[0] + v.width / 2, loc[1] + v.height / 2)
    }

    private fun screenRect(v: View): Rect {
        val loc = IntArray(2)
        v.getLocationOnScreen(loc)
        return Rect(loc[0], loc[1], loc[0] + v.width, loc[1] + v.height)
    }

    private fun sizeOf(v: View): Point {
        if (v.width > 0 && v.height > 0) return Point(v.width, v.height)
        v.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED)
        return Point(v.measuredWidth, v.measuredHeight)
    }

    private fun clamp(lp: WindowManager.LayoutParams, size: Point) {
        val screen = screenSize()
        lp.x = lp.x.coerceIn(0, max(0, screen.x - size.x))
        lp.y = lp.y.coerceIn(0, max(0, screen.y - size.y))
    }

    private fun screenSize(): Point {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val b = wm.maximumWindowMetrics.bounds
            Point(b.width(), b.height())
        } else {
            val p = Point()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealSize(p)
            p
        }
    }

    private fun toast(message: String, long: Boolean = false) {
        Toast.makeText(applicationContext, message, if (long) Toast.LENGTH_LONG else Toast.LENGTH_SHORT).show()
    }

    /** The tap count changes many times a second, so non-forced updates are rate-limited. */
    private fun notifyStatus(force: Boolean = true) {
        val now = SystemClock.uptimeMillis()
        if (!force && now - lastNotifyAt < 250L) return
        lastNotifyAt = now
        statusListener?.invoke()
    }

    /**
     * Plain (non-foreground) notification with Start/Stop and Close actions, so clicking can be
     * controlled from the shade without any floating UI. A foreground service is deliberately not
     * used: an enabled accessibility service is already kept alive by the system, and
     * startForeground() without a declared foregroundServiceType crashes on Android 14+.
     */
    private fun postNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Auto Clicker", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val toggle = if (isRunning) {
            NotificationCompat.Action(
                android.R.drawable.ic_media_pause, "Stop",
                actionIntent(AutoClickActionReceiver.ACTION_TOGGLE, 1),
            )
        } else {
            NotificationCompat.Action(
                android.R.drawable.ic_media_play, "Start",
                actionIntent(AutoClickActionReceiver.ACTION_TOGGLE, 1),
            )
        }
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Auto Clicker")
            .setContentText(if (isRunning) "Clicking\u2026" else "Ready. Place the ring, then tap Start.")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(toggle)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel, "Close",
                actionIntent(AutoClickActionReceiver.ACTION_CLOSE, 2),
            )
            .build()
        try {
            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Notification permission denied; the on-screen controls still work.
        }
    }

    private fun actionIntent(action: String, requestCode: Int): PendingIntent = PendingIntent.getBroadcast(
        this, requestCode,
        Intent(this, AutoClickActionReceiver::class.java).setAction(action),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}
