package com.example.utility

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

/**
 * Kept under its original name: renaming the provider would remove the widget from home screens.
 * Everything else lives in [UtilityWidget].
 */
class ScheduleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetManager.updateAppWidget(appWidgetIds, UtilityWidget.buildViews(context))
    }
}
