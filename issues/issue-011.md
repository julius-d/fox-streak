# Issue 011: Streak system (fox-streak core)

Status: open | Priority: P1 | Type: gamification

## Goal
Daily streak = retention hook and namesake of fox-streak.

## Duolingo reference
Streak counts consecutive days with ≥1 lesson; Duolingo uses streak freeze/repair — we do simple v1, no shop.

## Acceptance criteria
- [ ] Streak +1 when first XP earned on a new calendar day (local tz); same-day practice never double-counts
- [ ] Missed day resets to 0 (v1 simple, no freeze); fox mascot states: empty / lit / on-fire
- [ ] Home shows flame + count + "today done" check
- [ ] Logic 100% unit-tested with fake clock (yesterday/today/tomorrow, timezone edge)

## Tasks
1. `StreakService.recordActivity(now)` returning {streak, isNewDay}
2. `StreakBadge` widget + fox asset placeholder
3. Notification hook point (local reminder, actual notifications in later issue)

## Future
Streak freeze / repair, push reminders — explicitly post-MVP.

## Follow-up (from #005 review 2026-10-11)
- Consumes #005 `LessonResult` (after #010 XP write): first XP of a new local day increments `streak_count`; sole writer of `streak_count`/`last_active_day` per #002. `on-fire` mascot state belongs here, never in #005 result screen.
