package com.example.utility

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.min

private val COLOR_IDLE = Color.parseColor("#3B82F6")
private val COLOR_RUNNING = Color.parseColor("#10B981")
private val COLOR_STOP = Color.parseColor("#EF4444")
private val COLOR_MUTED = Color.parseColor("#94A3B8")

private fun ringColor(running: Boolean) = if (running) COLOR_RUNNING else COLOR_IDLE

/**
 * Small translucent ring marking where taps land; its centre is the tap point. The view is larger
 * than the ring so it's easy to grab, and it fades further while clicking so it stays out of the way.
 */
class TargetView(context: Context) : View(context) {
    var running: Boolean = false
        set(value) {
            field = value
            alpha = if (value) RUNNING_ALPHA else IDLE_ALPHA
            invalidate()
        }

    private val d = resources.displayMetrics.density
    private val halo = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3.5f * d
        color = Color.argb(110, 255, 255, 255)
    }
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1.6f * d
    }
    private val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }

    init {
        contentDescription = "Auto clicker target"
        alpha = IDLE_ALPHA
    }

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        val color = ringColor(running)
        ring.color = color
        dot.color = color
        // The faint white halo keeps a thin ring readable on both dark and light screens.
        canvas.drawCircle(cx, cy, RING_RADIUS_DP * d, halo)
        canvas.drawCircle(cx, cy, RING_RADIUS_DP * d, ring)
        canvas.drawCircle(cx, cy, 1.6f * d, dot)
    }

    private companion object {
        const val RING_RADIUS_DP = 11f
        const val IDLE_ALPHA = 0.8f
        const val RUNNING_ALPHA = 0.5f
    }
}

/** The collapsed control: a small disc with a mini target ring. Tap to expand, drag to move. */
class BubbleView(context: Context) : View(context) {
    var running: Boolean = false
        set(value) {
            field = value
            invalidate()
        }

    /** Drawn as a dark disc when collapsed; bare when it sits inside the expanded pill. */
    var showDisc: Boolean = true
        set(value) {
            field = value
            invalidate()
        }

    private val d = resources.displayMetrics.density
    private val disc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.argb(200, 15, 23, 42)
    }
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1.8f * d
    }
    private val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }

    init {
        contentDescription = "Auto clicker controls"
    }

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        val color = ringColor(running)
        ring.color = color
        dot.color = color
        if (showDisc) canvas.drawCircle(cx, cy, 15f * d, disc)
        canvas.drawCircle(cx, cy, 6.5f * d, ring)
        canvas.drawCircle(cx, cy, 1.8f * d, dot)
    }
}

enum class Glyph { PLAY, STOP, CLOSE }

/** Small icon button drawn with paths, so it looks the same on every device and font. */
class GlyphView(context: Context, glyph: Glyph, tint: Int) : View(context) {
    var glyph: Glyph = glyph
        set(value) {
            field = value
            invalidate()
        }
    var tint: Int = tint
        set(value) {
            field = value
            invalidate()
        }

    private val d = resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val path = Path()

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        val s = min(width, height) * 0.24f
        paint.color = tint
        when (glyph) {
            Glyph.PLAY -> {
                paint.style = Paint.Style.FILL
                path.reset()
                path.moveTo(cx - s * 0.7f, cy - s)
                path.lineTo(cx + s * 1.1f, cy)
                path.lineTo(cx - s * 0.7f, cy + s)
                path.close()
                canvas.drawPath(path, paint)
            }
            Glyph.STOP -> {
                paint.style = Paint.Style.FILL
                canvas.drawRoundRect(cx - s, cy - s, cx + s, cy + s, s * 0.25f, s * 0.25f, paint)
            }
            Glyph.CLOSE -> {
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = 2f * d
                paint.strokeCap = Paint.Cap.ROUND
                canvas.drawLine(cx - s * 0.8f, cy - s * 0.8f, cx + s * 0.8f, cy + s * 0.8f, paint)
                canvas.drawLine(cx + s * 0.8f, cy - s * 0.8f, cx - s * 0.8f, cy + s * 0.8f, paint)
            }
        }
    }
}

/**
 * Floating controls. Collapsed it is just a small [BubbleView]; tapping the bubble expands it into
 * a pill: [bubble] [start/stop] [tap counter] [close]. The bubble is the drag handle in both states.
 */
class PanelView(context: Context) : LinearLayout(context) {
    private val d = resources.displayMetrics.density

    val handle = BubbleView(context)
    val toggle = GlyphView(context, Glyph.PLAY, COLOR_RUNNING)
    val close = GlyphView(context, Glyph.CLOSE, COLOR_MUTED)
    private val counter = TextView(context)

    var expanded: Boolean = false
        set(value) {
            field = value
            applyExpanded()
        }

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL

        toggle.contentDescription = "Start or stop clicking"
        close.contentDescription = "Close auto clicker"
        counter.apply {
            setTextColor(Color.parseColor("#E2E8F0"))
            textSize = 12f
            gravity = Gravity.CENTER
            minWidth = (28f * d).toInt()
            setSingleLine()
        }

        addView(handle, LayoutParams(dp(40), dp(40)))
        addView(toggle, LayoutParams(dp(40), dp(40)))
        addView(counter, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
        addView(close, LayoutParams(dp(36), dp(40)))
        applyExpanded()
        render(running = false, taps = 0)
    }

    fun render(running: Boolean, taps: Int) {
        handle.running = running
        toggle.glyph = if (running) Glyph.STOP else Glyph.PLAY
        toggle.tint = if (running) COLOR_STOP else COLOR_RUNNING
        counter.text = taps.toString()
    }

    private fun applyExpanded() {
        val vis = if (expanded) VISIBLE else GONE
        toggle.visibility = vis
        counter.visibility = vis
        close.visibility = vis
        handle.showDisc = !expanded
        if (expanded) {
            background = GradientDrawable().apply {
                setColor(Color.argb(224, 15, 23, 42))
                cornerRadius = 22f * d
                setStroke((1f * d).toInt(), Color.parseColor("#334155"))
            }
            setPadding(0, 0, dp(4), 0)
        } else {
            background = null
            setPadding(0, 0, 0, 0)
        }
    }

    private fun dp(value: Int) = (value * d).toInt()
}
