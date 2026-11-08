package io.github.juliusd.foxstreak

import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** What the widget shows for one calendar day (mirrors Dart's `HomeWidgetState`). */
data class WidgetState(
    val streakCount: Int,
    val todayXp: Int,
    val ringFill: Double,
    val atRisk: Boolean,
    val description: String,
)

/**
 * The state pushed by the app (Dart's `HomeWidgetPayload`). The app resolves
 * all rules; the only decision made here is [resolve]: before midnight show
 * [current], afterwards [nextDay].
 */
data class WidgetPayload(
    val day: String,
    val current: WidgetState,
    val nextDay: WidgetState,
    val petEmoji: String,
    val atRiskText: String,
) {
    fun resolve(today: String): WidgetState =
        // ISO dates compare chronologically as strings; a clock set back
        // keeps the current state instead of flipping to the next day.
        if (today <= day) current else nextDay

    companion object {
        fun fromJson(json: String): WidgetPayload? = try {
            val o = JSONObject(json)
            WidgetPayload(
                day = o.getString("day"),
                current = stateFromJson(o.getJSONObject("current")),
                nextDay = stateFromJson(o.getJSONObject("nextDay")),
                petEmoji = o.getString("petEmoji"),
                atRiskText = o.getString("atRiskText"),
            )
        } catch (e: Exception) {
            null
        }

        private fun stateFromJson(o: JSONObject) = WidgetState(
            streakCount = o.getInt("streakCount"),
            todayXp = o.getInt("todayXp"),
            ringFill = o.getDouble("ringFill"),
            atRisk = o.getBoolean("atRisk"),
            description = o.getString("description"),
        )

        /** The device's local calendar day as `YYYY-MM-DD`, like Dart's `toLocalDayString`. */
        fun localDay(nowMillis: Long = System.currentTimeMillis()): String =
            SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(nowMillis))
    }
}
