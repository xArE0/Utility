package com.example.utility

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.MotionEvent
import android.view.View
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import kotlin.math.hypot

/**
 * One recorded touch: start [delayMs] after the previous step started (the first step: after
 * recording began), then trace [points] (x0,y0,x1,y1,… in screen pixels) over [durationMs].
 * A tap is a single point; a swipe or drag is a path; a long press is one point held longer.
 */
class RecordedStep(val delayMs: Long, val durationMs: Long, val points: FloatArray)

/** A saved sequence of touches. [width]×[height] is the screen it was recorded on, for scaling. */
class Recording(
    val id: String,
    val name: String,
    val createdAt: Long,
    val width: Int,
    val height: Int,
    val steps: List<RecordedStep>,
) {
    /** From the first step's start to the end of the last step. */
    val lengthMs: Long
        get() = steps.drop(1).sumOf { it.delayMs } + (steps.lastOrNull()?.durationMs ?: 0L)

    fun summary(): Map<String, Any> = mapOf(
        "id" to id,
        "name" to name,
        "createdAt" to createdAt,
        "steps" to steps.size,
        "lengthMs" to lengthMs,
    )

    fun withName(newName: String) = Recording(id, newName, createdAt, width, height, steps)

    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("name", name)
        .put("created", createdAt)
        .put("w", width)
        .put("h", height)
        .put("steps", JSONArray().apply {
            for (s in steps) {
                put(JSONObject()
                    .put("d", s.delayMs)
                    .put("t", s.durationMs)
                    .put("p", JSONArray().apply { s.points.forEach { put(it.toDouble()) } }))
            }
        })

    companion object {
        fun fromJson(o: JSONObject): Recording {
            val steps = o.getJSONArray("steps")
            return Recording(
                id = o.getString("id"),
                name = o.optString("name", "Recording"),
                createdAt = o.optLong("created"),
                width = o.optInt("w"),
                height = o.optInt("h"),
                steps = List(steps.length()) { i ->
                    val s = steps.getJSONObject(i)
                    val p = s.getJSONArray("p")
                    RecordedStep(
                        delayMs = s.getLong("d"),
                        durationMs = s.getLong("t"),
                        points = FloatArray(p.length()) { p.getDouble(it).toFloat() },
                    )
                },
            )
        }
    }
}

/** Recordings live in a private SharedPreferences file as one JSON array. */
object RecordingStore {
    private const val PREFS = "autoclicker_recordings"
    private const val KEY = "list"

    fun all(context: Context): List<Recording> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            List(arr.length()) { Recording.fromJson(arr.getJSONObject(it)) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun get(context: Context, id: String?): Recording? = id?.let { all(context).firstOrNull { r -> r.id == it } }

    fun add(context: Context, steps: List<RecordedStep>, width: Int, height: Int): Recording {
        val list = all(context)
        val used = list.map { it.name }.toSet()
        var n = list.size + 1
        while ("Recording $n" in used) n++
        val rec = Recording(UUID.randomUUID().toString(), "Recording $n", System.currentTimeMillis(), width, height, steps)
        write(context, list + rec)
        return rec
    }

    fun rename(context: Context, id: String, name: String) =
        write(context, all(context).map { if (it.id == id) it.withName(name.ifBlank { it.name }) else it })

    fun delete(context: Context, id: String) = write(context, all(context).filter { it.id != id })

    private fun write(context: Context, list: List<Recording>) {
        val arr = JSONArray().apply { list.forEach { put(it.toJson()) } }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
    }
}

/**
 * Full-screen, see-through layer shown while recording. It catches each one-finger touch (down to
 * up), hands it to [onStroke] as screen-pixel points, and draws a thin red frame so it is obvious
 * that recording is on. The service then replays the touch to the app underneath.
 */
@SuppressLint("ViewConstructor")
class CaptureView(
    context: Context,
    private val onStroke: (downAt: Long, upAt: Long, points: FloatArray) -> Unit,
) : View(context) {
    private val d = resources.displayMetrics.density
    private val frame = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3f * d
        color = Color.argb(200, 210, 98, 90)
    }
    private val points = ArrayList<Float>()
    private var downAt = 0L
    private var tracking = false

    init {
        contentDescription = "Recording touches"
    }

    override fun onDraw(canvas: Canvas) {
        val h = frame.strokeWidth / 2
        canvas.drawRect(h, h, width - h, height - h, frame)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(e: MotionEvent): Boolean {
        // Screen position of this view, so historical (view-relative) points can be converted too.
        val offX = e.rawX - e.x
        val offY = e.rawY - e.y
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                points.clear()
                downAt = e.eventTime
                tracking = true
                add(e.rawX, e.rawY, force = true)
            }
            MotionEvent.ACTION_MOVE -> if (tracking) {
                val i = e.findPointerIndex(e.getPointerId(0))
                for (h in 0 until e.historySize) add(e.getHistoricalX(i, h) + offX, e.getHistoricalY(i, h) + offY)
                add(e.getX(i) + offX, e.getY(i) + offY)
            }
            // A second finger: this tool replays one finger only, so the stroke is dropped.
            MotionEvent.ACTION_POINTER_DOWN -> tracking = false
            MotionEvent.ACTION_UP -> if (tracking) {
                add(e.rawX, e.rawY)
                tracking = false
                onStroke(downAt, e.eventTime, points.toFloatArray())
            }
            MotionEvent.ACTION_CANCEL -> tracking = false
        }
        return true
    }

    /** Points closer than ~3 px to the previous one add nothing but size. */
    private fun add(x: Float, y: Float, force: Boolean = false) {
        val n = points.size
        if (!force && n >= 2 && hypot(x - points[n - 2], y - points[n - 1]) < 3f) return
        points.add(x)
        points.add(y)
    }
}
