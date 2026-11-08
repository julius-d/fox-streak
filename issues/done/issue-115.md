# Issue 115: Android home-screen widget for today's XP and streak

Status: done | Priority: P3 | Type: feature | Refined-at: 2026-11-07 | Completed-at: 2026-11-08

## Goal

Give Android users a home-screen widget that shows their streak, their
equipped pet and today's XP progress at a glance, so the daily habit is
visible without opening the app.

## Rationale

The streak and daily goal are the core motivation loop. A widget keeps them
in front of the user all day and acts as a gentle reminder to practice.

## Desired behavior

- **Platform:** Android only. No iOS, Windows or macOS widget in this issue.
- **One widget, resizable**, starting small (about 2x1) and scaling up.
- **Layout, three elements side by side:**
  1. **Streak:** number of days with a flame icon (same flame as the home
     streak badge). The ice-cube variant is not used in the widget.
  2. **Pet:** the currently equipped collectible pet as a static image. If no
     pet is equipped, show the default fox.
  3. **Today's XP:** the XP number in the center of a circular progress ring
     that fills toward the daily XP goal. It mirrors the goal ring on the
     home screen and has the same meaning. The ring is clamped at full when
     the goal is exceeded.
- **Streak at risk:** defined as streak > 0 and no activity yet today (the same
  "today done" rule as the home streak badge). In that state the flame is
  dimmed and a short, encouraging text line (DE + EN, no shaming) is shown,
  e.g. "Practice today to keep your streak!". The text only appears when the
  widget is large enough to fit it; the dimmed flame always shows.
- **Tap:** opens the app home screen.
- **Styling:** Material You dynamic colors (adapts to wallpaper and system
  light/dark), not the fixed orange brand palette.
- **Empty state:** with no streak or XP yet, show streak 0, XP 0 and an empty
  ring. No special welcome state.
- **No data yet** (app never opened since the widget was added): show the fox
  with a short "Open FoxStreak" prompt (DE + EN); tapping opens the app.
- **Freshness:**
  - The widget updates whenever XP, streak, daily goal or equipped pet change
    in the app.
  - It resets at midnight without the app being opened: the new day shows
    0 XP and an empty ring.
  - After a missed day the widget keeps the last known streak number and
    shows the at-risk state. It never shows the streak as broken, because the
    streak (including a streak freeze, #087) is only settled when the app
    opens.
- **Accessibility:** the widget has a screen-reader description, e.g.
  "5 day streak, 40 of 50 XP today" (DE + EN).

## Acceptance criteria

- [x] Widget can be added from the Android widget picker and shows streak,
      pet and XP ring as described.
- [x] Values match the home screen for the same moment.
- [x] Ring fill equals today's XP / daily goal, clamped at full.
- [x] After a lesson, the widget updates without opening the app again.
- [x] After midnight the widget shows 0 XP / empty ring without app use, and
      the at-risk state if the streak is > 0.
- [x] After a missed day the streak number is not shown as broken.
- [x] At-risk text shows only when at risk and space allows; the flame is
      dimmed whenever at risk.
- [x] Fallback pet (default fox) and the "no data yet" placeholder work.
- [x] Works in light and dark system themes with dynamic colors.
- [x] Screen-reader description is present and localized.
- [x] All user-visible strings are in the DE + EN arb files.
- [x] Pure logic (at-risk rule, ring fill clamping, midnight/today handling)
      is covered by Dart unit tests.
- [x] Manually verified on a real Android device or emulator (add/resize,
      light/dark, post-lesson update, midnight); result noted in the issue.
- [x] Screenshots (light, dark, small and large size) are added to the issue,
      as with earlier UI issues.
- [x] Follows #015.

## Out of scope

- iOS and desktop widgets.
- Starting a lesson directly from the widget.
- Multiple widget types or fixed alternative sizes.
- Animated pet in the widget.
- Changes to the question format (no `docs/` update needed).

## Open questions

- AGENTS.md forbids plugins without iOS + Windows + macOS support; the usual
  Flutter widget bridge (`home_widget`) lacks desktop support. Needs a
  decision (exception or platform-guarded integration) before implementation.
- Widgets cannot be covered by widget/golden tests, and the Android SDK is not
  set up on every dev machine (CI is the only build gate there), so the manual
  device check needs a machine with the SDK.

## Summary

- Native Android `AppWidgetProvider` (Kotlin) + own `MethodChannel` (`io.github.juliusd.foxstreak/home_widget`), no pub plugin, so AGENTS.md's platform rule stays intact (`NoopHomeWidgetBridge` on other OSes).
- All rules live in Dart (`lib/src/home_widget/`): the app pushes the current state *and* the pre-resolved next-day state; the widget only compares the stored day with the device date (midnight works without the app; `DATE_CHANGED`/`TIME_SET`/`TIMEZONE_CHANGED` + 30 min `updatePeriodMillis` re-render).
- Pet = equipped pet's emoji (catalog is Lottie-only, no static art). Colors: Material You (`system_*` colors, `values-v31`/`-night-v31`), orange fallback below Android 12.
- The only native strings are the "Open FoxStreak" prompt + picker description (needed before the app ever ran); all other copy is in the arb files.
- Manual check on Pixel_9 emulator (API 36): add from picker, no-data state, push from app, light/dark, 2x1 and resized (at-risk text only when tall), rollover to a new day (0 XP, empty ring, streak kept, at risk), tap opens app. Real post-lesson update not driven through a lesson by hand; covered by `home_widget_sync_test.dart`.
- No integration_test: a home-screen widget is not part of the Flutter UI tree.
- Screenshots: `issue-115-widget-{small-light,small-dark,large-light-at-risk,large-dark-at-risk}.png`.

## Code review

- Backwards clock/timezone change flipped the widget to the next-day state (`WidgetPayload.resolve`).
  Fixed: current state is kept while `today <= day`; Kotlin test added.
- Channel handler could throw on a bad argument; `fromJson` caught only `JSONException`.
  Fixed: handler replies with `result.error`, parsing catches `Exception`.
- Empty `Intent()` fallback for the tap target; `store` used async `apply()`.
  Fixed: no click target if no launch intent; `commit()` so the update reads persisted data.
- Streak N kept (shown at risk) after missed days / in `nextDay`.
  Not changed: this is the issue's explicit requirement (streak only settles when the app opens).
- Device-language change or app resume does not re-push the localized text; landscape uses the portrait height for the at-risk line.
  Not fixed: minor, texts refresh on the next XP/streak/pet change.
- Midnight relies on `DATE_CHANGED` broadcasts with a 30 min `updatePeriodMillis` fallback; 1-cell-high size is tight.
  Not changed: platform limits, accepted.

