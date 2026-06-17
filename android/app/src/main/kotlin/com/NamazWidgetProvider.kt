package com.cahitacar.kiblenamaz

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews


class NamazWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {

        for (appWidgetId in appWidgetIds) {

            val views = RemoteViews(
                context.packageName,
                R.layout.namaz_widget
            )
            val prefs = context.getSharedPreferences(
    "HomeWidgetPreferences",
    Context.MODE_PRIVATE
)

val sehir = prefs.getString(
    "widget_sehir",
    "Eskişehir"
)

val vakit = prefs.getString(
    "widget_vakit",
    "Yatsı"
)

val saat = prefs.getString(
    "widget_saat",
    "--:--"
)

views.setTextViewText(
    R.id.widget_title,
    "📍 $sehir"
)

views.setTextViewText(
    R.id.widget_time,
    "🕌 Sonraki Vakit: $vakit\n$saat"
)

            appWidgetManager.updateAppWidget(
                appWidgetId,
                views
            )
        }
    }
}