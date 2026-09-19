package com.example.utility

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Handles the Start/Stop and Close actions on the Auto Clicker notification. */
class AutoClickActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val service = ClickAccessibilityService.instance ?: return
        when (intent.action) {
            // Longer delay than the panel: the notification shade has to slide away first.
            ACTION_TOGGLE -> service.toggleClicking(NOTIFICATION_START_DELAY_MS)
            ACTION_CLOSE -> service.hideOverlay()
        }
    }

    companion object {
        const val ACTION_TOGGLE = "com.example.utility.autoclicker.TOGGLE"
        const val ACTION_CLOSE = "com.example.utility.autoclicker.CLOSE"
        private const val NOTIFICATION_START_DELAY_MS = 800L
    }
}
