package dev.sidekick.sidekick

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.text.format.DateUtils
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Sidekick's home-screen widgets (4.0): [SmallWidget] shows the last file
 * received (or "Ready to receive"), [DevicesWidget] up to three paired
 * devices with Send and Ping. The app writes what they show (Dart
 * platform/home_widgets.dart → `updateWidgets` on `sidekick/background`);
 * taps open Sidekick with a `sidekick://` link it picks up ([WidgetLinks]).
 */
object SidekickWidgets {
    private const val PREFS = "sidekick_widgets"

    fun save(context: Context, json: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("data", json).apply()
        updateAll(context)
    }

    private fun data(context: Context): JSONObject = try {
        JSONObject(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("data", null) ?: "{}")
    } catch (e: Exception) {
        JSONObject()
    }

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val smallIds = manager.getAppWidgetIds(ComponentName(context, SmallWidget::class.java))
        if (smallIds.isNotEmpty()) manager.updateAppWidget(smallIds, small(context))
        val deviceIds = manager.getAppWidgetIds(ComponentName(context, DevicesWidget::class.java))
        if (deviceIds.isNotEmpty()) manager.updateAppWidget(deviceIds, devices(context))
    }

    private fun open(context: Context, link: String, code: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(link), context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context, code, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    fun small(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_small)
        val last = data(context).optJSONObject("last")
        if (last == null) {
            views.setViewVisibility(R.id.widget_last, View.GONE)
            views.setViewVisibility(R.id.widget_ready, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_last, View.VISIBLE)
            views.setViewVisibility(R.id.widget_ready, View.GONE)
            views.setTextViewText(R.id.widget_last_name, last.optString("name", "A file"))
            val ago = DateUtils.getRelativeTimeSpanString(
                last.optLong("at", System.currentTimeMillis()), System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS,
            )
            val from = last.optString("from", "")
            views.setTextViewText(R.id.widget_last_from, if (from.isEmpty()) ago else "From $from · $ago")
        }
        views.setOnClickPendingIntent(R.id.widget_root, open(context, "sidekick://open", 1))
        return views
    }

    fun devices(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_devices)
        val list = data(context).optJSONArray("devices")
        val rows = listOf(
            listOf(R.id.widget_row1, R.id.widget_name1, R.id.widget_status1, R.id.widget_send1, R.id.widget_ping1),
            listOf(R.id.widget_row2, R.id.widget_name2, R.id.widget_status2, R.id.widget_send2, R.id.widget_ping2),
            listOf(R.id.widget_row3, R.id.widget_name3, R.id.widget_status3, R.id.widget_send3, R.id.widget_ping3),
        )
        val count = list?.length() ?: 0
        views.setViewVisibility(R.id.widget_empty, if (count == 0) View.VISIBLE else View.GONE)
        for ((i, row) in rows.withIndex()) {
            val device = if (i < count) list?.optJSONObject(i) else null
            if (device == null) {
                views.setViewVisibility(row[0], View.GONE)
                continue
            }
            views.setViewVisibility(row[0], View.VISIBLE)
            val id = Uri.encode(device.optString("id"))
            val online = device.optBoolean("online")
            views.setTextViewText(row[1], device.optString("name"))
            views.setTextViewText(row[2], if (online) "● Ready" else "Not reachable")
            views.setTextColor(row[2], if (online) 0xFF45D07E.toInt() else 0xFF8A8A8F.toInt())
            views.setOnClickPendingIntent(row[3], open(context, "sidekick://send?id=$id", 10 + i))
            views.setOnClickPendingIntent(row[4], open(context, "sidekick://ping?id=$id", 20 + i))
        }
        views.setOnClickPendingIntent(R.id.widget_root, open(context, "sidekick://open", 2))
        return views
    }
}

/** A `sidekick://` link from a widget, until the app takes it. */
object WidgetLinks {
    @Volatile
    var pending: String? = null

    fun from(intent: Intent?) {
        val data = intent?.data ?: return
        if (data.scheme == "sidekick" && (data.host ?: "") in setOf("open", "send", "ping")) pending = data.toString()
    }

    fun take(): String? = pending.also { pending = null }
}

class SmallWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        manager.updateAppWidget(ids, SidekickWidgets.small(context))
    }
}

class DevicesWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        manager.updateAppWidget(ids, SidekickWidgets.devices(context))
    }
}
