package com.example.utility

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class UtilityWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.utility_widget).apply {
                val date = widgetData.getString("widget_date", "No Data")
                val aqi = widgetData.getString("widget_aqi", "AQI: --")
                val tasks = widgetData.getString("widget_tasks", "No tasks scheduled.")
                val quote = widgetData.getString("widget_quote", "")
                
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

                setTextViewText(R.id.widget_date, date)
                setTextViewText(R.id.widget_aqi, aqi)
                setTextViewText(R.id.widget_tasks, tasks)
                setTextViewText(R.id.widget_quote, quote)
                
                // Timer Buttons Intents (target the roots to ensure clicks are caught)
                val intent5m = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(context, android.net.Uri.parse("utility://timer?mins=5"))
                val intent15m = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(context, android.net.Uri.parse("utility://timer?mins=15"))
                val intent30m = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(context, android.net.Uri.parse("utility://timer?mins=30"))

                setOnClickPendingIntent(R.id.btn_5m_root, intent5m)
                setOnClickPendingIntent(R.id.btn_15m_root, intent15m)
                setOnClickPendingIntent(R.id.btn_30m_root, intent30m)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
