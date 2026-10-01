package com.example.utility

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.view.View
import android.widget.RemoteViews

/**
 * The home screen widget: state, rendering and every action it can take.
 *
 * Taps are handled natively by [WidgetActionReceiver] — no Flutter engine is started, so they are
 * instant and can't be lost halfway. All widget state lives in one SharedPreferences file here; the
 * app reads and changes it over the "com.example.utility/widget" channel and gets a "changed" push
 * through [listener] whenever anything moves.
 *
 * Timer: one at a time. Its end is a single exact alarm; the countdown on the widget is a
 * Chronometer, which the launcher ticks by itself, so nothing runs while it counts down.
 *
 * Stay awake: switches the screen-off timeout to the configured duration and remembers the old
 * value; switching off restores it, unless the user changed the timeout by hand in the meantime.
 */
object UtilityWidget {
    private const val PREFS = "utility_widget"
    private const val KEY_AQI = "aqi"
    private const val KEY_TIMER1 = "timer1"
    private const val KEY_TIMER2 = "timer2"
    private const val KEY_AWAKE_MINUTES = "awake_minutes"
    private const val KEY_TIMER_END = "timer_end_ms"
    private const val KEY_TIMER_MINUTES = "timer_minutes"
    private const val KEY_TIMER_STARTED = "timer_started_ms"
    private const val KEY_AWAKE_ON = "awake_on"
    private const val KEY_AWAKE_PREVIOUS = "awake_previous_ms"
    private const val KEY_AWAKE_SET = "awake_set_ms"

    const val ACTION_TIMER_START = "com.example.utility.widget.TIMER_START"
    const val ACTION_TIMER_CANCEL = "com.example.utility.widget.TIMER_CANCEL"
    const val ACTION_TIMER_DONE = "com.example.utility.widget.TIMER_DONE"
    const val ACTION_AWAKE_TOGGLE = "com.example.utility.widget.AWAKE_TOGGLE"
    const val EXTRA_SLOT = "slot"

    // Distinct request codes: PendingIntents that only differ in extras would otherwise merge.
    private const val REQ_TIMER_ALARM = 7401
    private const val REQ_TIMER1 = 7411
    private const val REQ_TIMER2 = 7412
    private const val REQ_CANCEL = 7413
    private const val REQ_AWAKE = 7414
    private const val REQ_LAUNCH = 7415
    private const val REQ_WRITE_SETTINGS = 7416
    private const val REQ_NOTIFICATION = 7417

    /** Same channel the Flutter-side timers used, so any sound/vibration the user chose is kept. */
    private const val CHANNEL_ID = "quick_timers"
    private const val NOTIFICATION_ID = 7402

    private const val DEFAULT_TIMER1 = 5
    private const val DEFAULT_TIMER2 = 15
    private const val DEFAULT_AWAKE_MINUTES = 10

    /**
     * The ✕ sits where the second timer button was; a quick double-tap on that button would
     * otherwise start the timer and cancel it straight away.
     */
    private const val CANCEL_GUARD_MS = 1500L

    /** Set by MainActivity while the Flutter UI is alive; always invoked on the main thread. */
    var listener: (() -> Unit)? = null

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ── Called from the app ───────────────────────────────────────────────────

    fun state(context: Context): Map<String, Any?> {
        val p = prefs(context)
        val end = p.getLong(KEY_TIMER_END, 0L)
        return mapOf(
            "timer1" to p.getInt(KEY_TIMER1, DEFAULT_TIMER1),
            "timer2" to p.getInt(KEY_TIMER2, DEFAULT_TIMER2),
            "awakeMinutes" to p.getInt(KEY_AWAKE_MINUTES, DEFAULT_AWAKE_MINUTES),
            "awakeOn" to p.getBoolean(KEY_AWAKE_ON, false),
            "canWriteSettings" to Settings.System.canWrite(context),
            "timerEndMs" to end.takeIf { it > System.currentTimeMillis() },
            "timerMinutes" to p.getInt(KEY_TIMER_MINUTES, 0),
        )
    }

    fun configure(context: Context, timer1: Int, timer2: Int, awakeMinutes: Int) {
        val p = prefs(context)
        p.edit()
            .putInt(KEY_TIMER1, timer1.coerceIn(1, 999))
            .putInt(KEY_TIMER2, timer2.coerceIn(1, 999))
            .putInt(KEY_AWAKE_MINUTES, awakeMinutes.coerceIn(1, 999))
            .apply()

        // A new duration while stay-awake is on takes effect right away.
        if (p.getBoolean(KEY_AWAKE_ON, false) && Settings.System.canWrite(context)) {
            val target = awakeMinutes.coerceIn(1, 999) * 60_000
            val resolver = context.contentResolver
            try {
                if (Settings.System.getInt(resolver, Settings.System.SCREEN_OFF_TIMEOUT, -1) == p.getInt(KEY_AWAKE_SET, -2)) {
                    Settings.System.putInt(resolver, Settings.System.SCREEN_OFF_TIMEOUT, target)
                    p.edit().putInt(KEY_AWAKE_SET, target).apply()
                }
            } catch (_: SecurityException) {
            }
        }
        changed(context)
    }

