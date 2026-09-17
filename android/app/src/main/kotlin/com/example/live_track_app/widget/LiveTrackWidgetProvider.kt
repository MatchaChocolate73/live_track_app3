package com.example.live_track_app.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import com.example.live_track_app.R

/**
 * Widget sederhana yang menampilkan: nama anggota, kecepatan terkini,
 * dan status ("Live sekarang" / "Terakhir terlihat X lalu").
 *
 * Data diisi lewat HomeWidgetService.updateWidgetData() dari sisi Flutter,
 * disimpan lewat SharedPreferences yang dibaca lagi di sini oleh
 * HomeWidgetPlugin.getData(context).
 */
class LiveTrackWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.live_track_widget)

            val memberName = widgetData.getString("member_name", "Belum ada data")
            val speedKmh = widgetData.getFloat("speed_kmh", 0f)
            val statusLabel = widgetData.getString("status_label", "Tidak ada data")

            views.setTextViewText(R.id.widget_member_name, memberName)
            views.setTextViewText(R.id.widget_speed, "${speedKmh.toInt()} km/j")
            views.setTextViewText(R.id.widget_status, statusLabel)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
