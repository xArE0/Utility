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
                val aqi = widgetData.getString("widget_aqi", "Air Quality: --")
                
                // Button 5m
                val is5Tick = widgetData.getBoolean("btn_5m_tick", false)
                setViewVisibility(R.id.btn_5m_text, if (is5Tick) android.view.View.GONE else android.view.View.VISIBLE)
                setViewVisibility(R.id.btn_5m_icon, if (is5Tick) android.view.View.VISIBLE else android.view.View.GONE)

                // Button 15m
                val is15Tick = widgetData.getBoolean("btn_15m_tick", false)
                setViewVisibility(R.id.btn_15m_text, if (is15Tick) android.view.View.GONE else android.view.View.VISIBLE)
                setViewVisibility(R.id.btn_15m_icon, if (is15Tick) android.view.View.VISIBLE else android.view.View.GONE)

                // Button 30m
                val is30Tick = widgetData.getBoolean("btn_30m_tick", false)
                setViewVisibility(R.id.btn_30m_text, if (is30Tick) android.view.View.GONE else android.view.View.VISIBLE)
                setViewVisibility(R.id.btn_30m_icon, if (is30Tick) android.view.View.VISIBLE else android.view.View.GONE)

                setTextViewText(R.id.widget_aqi, aqi)
                
                // Timer Buttons Intents (target the roots to ensure clicks are caught, use unique request codes to prevent intent merging)
                val intent5m = android.content.Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java).apply {
                    data = android.net.Uri.parse("utility://timer?mins=5")
                    action = "es.antonborri.home_widget.action.BACKGROUND"
                }
                val pending5m = android.app.PendingIntent.getBroadcast(
                    context, 5, intent5m, 
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )

                val intent15m = android.content.Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java).apply {
                    data = android.net.Uri.parse("utility://timer?mins=15")
                    action = "es.antonborri.home_widget.action.BACKGROUND"
                }
                val pending15m = android.app.PendingIntent.getBroadcast(
                    context, 15, intent15m, 
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )

                val intent30m = android.content.Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java).apply {
                    data = android.net.Uri.parse("utility://timer?mins=30")
                    action = "es.antonborri.home_widget.action.BACKGROUND"
                }
                val pending30m = android.app.PendingIntent.getBroadcast(
                    context, 30, intent30m, 
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )

                setOnClickPendingIntent(R.id.btn_5m_root, pending5m)
                setOnClickPendingIntent(R.id.btn_15m_root, pending15m)
                setOnClickPendingIntent(R.id.btn_30m_root, pending30m)

                // Launch App when clicking the widget root or app icon
                val launchIntent = android.content.Intent(context, MainActivity::class.java).apply {
                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                }
                val launchPendingIntent = android.app.PendingIntent.getActivity(
                    context, 0, launchIntent, 
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, launchPendingIntent)
                setOnClickPendingIntent(R.id.btn_launch_app, launchPendingIntent)
                setOnClickPendingIntent(R.id.widget_aqi, launchPendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
