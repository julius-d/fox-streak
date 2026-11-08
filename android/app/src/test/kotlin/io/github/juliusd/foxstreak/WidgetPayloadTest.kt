package io.github.juliusd.foxstreak

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetPayloadTest {
    private fun state(xp: Int, atRisk: Boolean) =
        WidgetState(streakCount = 5, todayXp = xp, ringFill = xp / 50.0, atRisk = atRisk, description = "d$xp")

    private val payload = WidgetPayload(
        day = "2026-11-08",
        current = state(40, false),
        nextDay = state(0, true),
        petEmoji = "🦊",
        atRiskText = "text",
    )

    @Test
    fun usesCurrentStateOnTheSameDay() {
        assertEquals(payload.current, payload.resolve("2026-11-08"))
    }

    @Test
    fun usesNextDayStateAfterMidnight() {
        assertEquals(payload.nextDay, payload.resolve("2026-11-09"))
    }

    @Test
    fun keepsUsingNextDayStateAfterSeveralMissedDays() {
        assertEquals(payload.nextDay, payload.resolve("2026-11-15"))
    }

    @Test
    fun keepsCurrentStateWhenTheClockIsSetBack() {
        assertEquals(payload.current, payload.resolve("2026-11-07"))
    }

    @Test
    fun localDayFormatsAsIsoDate() {
        val day = WidgetPayload.localDay(0L)
        assertEquals(10, day.length)
        assertEquals('-', day[4])
    }
}
