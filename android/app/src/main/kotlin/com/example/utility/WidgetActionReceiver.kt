package com.example.utility

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Widget taps, the timer alarm, and the system events after which the widget must be restored. */
class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            UtilityWidget.ACTION_TIMER_START ->
                UtilityWidget.startTimer(context, intent.getIntExtra(UtilityWidget.EXTRA_SLOT, 1))
            UtilityWidget.ACTION_TIMER_CANCEL -> UtilityWidget.cancelTimerFromWidget(context)
            UtilityWidget.ACTION_TIMER_DONE -> UtilityWidget.finishTimer(context)
            UtilityWidget.ACTION_AWAKE_TOGGLE -> UtilityWidget.toggleAwake(context)
            Intent.ACTION_BOOT_COMPLETED -> UtilityWidget.restore(context, dropExpired = true)
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            -> UtilityWidget.restore(context, dropExpired = false)
        }
    }
}
