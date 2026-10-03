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
 * tiny bubble until tapped, then expands to start/stop/record/close. The notification offers the
 * same start/stop/close. Touches are injected with [dispatchGesture].
 *
 * Modes: click (tap the ring), scroll (swipe through the ring) and play (replay a [Recording]).
 * Recording puts a full-screen [CaptureView] over everything; each touch it catches is stored and
 * immediately replayed to the app underneath, so the app still reacts.
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

        const val MODE_CLICK = "click"
        const val MODE_SCROLL = "scroll"
        const val MODE_PLAY = "play"

        var intervalMs: Long = 500L
        /** 0 means keep going until stopped. Counts taps, swipes, or replay loops, by mode. */
        var maxClicks: Int = 0
        var mode: String = MODE_CLICK

        /** Which way the finger moves: "up" scrolls content down (next item), like a reel swipe. */
        var scrollDirection: String = "up"
        /** Swipe length as a share of the screen's height (or width, sideways). */
        var scrollDistancePct: Int = 50
        var swipeMs: Long = 350L

        /** The recording play mode replays. */
        var recordingId: String? = null
        /** Bumped whenever a recording is saved, so the app knows to reload its list. */
        var recordingsVersion: Int = 0

        /** Recordings start counting from the first touch, so a slow start isn't replayed. */
        private const val FIRST_STEP_MAX_DELAY_MS = 1500L
        /** Pause between replay loops, so the end of one and the start of the next stay distinct. */
        private const val LOOP_GAP_MS = 500L
        /** Time for Android to apply "not touchable" before a touch is replayed through the layer. */
        private const val PASS_THROUGH_DELAY_MS = 80L

        /** Fired on the main thread whenever overlay/run state or the tap count changes. */
        var statusListener: (() -> Unit)? = null
    }

    private val wm: WindowManager by lazy { getSystemService(Context.WINDOW_SERVICE) as WindowManager }
    private val handler = Handler(Looper.getMainLooper())
    private val tick = Runnable { performStep() }
    private val density get() = resources.displayMetrics.density

    private var target: TargetView? = null
    private var panel: PanelView? = null
    private var targetLp: WindowManager.LayoutParams? = null
    private var panelLp: WindowManager.LayoutParams? = null

    private var capture: CaptureView? = null
    private var captureLp: WindowManager.LayoutParams? = null
    private val recordedSteps = ArrayList<RecordedStep>()
    private var recordStartAt = 0L
    private var lastStepAt = 0L
    private var recordSize = Point()
    /** A recorded touch is being replayed through the capture layer; anything it catches now is ignored. */
    private var passingThrough = false

    private var playing: Recording? = null
    private var playIndex = 0
    private var playScaleX = 1f
    private var playScaleY = 1f

    private var cancelStreak = 0
    private var lastNotifyAt = 0L

    /** Bumped on every start so a late gesture callback from a previous run can't revive the loop. */
    private var runId = 0

    var isRunning = false
        private set
    var tapCount = 0
        private set
    var isRecording = false
        private set
    val recordedCount: Int get() = recordedSteps.size
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

        p.record.setOnClickListener {
            startRecording()?.let { toast(it) } ?: setExpanded(false)
        }

        target = t
        panel = p
        targetLp = tlp
        panelLp = plp
        updateTargetVisibility()
        Log.i(TAG, "overlay shown: screen=${screen.x}x${screen.y} target=(${tlp.x},${tlp.y}) panel=(${plp.x},${plp.y})")
        postNotification()
        notifyStatus()
    }

    fun hideOverlay() {
        stopRecording(save = true)
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

    // ── Running: click / scroll / play ─────────────────────────────────────

    /** Starts or stops (panel and notification share this). True if this call started something. */
    fun toggleClicking(graceMs: Long = START_GRACE_MS): Boolean {
        if (isRecording) {
            stopRecording(save = true)
            return false
        }
        if (isRunning) {
            stopClicking(null)
            return false
        }
        val problem = startClicking(graceMs)
        if (problem != null) toast(problem)
        return problem == null
    }

    /**
     * Starts the current [mode] after [graceMs]. Returns a user-facing reason if it can't, else null.
     * A longer grace is used when started from the app, so it has left the screen before step one.
     */
    fun startClicking(graceMs: Long = START_GRACE_MS): String? {
        val t = target ?: return "Show the floating controls first."
        if (isRunning) return null
        if (isRecording) return "Stop recording first."

        if (mode == MODE_PLAY) {
            val rec = RecordingStore.get(this, recordingId) ?: return "Choose a recording to replay first."
            if (rec.steps.isEmpty()) return "That recording is empty."
            // Recorded on a different screen size (or the other way round): scale the touches to fit.
            val screen = screenSize()
            playScaleX = if (rec.width > 0) screen.x.toFloat() / rec.width else 1f
            playScaleY = if (rec.height > 0) screen.y.toFloat() / rec.height else 1f
            playing = rec
            playIndex = 0
            Log.i(TAG, "play: ${rec.name} steps=${rec.steps.size} loops=$maxClicks grace=${graceMs}ms")
        } else {
            // The panel stays touchable, so a target hidden beneath it would touch the panel itself.
            val at = tapPoint(t)
            panel?.let { p ->
                val pad = (8 * density).toInt()
                val rect = screenRect(p).apply { inset(-pad, -pad) }
                if (rect.contains(at.x, at.y)) return "Move the bubble away from the ring first."
            }
            Log.i(TAG, "start $mode: at=(${at.x},${at.y}) interval=${intervalMs}ms max=$maxClicks grace=${graceMs}ms")
        }

        isRunning = true
        runId++
        tapCount = 0
        cancelStreak = 0
        // Non-touchable, so the injected touches pass through the marker to the app underneath.
        setTargetTouchable(false)
        t.running = true
        updateTargetVisibility()
        panel?.render(running = true, taps = 0)
        postNotification()
        notifyStatus()
        handler.postDelayed(tick, graceMs)
        return null
    }

    fun stopClicking(reason: String?) {
        if (!isRunning) return
        Log.i(TAG, "stop: count=$tapCount reason=${reason ?: "user"}")
        isRunning = false
        playing = null
        handler.removeCallbacks(tick)
        target?.running = false
        updateTargetVisibility()
        panel?.render(running = false, taps = tapCount)
        if (target != null) postNotification()
        notifyStatus()
        if (reason != null) toast(reason, long = true)
    }

    /** Called after the app changes settings; the ring only shows in modes that use it. */
    fun onConfigChanged() {
        if (!isRunning) updateTargetVisibility()
        if (target != null) postNotification()
        notifyStatus()
    }

    private fun performStep() {
        if (!isRunning) return
        if (playing != null) return playStep()
        val t = target ?: return stopClicking(null)

        // Read the marker's real on-screen centre instead of trusting layout params, so the touch
        // lands exactly under the crosshair whatever the status bar, cutout or density.
        val at = tapPoint(t)
        val stroke = if (mode == MODE_SCROLL) {
            swipeThrough(at)
        } else {
            GestureDescription.StrokeDescription(
                Path().apply { moveTo(at.x.toFloat(), at.y.toFloat()) }, 0L, TAP_DURATION_MS,
            )
        }
        val startedAt = SystemClock.uptimeMillis()
        val thisRun = runId
        dispatch(stroke) { completed -> onStepFinished(thisRun, startedAt, completed) }
    }

    /** A straight swipe centred on [at], [scrollDistancePct] of the screen long, kept off the edges. */
    private fun swipeThrough(at: Point): GestureDescription.StrokeDescription {
        val screen = screenSize()
        val margin = 24 * density
        val vertical = scrollDirection == "up" || scrollDirection == "down"
        val half = (if (vertical) screen.y else screen.x) * scrollDistancePct.coerceIn(10, 90) / 200f
        val (dx, dy) = when (scrollDirection) {
            "up" -> 0f to -half
            "down" -> 0f to half
            "left" -> -half to 0f
            else -> half to 0f
        }
        fun cx(v: Float) = v.coerceIn(margin, screen.x - margin)
        fun cy(v: Float) = v.coerceIn(margin, screen.y - margin)
        val path = Path().apply {
            moveTo(cx(at.x - dx), cy(at.y - dy))
            lineTo(cx(at.x + dx), cy(at.y + dy))
        }
        return GestureDescription.StrokeDescription(path, 0L, swipeMs.coerceIn(50L, 3000L))
    }

    /** Schedules the next step only once the previous one has finished, so they never overlap. */
    private fun onStepFinished(run: Int, startedAt: Long, completed: Boolean) {
        if (!isRunning || run != runId) return
        // Log the first few and then every 50th, so logcat shows it working without flooding.
        if (tapCount < 3 || tapCount % 50 == 0 || !completed) {
            Log.d(TAG, "$mode #${tapCount + 1} ${if (completed) "completed" else "CANCELLED"}")
        }
        if (completed) {
            tapCount++
            cancelStreak = 0
        } else if (++cancelStreak >= MAX_CONSECUTIVE_CANCELS) {
            stopClicking("Touches keep getting cancelled. Is something else touching the screen?")
            return
        }
        panel?.render(running = true, taps = tapCount)
        notifyStatus(force = false)

        if (maxClicks > 0 && tapCount >= maxClicks) {
            // You're in another app by now, so say it's finished.
            stopClicking("Auto Clicker done: $tapCount ${if (mode == MODE_SCROLL) "swipes" else "taps"}")
            return
        }
        // A swipe needs to finish (plus a moment for the list to settle) before the next one.
        val minGap = if (mode == MODE_SCROLL) swipeMs + 150L else MIN_INTERVAL_MS
        val nextAt = startedAt + max(intervalMs, minGap)
        handler.removeCallbacks(tick)
        handler.postDelayed(tick, max(0L, nextAt - SystemClock.uptimeMillis()))
    }

    // ── Replay ─────────────────────────────────────────────────────────────

    private fun playStep() {
        val rec = playing ?: return
        val step = rec.steps[playIndex]
        val startedAt = SystemClock.uptimeMillis()
        val thisRun = runId
        dispatch(strokeFor(step.points, step.durationMs, playScaleX, playScaleY)) { completed ->
            onPlayStepFinished(thisRun, startedAt, completed)
        }
    }

    /** Next touch at its recorded offset from this one's start; after the last, loop or finish. */
    private fun onPlayStepFinished(run: Int, startedAt: Long, completed: Boolean) {
        if (!isRunning || run != runId) return
        val rec = playing ?: return
        if (completed) {
            cancelStreak = 0
        } else if (++cancelStreak >= MAX_CONSECUTIVE_CANCELS) {
            stopClicking("Replay keeps getting interrupted. Is something else touching the screen?")
            return
        }
        val next = playIndex + 1
        val nextAt: Long
        if (next < rec.steps.size) {
            playIndex = next
            nextAt = startedAt + rec.steps[next].delayMs
        } else {
            tapCount++ // one full loop
            panel?.render(running = true, taps = tapCount)
            notifyStatus(force = false)
            if (maxClicks > 0 && tapCount >= maxClicks) {
                stopClicking("Replay done: ${rec.name}, $tapCount ${if (tapCount == 1) "time" else "times"}")
                return
            }
            playIndex = 0
            nextAt = SystemClock.uptimeMillis() + max(LOOP_GAP_MS, rec.steps[0].delayMs)
        }
        handler.removeCallbacks(tick)
        handler.postDelayed(tick, max(0L, nextAt - SystemClock.uptimeMillis()))
    }

    // ── Recording ──────────────────────────────────────────────────────────

    /** Starts catching touches after [graceMs] (so the tap that started it isn't recorded). */
    fun startRecording(graceMs: Long = START_GRACE_MS): String? {
        if (target == null) return "Show the floating controls first."
        if (isRecording) return null
        stopClicking(null)

        val view = CaptureView(this) { down, up, points -> onRecordedStroke(down, up, points) }
        val lp = overlayParams(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
        isRecording = true
        recordedSteps.clear()
        recordSize = screenSize()
        passingThrough = false
        capture = view
        captureLp = lp
        updateTargetVisibility()
        panel?.render(running = false, taps = 0, recording = true)
        postNotification()
        notifyStatus()

        handler.postDelayed({
            if (!isRecording || capture !== view) return@postDelayed
            try {
                wm.addView(view, lp)
                raisePanel() // the controls must stay above the capture layer, or Stop can't be tapped
            } catch (e: Exception) {
                Log.w(TAG, "capture layer refused", e)
                capture = null
                isRecording = false
                updateTargetVisibility()
                panel?.render(running = false, taps = 0)
                notifyStatus()
                toast("Couldn't start recording: ${e.message}")
                return@postDelayed
            }
            recordStartAt = SystemClock.uptimeMillis()
            Log.i(TAG, "recording started")
        }, graceMs)
        return null
    }

    /** Ends recording; with [save] and at least one touch, stores it and selects it for replay. */
    fun stopRecording(save: Boolean) {
        if (!isRecording) return
        isRecording = false
        passingThrough = false
        capture?.let { runCatching { wm.removeView(it) } }
        capture = null
        captureLp = null
        val steps = recordedSteps.toList()
        recordedSteps.clear()
        if (save && steps.isNotEmpty()) {
            val rec = RecordingStore.add(this, steps, recordSize.x, recordSize.y)
            recordingId = rec.id
            mode = MODE_PLAY // so ▶ replays what was just recorded
            recordingsVersion++
            Log.i(TAG, "recording saved: ${rec.name} steps=${steps.size}")
            toast("Saved ${rec.name} · ${steps.size} ${if (steps.size == 1) "touch" else "touches"}. Tap ▶ to replay.", long = true)
        } else if (save) {
            toast("Nothing was recorded.")
        }
        updateTargetVisibility()
        panel?.render(running = false, taps = 0)
        if (target != null) postNotification()
        notifyStatus()
    }

    private fun onRecordedStroke(downAt: Long, upAt: Long, points: FloatArray) {
        if (!isRecording || passingThrough || points.isEmpty()) return
        val delay = if (recordedSteps.isEmpty()) {
            (downAt - recordStartAt).coerceIn(0L, FIRST_STEP_MAX_DELAY_MS)
        } else {
            downAt - lastStepAt
        }
        lastStepAt = downAt
        val duration = (upAt - downAt).coerceAtLeast(1L)
        recordedSteps.add(RecordedStep(delay, duration, points))
        panel?.render(running = false, taps = recordedSteps.size, recording = true)
        notifyStatus(force = false)

        // Hand the touch on: let it through the capture layer, replay it, then catch the next one.
        passingThrough = true
        setCaptureTouchable(false)
        handler.postDelayed({
            if (!isRecording) return@postDelayed
            dispatch(strokeFor(points, duration, 1f, 1f)) {
                passingThrough = false
                setCaptureTouchable(true)
            }
        }, PASS_THROUGH_DELAY_MS)
    }

    private fun setCaptureTouchable(touchable: Boolean) {
        val v = capture ?: return
        val lp = captureLp ?: return
        lp.flags = if (touchable) {
            lp.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        } else {
            lp.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        runCatching { wm.updateViewLayout(v, lp) }
    }

    /** Re-adds the panel window so it sits above windows added after it. */
    private fun raisePanel() {
        val p = panel ?: return
        val lp = panelLp ?: return
        runCatching { wm.removeView(p) }
        runCatching { wm.addView(p, lp) }
    }

    // ── Gestures ───────────────────────────────────────────────────────────

    /** A one-finger stroke through [points] (x,y pairs), scaled, lasting [durationMs]. */
    private fun strokeFor(points: FloatArray, durationMs: Long, sx: Float, sy: Float): GestureDescription.StrokeDescription {
        val path = Path().apply {
            moveTo(points[0] * sx, points[1] * sy)
            var i = 2
            while (i + 1 < points.size) {
                lineTo(points[i] * sx, points[i + 1] * sy)
                i += 2
            }
        }
        val max = GestureDescription.getMaxGestureDuration()
        return GestureDescription.StrokeDescription(path, 0L, durationMs.coerceIn(1L, max))
    }

    /** Dispatches [stroke]; [done] gets whether it completed. A refused dispatch stops everything. */
    private fun dispatch(stroke: GestureDescription.StrokeDescription, done: (Boolean) -> Unit) {
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        val accepted = dispatchGesture(gesture, object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) = done(true)
            override fun onCancelled(gestureDescription: GestureDescription?) = done(false)
        }, handler)
        if (!accepted) {
            Log.w(TAG, "dispatchGesture refused")
            if (isRecording) {
                passingThrough = false
                setCaptureTouchable(true)
            }
            stopClicking("Android refused the touch. Turn the accessibility service off and on, then try again.")
        }
    }

    /** The ring is only shown (and only grabs touches) in modes that use it. */
    private fun updateTargetVisibility() {
        val t = target ?: return
        val visible = !isRecording && mode != MODE_PLAY
        t.visibility = if (visible) View.VISIBLE else View.GONE
        setTargetTouchable(visible && !isRunning)
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
        val toggle = if (isRunning || isRecording) {
            NotificationCompat.Action(
                android.R.drawable.ic_media_pause, if (isRecording) "Stop recording" else "Stop",
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
            .setContentText(notificationText())
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

    private fun notificationText(): String = when {
        isRecording -> "Recording your touches\u2026 Stop from the bubble or here."
        isRunning && mode == MODE_PLAY -> "Replaying ${playing?.name ?: "recording"}\u2026"
        isRunning && mode == MODE_SCROLL -> "Scrolling\u2026"
        isRunning -> "Clicking\u2026"
        mode == MODE_PLAY -> "Ready to replay ${RecordingStore.get(this, recordingId)?.name ?: "a recording"}."
        mode == MODE_SCROLL -> "Ready. Place the ring where to swipe, then tap Start."
        else -> "Ready. Place the ring, then tap Start."
    }

    private fun actionIntent(action: String, requestCode: Int): PendingIntent = PendingIntent.getBroadcast(
        this, requestCode,
        Intent(this, AutoClickActionReceiver::class.java).setAction(action),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}
