package com.example.utility

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fires scheduled volume changes. Also re-arms the alarm after events that wipe or shift it:
 * reboot, app update, and clock/time zone changes.
 */
class VolumeAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        VolumeScheduler.sync(context)
    }

    companion object {
        const val ACTION_FIRE = "com.example.utility.VOLUME_SCHEDULE_FIRE"
    }
}
