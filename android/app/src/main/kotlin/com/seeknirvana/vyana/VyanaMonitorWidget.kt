package com.seeknirvana.vyana

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * One-tap "Monitor all vitals" action widget. Tapping deep-links into Vyana
 * (`vyanawidget://monitor`), which starts a hands-off run of every vital and
 * notifies when done — the user can set the phone aside.
 */
class VyanaMonitorWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.vyana_monitor_widget).apply {
                val updated = widgetData.getString("updated_label", null)
                setTextViewText(
                    R.id.widget_updated,
                    if (!updated.isNullOrEmpty()) "Last check-in $updated" else "Tap to check in"
                )

                val launch = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("vyanawidget://monitor")
                )
                setOnClickPendingIntent(R.id.widget_root, launch)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
