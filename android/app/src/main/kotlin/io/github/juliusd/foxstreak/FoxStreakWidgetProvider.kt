package io.github.juliusd.foxstreak

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import kotlin.math.roundToInt

/**
 * Home-screen widget (issue #115): streak, equipped pet and today's XP ring.
 *
 * The Flutter app pushes a [WidgetPayload] via [store]; this class only
 * renders it. A date change re-renders without the app running (the payload
 * carries the already-resolved next-day state).
 */
class FoxStreakWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { render(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context, manager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> updateAll(context)
        }
    }

    companion object {
        /** Minimum widget height (dp) at which the at-risk text line fits. */
        private const val AT_RISK_TEXT_MIN_HEIGHT_DP = 100

        private const val PREFS = "fox_streak_widget"
        private const val KEY_PAYLOAD = "payload"

        fun store(context: Context, payloadJson: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY_PAYLOAD, payloadJson).commit()
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, FoxStreakWidgetProvider::class.java))
            ids.forEach { render(context, manager, it) }
        }

        private fun load(context: Context): WidgetPayload? =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_PAYLOAD, null)
                ?.let(WidgetPayload::fromJson)

        private fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val payload = load(context)
            val views = if (payload == null) {
                RemoteViews(context.packageName, R.layout.widget_fox_streak_empty)
            } else {
                val heightDp = manager.getAppWidgetOptions(id)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
                filled(context, payload, heightDp)
            }
            openAppIntent(context)?.let { views.setOnClickPendingIntent(R.id.widget_root, it) }
            manager.updateAppWidget(id, views)
        }

        private fun filled(context: Context, payload: WidgetPayload, heightDp: Int): RemoteViews {
            val state = payload.resolve(WidgetPayload.localDay())
            val views = RemoteViews(context.packageName, R.layout.widget_fox_streak)
            views.setTextViewText(R.id.widget_streak, state.streakCount.toString())
            views.setTextViewText(R.id.widget_pet, payload.petEmoji)
            views.setTextViewText(R.id.widget_xp, state.todayXp.toString())
            views.setProgressBar(R.id.widget_ring, 100, (state.ringFill * 100).roundToInt(), false)
            // Dimmed flame whenever the streak is at risk.
            views.setInt(R.id.widget_flame, "setImageAlpha", if (state.atRisk) 90 else 255)
            val showText = state.atRisk && heightDp >= AT_RISK_TEXT_MIN_HEIGHT_DP
            views.setViewVisibility(R.id.widget_at_risk, if (showText) View.VISIBLE else View.GONE)
            views.setTextViewText(R.id.widget_at_risk, payload.atRiskText)
            views.setContentDescription(R.id.widget_root, state.description)
            return views
        }

        private fun openAppIntent(context: Context): PendingIntent? {
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: return null
            return PendingIntent.getActivity(
                context,
                0,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
