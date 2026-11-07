# Issue 115: Android home-screen widget for today's XP and streak

Status: open | Priority: P3 | Type: feature | Refined-at: 2026-11-07

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

- [ ] Widget can be added from the Android widget picker and shows streak,
      pet and XP ring as described.
- [ ] Values match the home screen for the same moment.
- [ ] Ring fill equals today's XP / daily goal, clamped at full.
- [ ] After a lesson, the widget updates without opening the app again.
- [ ] After midnight the widget shows 0 XP / empty ring without app use, and
      the at-risk state if the streak is > 0.
- [ ] After a missed day the streak number is not shown as broken.
- [ ] At-risk text shows only when at risk and space allows; the flame is
      dimmed whenever at risk.
- [ ] Fallback pet (default fox) and the "no data yet" placeholder work.
- [ ] Works in light and dark system themes with dynamic colors.
- [ ] Screen-reader description is present and localized.
- [ ] All user-visible strings are in the DE + EN arb files.
- [ ] Pure logic (at-risk rule, ring fill clamping, midnight/today handling)
      is covered by Dart unit tests.
- [ ] Manually verified on a real Android device or emulator (add/resize,
      light/dark, post-lesson update, midnight); result noted in the issue.
- [ ] Screenshots (light, dark, small and large size) are added to the issue,
      as with earlier UI issues.
- [ ] Follows #015.

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
