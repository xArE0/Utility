package com.example.utility

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ScheduleWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.utility_widget).apply {
                val aqi = widgetData.getString("widget_aqi", "AQI: --")

                // Read configurable timer durations (defaults: 5, 15, 30)
                val timer1 = widgetData.getInt("widget_timer1", 5)
                val timer2 = widgetData.getInt("widget_timer2", 15)
                val timer3 = widgetData.getInt("widget_timer3", 30)

                // Set button labels dynamically
                setTextViewText(R.id.btn_timer1_text, "${timer1}m")
                setTextViewText(R.id.btn_timer2_text, "${timer2}m")
                setTextViewText(R.id.btn_timer3_text, "${timer3}m")

                // Button 1 tick state
                val is1Tick = widgetData.getBoolean("btn_timer1_tick", false)
                setViewVisibility(R.id.btn_timer1_text, if (is1Tick) android.view.View.INVISIBLE else android.view.View.VISIBLE)
                setViewVisibility(R.id.btn_timer1_icon, if (is1Tick) android.view.View.VISIBLE else android.view.View.INVISIBLE)

                // Button 2 tick state
                val is2Tick = widgetData.getBoolean("btn_timer2_tick", false)
                setViewVisibility(R.id.btn_timer2_text, if (is2Tick) android.view.View.INVISIBLE else android.view.View.VISIBLE)
                setViewVisibility(R.id.btn_timer2_icon, if (is2Tick) android.view.View.VISIBLE else android.view.View.INVISIBLE)

                // Button 3 tick state
                val is3Tick = widgetData.getBoolean("btn_timer3_tick", false)
                setViewVisibility(R.id.btn_timer3_text, if (is3Tick) android.view.View.INVISIBLE else android.view.View.VISIBLE)
                setViewVisibility(R.id.btn_timer3_icon, if (is3Tick) android.view.View.VISIBLE else android.view.View.INVISIBLE)

                setTextViewText(R.id.widget_aqi, aqi)
                
                // Timer Buttons Intents — use dynamic minute values in URIs
                val intent1 = android.content.Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java).apply {
                    data = android.net.Uri.parse("utility://timer?mins=$timer1&slot=1")
                    action = "es.antonborri.home_widget.action.BACKGROUND"
                }
                val pending1 = android.app.PendingIntent.getBroadcast(
                    context, 1001, intent1, 
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )

                val intent2 = android.content.Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java).apply {
                    data = android.net.Uri.parse("utility://timer?mins=$timer2&slot=2")
                    action = "es.antonborri.home_widget.action.BACKGROUND"
                }
                val pending2 = android.app.PendingIntent.getBroadcast(
                    context, 1002, intent2, 
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )

                val intent3 = android.content.Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java).apply {
                    data = android.net.Uri.parse("utility://timer?mins=$timer3&slot=3")
                    action = "es.antonborri.home_widget.action.BACKGROUND"
                }
                val pending3 = android.app.PendingIntent.getBroadcast(
                    context, 1003, intent3, 
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )

                setOnClickPendingIntent(R.id.btn_timer1_root, pending1)
                setOnClickPendingIntent(R.id.btn_timer2_root, pending2)
                setOnClickPendingIntent(R.id.btn_timer3_root, pending3)

                // Launch App when clicking the app icon
                val launchIntent = android.content.Intent(context, MainActivity::class.java).apply {
                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                }
                val launchPendingIntent = android.app.PendingIntent.getActivity(
                    context, 0, launchIntent, 
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.btn_launch_app, launchPendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