    fun setAqi(context: Context, text: String) {
        if (prefs(context).getString(KEY_AQI, null) == text) return
        prefs(context).edit().putString(KEY_AQI, text).apply()
        render(context)
    }

    // ── Timer ─────────────────────────────────────────────────────────────────

    fun startTimer(context: Context, slot: Int) {
        val p = prefs(context)
        // A second tap that raced the redraw lands here; one timer at a time.
        if (p.getLong(KEY_TIMER_END, 0L) > System.currentTimeMillis()) return
        val minutes = if (slot == 2) p.getInt(KEY_TIMER2, DEFAULT_TIMER2) else p.getInt(KEY_TIMER1, DEFAULT_TIMER1)
        val end = System.currentTimeMillis() + minutes * 60_000L
        p.edit()
            .putLong(KEY_TIMER_END, end)
            .putInt(KEY_TIMER_MINUTES, minutes)
            .putLong(KEY_TIMER_STARTED, System.currentTimeMillis())
            .apply()
        scheduleAlarm(context, end)
        changed(context)
    }

    /** The widget's ✕; ignores taps that are really the tail of a double-tap on a timer button. */
    fun cancelTimerFromWidget(context: Context) {
        val started = prefs(context).getLong(KEY_TIMER_STARTED, 0L)
        if (System.currentTimeMillis() - started < CANCEL_GUARD_MS) return
        cancelTimer(context)
    }

    fun cancelTimer(context: Context) {
        context.getSystemService(AlarmManager::class.java).cancel(alarmIntent(context))
        prefs(context).edit().remove(KEY_TIMER_END).remove(KEY_TIMER_MINUTES).apply()
        changed(context)
    }

    fun finishTimer(context: Context) {
        val p = prefs(context)
        if (p.getLong(KEY_TIMER_END, 0L) == 0L) return // cancelled after the alarm was already in flight
        val minutes = p.getInt(KEY_TIMER_MINUTES, 0)
        p.edit().remove(KEY_TIMER_END).remove(KEY_TIMER_MINUTES).apply()
        notifyFinished(context, minutes)
        changed(context)
    }

    /**
     * After reboot, app update, a clock change or app start (a force-stop clears alarms): re-arm
     * the alarm and redraw (the countdown's base is uptime-relative and the launcher may still hold
     * views from the previous app version). With [dropExpired], a timer that ran out unnoticed
     * (phone off, app force-stopped) is dropped rather than announced late.
     */
    fun restore(context: Context, dropExpired: Boolean) {
        val p = prefs(context)
        val end = p.getLong(KEY_TIMER_END, 0L)
        if (end > 0L) {
            if (dropExpired && end <= System.currentTimeMillis()) {
                p.edit().remove(KEY_TIMER_END).remove(KEY_TIMER_MINUTES).apply()
            } else {
                scheduleAlarm(context, end) // already past: fires immediately and finishes normally
            }
        }
        changed(context)
    }

