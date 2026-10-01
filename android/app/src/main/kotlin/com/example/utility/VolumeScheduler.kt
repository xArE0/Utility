package com.example.utility

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Scheduled volume changes. Rules live here (native SharedPreferences) rather than in Dart because
 * alarms, boot and app updates are handled while the Flutter engine isn't running.
 *
 * Only one alarm is ever registered: the soonest upcoming change across all rules. When it fires,
 * everything that became due is applied and the next one is scheduled. No service, no polling.
 *
 * Rule JSON: {id, label, hour, minute, days: [1..7 (Mon=1, like Dart's DateTime.weekday)],
 * enabled, levels: {stream: percent}, once, armedAt}. Streams missing from levels are left alone.
 * A "once" rule ignores days: it runs at the first hour:minute after armedAt (when it was switched
 * on), then switches itself off.
 */
object VolumeScheduler {
    private const val PREFS = "volume_schedule"
    private const val KEY_RULES = "rules"
    private const val KEY_LAST_APPLIED = "last_applied_ms"
    private const val KEY_LOG = "log"
    private const val LOG_SIZE = 20
    private const val REQUEST_CODE = 7301

    /** Missed changes older than this (phone off, alarm dropped) are not applied late. */
    private const val CATCH_UP_MS = 7L * 24 * 60 * 60 * 1000

    val STREAMS = linkedMapOf(
        "media" to AudioManager.STREAM_MUSIC,
        "ring" to AudioManager.STREAM_RING,
        "notification" to AudioManager.STREAM_NOTIFICATION,
        "alarm" to AudioManager.STREAM_ALARM,
    )

    /** Changing these while on vibrate/silent/DND would flip the ringer mode (or need DND access). */
    private val RINGER_STREAMS = setOf("ring", "notification")

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun getRulesJson(context: Context): String = prefs(context).getString(KEY_RULES, "[]") ?: "[]"

    /** Saving counts as "caught up": edits never fire a rule retroactively. Use Apply now for that. */
    fun saveRules(context: Context, json: String) {
        JSONArray(json) // reject malformed input before storing it
        prefs(context).edit()
            .putString(KEY_RULES, json)
            .putLong(KEY_LAST_APPLIED, System.currentTimeMillis())
            .apply()
        scheduleNext(context)
    }

    /** Applies whatever became due since the last run, then arms the next alarm. */
    fun sync(context: Context) {
        try {
            applyDue(context)
        } finally {
            scheduleNext(context)
        }
    }

    fun applyRuleNow(context: Context, id: String): String? {
        val rule = rules(context).firstOrNull { it.optString("id") == id } ?: return "Rule not found."
        val summary = applyLevels(context, rule)
        log(context, rule, summary, manual = true)
        return null
    }

    fun nextChangeMs(context: Context): Long? =
        rules(context).mapNotNull { nextOccurrence(it, System.currentTimeMillis()) }.minOrNull()

    fun getLogJson(context: Context): String = prefs(context).getString(KEY_LOG, "[]") ?: "[]"

    fun streamInfo(context: Context): Map<String, Map<String, Int>> {
        val audio = context.getSystemService(AudioManager::class.java)
        return STREAMS.mapValues { (_, stream) ->
            mapOf(
                "min" to minVolume(audio, stream),
                "max" to audio.getStreamMaxVolume(stream),
                "current" to audio.getStreamVolume(stream),
            )
        }
    }

    fun ringerMode(context: Context): String =
        when (context.getSystemService(AudioManager::class.java).ringerMode) {
            AudioManager.RINGER_MODE_SILENT -> "silent"
            AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
            else -> "normal"
        }

    // ── Internals ─────────────────────────────────────────────────────────────

    private fun rules(context: Context): List<JSONObject> = try {
        val arr = JSONArray(getRulesJson(context))
        (0 until arr.length()).mapNotNull { arr.optJSONObject(it) }
    } catch (_: Exception) {
        emptyList()
    }

    private fun applyDue(context: Context) {
        val now = System.currentTimeMillis()
        val p = prefs(context)
        val since = maxOf(p.getLong(KEY_LAST_APPLIED, now), now - CATCH_UP_MS)

        // Each rule's latest occurrence in (since, now], oldest first so later changes win.
        val due = rules(context)
            .mapNotNull { rule -> latestOccurrence(rule, now)?.takeIf { it > since }?.let { it to rule } }
            .sortedBy { it.first }

        for ((_, rule) in due) {
            log(context, rule, applyLevels(context, rule), manual = false)
            if (rule.optBoolean("once")) rule.put("enabled", false)
        }

        val edit = p.edit().putLong(KEY_LAST_APPLIED, now)
        if (due.any { it.second.optBoolean("once") }) {
            // The rule objects were updated in place; write them back so one-shots stay off.
            edit.putString(KEY_RULES, JSONArray(rules(context).map { stored ->
                due.firstOrNull { it.second.optString("id") == stored.optString("id") }?.second ?: stored
            }).toString())
        }
        edit.apply()
    }

    /** Returns a per-stream summary like "notification 5/15" or "ring skipped (vibrate)". */
    private fun applyLevels(context: Context, rule: JSONObject): List<String> {
        val audio = context.getSystemService(AudioManager::class.java)
        val levels = rule.optJSONObject("levels") ?: return emptyList()
        val summary = mutableListOf<String>()

        for ((name, stream) in STREAMS) {
            if (!levels.has(name) || levels.isNull(name)) continue
            val percent = levels.optInt(name).coerceIn(0, 100)

            if (name in RINGER_STREAMS && audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) {
                summary += "$name skipped (${ringerMode(context)})"
                continue
            }

            val min = minVolume(audio, stream)
            val max = audio.getStreamMaxVolume(stream)
            var index = Math.round(percent / 100.0 * max).toInt().coerceIn(min, max)
            // 0 on ring/notification would switch the phone to vibrate; keep it audible.
            if (name in RINGER_STREAMS) index = maxOf(index, 1)

            summary += try {
                audio.setStreamVolume(stream, index, 0) // flags 0: no volume panel pops up
                "$name $index/$max"
            } catch (e: SecurityException) {
                "$name failed (${e.message ?: "not allowed"})"
            }
        }
        return summary
    }

    private fun minVolume(audio: AudioManager, stream: Int): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) audio.getStreamMinVolume(stream) else 0

    private fun days(rule: JSONObject): Set<Int> {
        val arr = rule.optJSONArray("days") ?: return emptySet()
        return (0 until arr.length()).map { arr.optInt(it) }.toSet()
    }

    /** Calendar's Sunday=1..Saturday=7 → Mon=1..Sun=7 (the rule format). */
    private fun isoWeekday(cal: Calendar): Int {
        val d = cal.get(Calendar.DAY_OF_WEEK)
        return if (d == Calendar.SUNDAY) 7 else d - 1
    }

    /** Candidate firing times for the 8 days around [fromMs], stepping [direction] (+1/-1) a day at a time. */
    private fun occurrences(rule: JSONObject, fromMs: Long, direction: Int): Sequence<Long> {
        if (!rule.optBoolean("enabled", true)) return emptySequence()
        val days = days(rule)
        if (days.isEmpty()) return emptySequence()
        val hour = rule.optInt("hour")
        val minute = rule.optInt("minute")
        return (0..7).asSequence().mapNotNull { offset ->
            val cal = Calendar.getInstance().apply {
                timeInMillis = fromMs
                add(Calendar.DAY_OF_YEAR, offset * direction)
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (isoWeekday(cal) in days) cal.timeInMillis else null
        }
    }

    /** A one-shot's single firing time: the first hour:minute after it was armed. */
    private fun onceOccurrence(rule: JSONObject): Long? {
        if (!rule.optBoolean("enabled", true)) return null
        val armedAt = rule.optLong("armedAt", 0L).takeIf { it > 0 } ?: return null
        val cal = Calendar.getInstance().apply {
            timeInMillis = armedAt
            set(Calendar.HOUR_OF_DAY, rule.optInt("hour"))
            set(Calendar.MINUTE, rule.optInt("minute"))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (cal.timeInMillis <= armedAt) cal.add(Calendar.DAY_OF_YEAR, 1)
        return cal.timeInMillis
    }

    private fun nextOccurrence(rule: JSONObject, nowMs: Long): Long? =
        if (rule.optBoolean("once")) {
            onceOccurrence(rule)?.takeIf { it > nowMs }
        } else {
            occurrences(rule, nowMs, 1).firstOrNull { it > nowMs }
        }

    private fun latestOccurrence(rule: JSONObject, nowMs: Long): Long? =
        if (rule.optBoolean("once")) {
            onceOccurrence(rule)?.takeIf { it <= nowMs }
        } else {
            occurrences(rule, nowMs, -1).firstOrNull { it <= nowMs }
        }

    private fun scheduleNext(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, VolumeAlarmReceiver::class.java).setAction(VolumeAlarmReceiver.ACTION_FIRE)
        val pending = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val next = nextChangeMs(context)
        if (next == null) {
            alarms.cancel(pending)
            return
        }
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
        if (exact) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending)
        } else {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending)
        }
    }

    private fun log(context: Context, rule: JSONObject, summary: List<String>, manual: Boolean) {
        val p = prefs(context)
        val old = try {
            JSONArray(p.getString(KEY_LOG, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        val entry = JSONObject()
            .put("at", System.currentTimeMillis())
            .put("label", rule.optString("label"))
            .put("manual", manual)
            .put("result", JSONArray(summary))
        val next = JSONArray().put(entry)
        for (i in 0 until minOf(old.length(), LOG_SIZE - 1)) next.put(old.get(i))
        p.edit().putString(KEY_LOG, next.toString()).apply()
    }
}
