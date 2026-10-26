# Issue 072: Lesson progress bar drains backward on "Practice again"

Status: open | Priority: P3 | Type: fix | Refined-at: 2026-10-26

## Goal

Fix `lessonProgressBar` so tapping "Practice again" resets it to empty
instantly, instead of visibly draining backward from full to empty over
~300ms.

## Decisions (2026-10-26, with repo owner)

- **Root cause (unchanged from the original report)**: `lesson_screen.dart`
  only swaps `Scaffold.body` between the lesson body and the result
  screen — the AppBar and its `lessonProgressBar` `FoxProgressBar` stay
  mounted for the whole screen lifetime. `LessonController.restart()`
  resets `outcomes` to `[]`, so `state.progress` jumps `1.0 -> 0.0` in one
  state update, and since #066 made this bar `animated: true`, the
  still-mounted `TweenAnimationBuilder` now tweens that drop instead of
  jumping.
- **Chosen fix: key the bar per lesson attempt, forcing a remount.**
  `LessonState` gains a new `attempt` counter (`int`, starts at `0`),
  bumped every time `LessonController.start()` runs (this covers both the
  very first start and every `restart()`, since `restart()` calls
  `start()`). `lesson_screen.dart` keys `lessonProgressBar` on
  `ValueKey(state.attempt)`. A new key means a brand-new
  `FoxProgressBar`/`TweenAnimationBuilder`, which — per #066's existing
  "initial build renders its starting value immediately, never animates
  in" behavior — shows `0.0` with no tween, exactly like a first mount.
  Rejected alternatives: a general "never animate decreases" rule inside
  `FoxProgressBar` itself (more robust but requires replacing
  `TweenAnimationBuilder` with a manually-driven `AnimationController` —
  bigger change for a bug with exactly one trigger path today); and
  leaving the drain as intentional (rejected — reads as the bar
  "un-completing", not as deliberate motion).
- **Scope stays narrow**: only `lessonProgressBar`'s remount-on-attempt
  behavior changes. The forward, per-item fill animation introduced by
  #066 (answering each item during a lesson) is unaffected — it still
  tweens normally within a single attempt.

## Acceptance Criteria

- [ ] Tapping "Practice again" resets `lessonProgressBar` to empty
      instantly — no visible backward tween, regardless of how far
      through the previous attempt the player was.
- [ ] `LessonState` exposes a new `attempt` field (`int`, default `0`),
      incremented on every `LessonController.start()` call (so also on
      every `restart()`); included in `LessonState`'s `==`/`hashCode`.
- [ ] `lesson_screen.dart` keys `lessonProgressBar`'s `FoxProgressBar` on
      `ValueKey(state.attempt)`.
- [ ] Within one attempt, answering items still animates the bar's
      forward fill per #066 (unaffected by this change).
- [ ] New/updated test (likely alongside
      `test/lesson/issue066_progress_bar_animation_test.dart` or in a
      lesson-screen test) pumps only a short duration after "Practice
      again" — too short for the old 300ms tween to resolve — and asserts
      the bar's rendered value is already `0.0`, regression-testing this
      bug.
- [ ] Existing #066 tests (`test/lesson/issue066_progress_bar_animation_test.dart`,
      `test/widgets/kit_test.dart`) and the restart-race test
      (`test/lesson/lesson_controller_restart_race_test.dart`) stay green.
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
      `dart fix --dry-run`, and `flutter test` are all clean.

## Tasks

1. Add `attempt` (`int`, default `0`) to `LessonState`: constructor field,
   `copyWith` param, `==`, `hashCode`.
2. In `LessonController.start()`, bump `attempt` by one on the new state
   (alongside the existing `_generation++`).
3. In `lesson_screen.dart`, add `key: ValueKey(state.attempt)` to the
   `lessonProgressBar` `FoxProgressBar`.
4. Add the regression test from Acceptance Criteria.
5. Run the Verify commands below.

## Out of scope

- A general "skip animation on decrease" rule inside `FoxProgressBar`
  itself (rejected above).
- Any other #066 animation behavior (per-item forward fill, reduce-motion
  handling).

## Dependencies

Depends on #066 (done) having introduced `animated: true` on
`lessonProgressBar`; no other open dependencies.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
