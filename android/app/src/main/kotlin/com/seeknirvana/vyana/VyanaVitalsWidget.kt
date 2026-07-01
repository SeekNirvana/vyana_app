package com.seeknirvana.vyana

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Live "state of being" home-screen widget: shows the worded state plus a grid
 * of the latest biomarker readings (Heart, Oxygen, HRV, Stress, Glucose, Steps…).
 * Data is pushed from the app after every sync via `HomeWidgetService`. Tapping
 * opens Vyana.
 */
class VyanaVitalsWidget : HomeWidgetProvider() {

    // Cell container + value + label view ids, one triple per biomarker slot.
    private val cells = listOf(
        Triple(R.id.bio0_cell, R.id.bio0_value, R.id.bio0_label),
        Triple(R.id.bio1_cell, R.id.bio1_value, R.id.bio1_label),
        Triple(R.id.bio2_cell, R.id.bio2_value, R.id.bio2_label),
        Triple(R.id.bio3_cell, R.id.bio3_value, R.id.bio3_label),
        Triple(R.id.bio4_cell, R.id.bio4_value, R.id.bio4_label),
        Triple(R.id.bio5_cell, R.id.bio5_value, R.id.bio5_label),
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.vyana_vitals_widget).apply {
                val title = widgetData.getString("state_title", null) ?: "Let's check in"
                val updated = widgetData.getString("updated_label", null) ?: "Tap to check in"
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_updated, updated)

                cells.forEachIndexed { i, (cellId, valueId, labelId) ->
                    val value = widgetData.getString("bio${i}_value", null)
                    val label = widgetData.getString("bio${i}_label", null)
                    if (value.isNullOrEmpty()) {
                        setViewVisibility(cellId, View.INVISIBLE)
                        setTextViewText(valueId, "")
                        setTextViewText(labelId, "")
                    } else {
                        setViewVisibility(cellId, View.VISIBLE)
                        setTextViewText(valueId, value)
                        setTextViewText(labelId, label ?: "")
                    }
                }

                val launch = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("vyanawidget://open")
                )
                setOnClickPendingIntent(R.id.widget_root, launch)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
