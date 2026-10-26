# Issue 066: Lesson progress bar grows with an animation

Status: done | Priority: P3 | Type: polish | Refined-at: 2026-10-26 | Completed-at: 2026-10-26

## Goal

The progress bar at the top of the lesson screen (`lib/src/lesson/lesson_screen.dart`'s
`FoxProgressBar`, value = `answeredCount / total`) currently jumps instantly
to its new value each time an item is answered. It should instead animate
the growth, giving the same kind of satisfying, bouncy feedback the kit
already favors elsewhere (#015).

This is scoped to the *lesson* progress bar only. `FoxLevelProgressBar`
(the gold level-up bar, #053) already has its own bespoke
`_LevelUpFillAnimation` and is unaffected by this issue.

## Decisions (2026-10-26, with repo owner)

- **Opt-in param on `FoxProgressBar`**: add an `animated` bool param
  (default `false`) to the shared `lib/src/widgets/fox_progress_bar.dart`
  widget rather than animating unconditionally or building a one-off
  wrapper in `lesson_screen.dart`. When `true`, the widget implicitly
  tweens its fill (e.g. `TweenAnimationBuilder<double>`) whenever `value`
  changes between rebuilds; when `false` (the default — all existing
  callers), it renders the given `value` immediately with no animation, so
  the kit golden test (`fox_progress_bar_*`, fixed at `value: 0.6`), the
  clamping widget test (`FoxProgressBar(value: 2, ...)`), and
  `FoxLevelProgressBar`'s existing `_LevelUpFillAnimation` (which already
  drives `value` itself via its own `AnimationController` and must not be
  double-animated by the bar underneath it) are all unaffected.
- **Lesson screen opts in**: `lesson_screen.dart`'s `FoxProgressBar` (key
  `lessonProgressBar`) passes `animated: true`.
- **Duration/curve — 300ms, `Curves.easeInOut`**: fast enough to stay out
  of the way when answering items quickly in succession, consistent with
  the kit's "instant feedback, bouncy micro-moments" principle (#015)
  rather than #053's slower 900ms (that animation is a rarer, two-part
  level-up sequence, not a per-item tick).
- **Respects reduced motion**: when `MediaQuery.of(context).disableAnimations`
  is `true`, the bar jumps straight to the new value (no tween), even
  though `animated` is `true`. This is the first animation in the app to
  check this flag — #053's level-up animation does not, and is unaffected
  by this issue.

## Acceptance criteria

- [x] `FoxProgressBar` gains an `animated` bool param, default `false`;
  behavior for every existing caller (kit golden test, `kit_test.dart`'s
  clamping test, `FoxLevelProgressBar`'s plain and `_LevelUpFillAnimation`
  branches) is unchanged.
- [x] When `animated: true` and `MediaQuery.disableAnimations` is `false`,
  a `value` change (e.g. 0.2 → 0.3 across a rebuild) animates the fill
  over ~300ms with `Curves.easeInOut` instead of jumping instantly.
- [x] When `animated: true` and `MediaQuery.disableAnimations` is `true`,
  the fill jumps instantly to the new `value` (no tween).
- [x] The initial build of an `animated: true` bar renders its starting
  `value` immediately — it does not animate in from 0 on first appearance.
- [x] `lesson_screen.dart`'s `lessonProgressBar` passes `animated: true`;
  manually answering/skipping items in a lesson shows the bar animating
  between steps instead of snapping.
- [x] New widget test(s) for `FoxProgressBar`'s `animated: true` behavior:
  value change animates over time (e.g. pump partway and assert an
  intermediate rendered value), and `disableAnimations: true` jumps
  instantly.
- [x] Existing `fox_progress_bar_*` golden images and
  `kit_test.dart`'s `FoxProgressBar(value: 2, ...)` clamping test are
  unaffected (no golden regeneration needed, since the new param defaults
  to the current behavior).
- [x] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md's
  Verify section.

## Tasks

1. In `lib/src/widgets/fox_progress_bar.dart`: add the `animated` param;
   when `true`, wrap the `LinearProgressIndicator` in a
   `TweenAnimationBuilder<double>` keyed on `value` (duration 300ms,
   `Curves.easeInOut`), short-circuiting to an instant value when
   `MediaQuery.of(context).disableAnimations` is `true`.
2. In `lib/src/lesson/lesson_screen.dart`: pass `animated: true` on the
   `lessonProgressBar` `FoxProgressBar`.
3. Add widget tests per the acceptance criteria above (new tests near
   `test/widgets/kit_test.dart` or a new `fox_progress_bar_test.dart`).

## Out of scope

- `FoxLevelProgressBar` / `_LevelUpFillAnimation` (#053) — unchanged.
- Any other progress indicator in the app.
- A general reduced-motion audit of existing animations (e.g. #053's
  level-up fill, `FoxCelebration`) — this issue only makes the *new*
  per-item animation respect it.

## Dependencies

- None. Builds on the existing `FoxProgressBar` (#015) and lesson
  controller's `progress` getter (#005).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

`FoxProgressBar` gained an `animated` bool param (default `false`); when
`true` and `MediaQuery.disableAnimationsOf(context)` is `false`, it wraps
the fill in a `TweenAnimationBuilder<double>` (300ms, `Curves.easeInOut`)
keyed on `value`, otherwise rendering instantly. `lesson_screen.dart`'s
`lessonProgressBar` now passes `animated: true`. Covered by new
`kit_test.dart` widget tests (tween-over-time, reduced-motion instant
jump, no animate-in-from-0 on first build) and a new
`integration_test/issue066_progress_bar_animation_test.dart` driving the
real `LessonScreen`.

## Code review

- Finding: `disableAnimations` was read via `MediaQuery.of(context)`
  (subscribes to the whole `MediaQueryData`, causing extra rebuilds on any
  change, e.g. keyboard open/close) instead of the scoped
  `MediaQuery.disableAnimationsOf(context)`.
  Fixed — switched to the scoped accessor.
- Finding: `Theme.of(context)` was looked up inside `_fill()`, so the
  animated path re-ran that lookup on every animation frame (~18× over
  300ms) instead of once per build.
  Fixed — `ColorScheme` is now resolved once in `build()` and passed into
  `_fill()`.
- Finding: tapping "Practice again" resets `LessonController` state, so
  `progress` drops from `1.0` to `0.0` in one update; since the AppBar's
  `FoxProgressBar` stays mounted across the restart, it now tweens that
  drop backward over ~300ms instead of resetting instantly.
  Not fixed — not covered by this issue's acceptance criteria (growth-only
  animation), and a correct fix needs a way to force a fresh widget
  instance per lesson attempt, which is more than a small/easy change.
  Filed as #072.
- Finding: nothing stops a future caller from passing `animated: true`
  into `FoxLevelProgressBar` (which already drives its own value via
  `_LevelUpFillAnimation`), which would double-animate.
  Not fixed — no current caller does this (both existing call sites omit
  `animated`, defaulting to `false`); the doc comment already warns
  against it, and a runtime assert for a hypothetical future misuse isn't
  warranted now.
