package com.example.utility

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (ClickAccessibilityService.ACTION_STOP_AUTOCLICK == action) {
            val stopIntent = Intent(context, ClickAccessibilityService::class.java).apply {
                this.action = ClickAccessibilityService.ACTION_STOP_AUTOCLICK
            }
            context.sendBroadcast(stopIntent)
        }
    }
}