    private fun alarmIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        REQ_TIMER_ALARM,
        Intent(context, WidgetActionReceiver::class.java).setAction(ACTION_TIMER_DONE),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun scheduleAlarm(context: Context, atMs: Long) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
        if (exact) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, alarmIntent(context))
        } else {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, alarmIntent(context))
        }
    }

    private fun notifyFinished(context: Context, minutes: Int) {
        val nm = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // No-op when the channel already exists, so the user's settings for it survive.
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Quick Timers", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Notifications for quick visual timers"
                },
            )
        }
        val open = PendingIntent.getActivity(
            context,
            REQ_NOTIFICATION,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
                .setPriority(Notification.PRIORITY_MAX)
                .setDefaults(Notification.DEFAULT_ALL)
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("⏱️ Time is Up!")
            .setContentText("Your $minutes minute timer finished.")
            .setCategory(Notification.CATEGORY_ALARM)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try {
            nm.notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Notifications not allowed; the widget still resets.
        }
    }

    // ── Stay awake ────────────────────────────────────────────────────────────

    /** Returns false (and changes nothing) without the "Modify system settings" permission. */
    fun toggleAwake(context: Context): Boolean {
        if (!Settings.System.canWrite(context)) {
            changed(context) // swaps the button over to opening the permission screen
            return false
        }
        val p = prefs(context)
        val resolver = context.contentResolver
        try {
            if (!p.getBoolean(KEY_AWAKE_ON, false)) {
                val previous = Settings.System.getInt(resolver, Settings.System.SCREEN_OFF_TIMEOUT, 60_000)
                val target = p.getInt(KEY_AWAKE_MINUTES, DEFAULT_AWAKE_MINUTES) * 60_000
                Settings.System.putInt(resolver, Settings.System.SCREEN_OFF_TIMEOUT, target)
                p.edit()
                    .putBoolean(KEY_AWAKE_ON, true)
                    .putInt(KEY_AWAKE_PREVIOUS, previous)
                    .putInt(KEY_AWAKE_SET, target)
                    .apply()
            } else {
                val current = Settings.System.getInt(resolver, Settings.System.SCREEN_OFF_TIMEOUT, -1)
                // Changed by hand while on: the user's newer choice wins.
                if (current == p.getInt(KEY_AWAKE_SET, -2)) {
                    Settings.System.putInt(
                        resolver,
                        Settings.System.SCREEN_OFF_TIMEOUT,
                        p.getInt(KEY_AWAKE_PREVIOUS, 60_000),
                    )
                }
                p.edit().putBoolean(KEY_AWAKE_ON, false).remove(KEY_AWAKE_PREVIOUS).remove(KEY_AWAKE_SET).apply()
            }
        } catch (_: SecurityException) {
            changed(context)
            return false
        }
        changed(context)
        return true
    }

    // ── Rendering ─────────────────────────────────────────────────────────────

    private fun changed(context: Context) {
        render(context)
        listener?.invoke()
    }

    fun render(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, ScheduleWidgetProvider::class.java))
        if (ids.isNotEmpty()) manager.updateAppWidget(ids, buildViews(context))
    }

    fun buildViews(context: Context): RemoteViews {
        val p = prefs(context)
        val views = RemoteViews(context.packageName, R.layout.utility_widget)

        views.setTextViewText(R.id.widget_aqi, p.getString(KEY_AQI, null) ?: "Air Quality: --")
        views.setOnClickPendingIntent(
            R.id.btn_launch_app,
            PendingIntent.getActivity(
                context,
                REQ_LAUNCH,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            ),
        )

        // Timer: two buttons, or one countdown spanning both slots.
        val now = System.currentTimeMillis()
        val end = p.getLong(KEY_TIMER_END, 0L)
        val running = end > now
        views.setViewVisibility(R.id.timer_buttons, if (running) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.timer_running, if (running) View.VISIBLE else View.GONE)
        if (running) {
            views.setChronometer(R.id.timer_countdown, SystemClock.elapsedRealtime() + (end - now), null, true)
            views.setChronometerCountDown(R.id.timer_countdown, true)
        } else {
            views.setChronometer(R.id.timer_countdown, SystemClock.elapsedRealtime(), null, false)
        }
        views.setTextViewText(R.id.btn_timer1_text, "${p.getInt(KEY_TIMER1, DEFAULT_TIMER1)}m")
        views.setTextViewText(R.id.btn_timer2_text, "${p.getInt(KEY_TIMER2, DEFAULT_TIMER2)}m")
        views.setOnClickPendingIntent(R.id.btn_timer1_root, broadcast(context, REQ_TIMER1, ACTION_TIMER_START, 1))
        views.setOnClickPendingIntent(R.id.btn_timer2_root, broadcast(context, REQ_TIMER2, ACTION_TIMER_START, 2))
        views.setOnClickPendingIntent(R.id.btn_timer_cancel, broadcast(context, REQ_CANCEL, ACTION_TIMER_CANCEL))

        // Stay awake. Without the permission the button opens its settings screen instead; an
        // activity can't be started from the receiver, so that choice is made here.
        val awakeOn = p.getBoolean(KEY_AWAKE_ON, false)
        views.setImageViewResource(R.id.btn_awake_icon, if (awakeOn) R.drawable.ic_awake_on else R.drawable.ic_awake_off)
        views.setInt(R.id.btn_awake_icon, "setBackgroundResource", if (awakeOn) R.drawable.widget_awake_on_bg else 0)
        views.setOnClickPendingIntent(
            R.id.btn_awake_root,
            if (Settings.System.canWrite(context)) {
                broadcast(context, REQ_AWAKE, ACTION_AWAKE_TOGGLE)
            } else {
                PendingIntent.getActivity(
                    context,
                    REQ_WRITE_SETTINGS,
                    Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, Uri.parse("package:${context.packageName}"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
            },
        )
        return views
    }

    private fun broadcast(context: Context, requestCode: Int, action: String, slot: Int = 0): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            requestCode,
            Intent(context, WidgetActionReceiver::class.java).setAction(action).putExtra(EXTRA_SLOT, slot),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
}
