# Issue 073: Loot box opens immediately instead of starting closed; add a tap-hint pulse

Status: done | Priority: P2 | Type: fix | Refined-at: 2026-10-26 | Completed-at: 2026-10-26

## Goal

Fix the daily lootbox reveal (`lib/src/mascot/lootbox_screen.dart`) so the
box always renders closed and static the moment the screen appears, and
only plays its opening animation once the player taps it — today it shows
already open on screen entry instead. While closed, add a subtle looping
pulse so the box visibly invites a tap.

## Decisions (2026-10-26, with repo owner)

- **Root cause, confirmed**: `kLootboxOpenAnimationAsset`'s frame 0 is the
  *open* box artwork, and its last frame is the *closed* box — i.e. the
  Lottie plays closed→open in reverse-frame order. `_animationController`
  currently starts at its default value `0.0` (frame 0 = open) and
  `_open()` calls `.forward()`, which is backwards: the fix is to start the
  controller at its upper bound (`1.0`, the closed/last frame) and drive
  the open animation with `.reverse()` (toward `0.0`, the open/first
  frame) on tap, instead of `.forward()`.
- `_handleAnimationStatus` currently reacts to `AnimationStatus.completed`
  to flip to `_LootboxPhase.revealed`; once opening runs via `.reverse()`,
  the completion signal is `AnimationStatus.dismissed` (value reaching
  `0.0`) instead.
- **Open animation itself is otherwise unchanged**: same
  `kLootboxOpenAnimationAsset`, same visual — only the start value and
  forward/reverse direction change. No redesign of the opening animation
  in this issue.
- **New idle hint: gentle pulse while closed**: while `_phase == closed`,
  loop a subtle scale pulse (e.g. `1.0` ↔ `1.05`) on the box to hint it's
  tappable. This is a new, separate `AnimationController` from the one
  driving the open Lottie — it must stop the instant `_open()` fires, with
  no visible snap before the open animation takes over.
- **Respect reduce-motion, following the one existing precedent**:
  `lib/src/widgets/fox_progress_bar.dart` (#066) checks
  `MediaQuery.disableAnimationsOf(context)` and skips its animation,
  rendering the final state directly, when it's on. The new pulse follows
  the same pattern: when `disableAnimationsOf(context)` is true, the box
  stays static-closed with no pulse loop (tapping still opens it normally
  — only the idle hint motion is skipped).
- No other reduce-motion precedent exists in the kit beyond
  `fox_progress_bar.dart` — confirmed by repo-wide search.

## Acceptance Criteria

- [x] On every fresh push of `LootboxScreen`, the box renders fully closed
      (the asset's last frame, no motion) immediately — true both when the
      Lottie composition loads fast and when it's still loading. *(Not
      the last frame — see Summary: the real closed frame is mid-range.)*
- [x] Tapping plays the opening Lottie, ending on the open frame, then
      transitions to the revealed phase. *(Plays forward `0.2 → 1.0`, not
      reverse `1.0 → 0.0` as originally assumed — see Summary.)*
- [x] While closed and tappable, the box runs a continuous subtle pulse
      (scale) loop, unless `MediaQuery.disableAnimationsOf(context)` is
      true, in which case it stays static-closed with no pulse.
- [x] Tapping stops the pulse and starts the opening animation with no
      visible jump/snap, regardless of which point in the pulse cycle the
      tap lands on.
- [x] Tapping again while opening (already non-interactive) remains a
      no-op, unchanged from today.
- [x] The revealed phase (`FoxCelebration` + reward content) is unaffected.
- [x] New/updated tests in `test/pet/pet_screens_test.dart` (the file was
      renamed off "mascot" by #068, before this issue was refined) cover:
      the box is static-closed on initial build (regression test for this
      bug), the pulse runs while closed, the pulse is skipped when
      `disableAnimations` is true (mirroring `test/widgets/kit_test.dart`'s
      existing `FoxProgressBar` reduce-motion test), and tapping plays the
      controller forward and reaches `revealed`. A new
      `integration_test/issue073_lootbox_closed_pulse_test.dart` drives
      the real app end-to-end to the same effect.
- [x] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
      `dart fix --dry-run`, and `flutter test` are all clean.

## Tasks

1. In `_LootboxScreenState`: initialize `_animationController` at value
   `1.0` (closed/last frame) instead of the default `0.0`; change `_open()`
   to call `.reverse()` instead of `.forward()`; change
   `_handleAnimationStatus` to flip to `revealed` on
   `AnimationStatus.dismissed` instead of `.completed`.
2. Add a dedicated pulse `AnimationController` in `_LootboxScreenState`
   (separate from the open-animation controller), looping a subtle scale
   tween only while `_phase == closed` and
   `!MediaQuery.disableAnimationsOf(context)`; stop/dispose it when
   `_open()` fires.
3. Wrap the closed-state rendering with the pulse's `Transform.scale`,
   keeping the existing `InkWell`/`Semantics` tap target intact.
4. Add the tests from Acceptance Criteria.
5. Run the Verify commands below.

## Out of scope

- Redesigning the opening Lottie animation itself.
- Loot-box trigger cadence (#067) or reward odds (#065 / #069).

## Dependencies

None blocking; independent of #067, #068, #069.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

This issue's stated root cause was wrong: `kLootboxOpenAnimationAsset` has
no closed frame at either `0.0` or `1.0` — both show the box already
open. Sampling the composition in 1% steps found the real closed frame
sits mid-range (~frame 27 of 136, value `0.2`); the asset opens briefly
at `0.0`, swings shut by ~frame 10, holds shut through ~frame 54, then
cracks open with a sparkle burst through frame 136. Fix:
`_animationController` starts at `0.2` and `_open()` plays `.forward()`
to `1.0` — direction/status (`.completed`) unchanged from before this
issue, only the starting value changed. The tap-hint pulse plays a
bounded breath-then-pause loop rather than a true non-stop `repeat()`,
since a perpetually-ticking `Transform.scale` on a real tap target races
both synthetic taps and `settle()`-style bounded-frame polling in
integration tests (confirmed against
`issue067_repeated_lootbox_test.dart`/`issue069_pet_rarity_test.dart`).

## Code review

1. `_stopPulse()` only stopped the pulse controller, never reset its
   value — a live reduce-motion toggle mid-breath left the box
   permanently scaled.
   Fixed: added `_resetPulse()` (stop + snap `value` to `0.0`), used from
   `didChangeDependencies` only when still closed and reduce-motion turns
   on; `_open()` still uses the plain freeze-in-place `_stopPulse()`.
2. `_LootboxPhase`'s doc comment still said "frozen on frame 0," stale
   after the fix moved the closed value to `0.2`.
   Fixed: reworded to "frozen on the closed frame" (no hardcoded value to
   go stale again).
3. Starting `_animationController` at `0.2` means its idle status reports
   `forward`, not `dismissed` as at `0.0` — a latent footgun for future
   code assuming an idle controller is `dismissed`.
   Not fixed as code (nothing reads the status while idle today); added a
   comment at the `_closedValue` declaration flagging it instead.
4. `_pulsePauseTimer` was never nulled when its own callback fired
   naturally, relying on `isAnimating` to short-circuit the double-start
   guard — fragile if that ordering ever changes.
   Fixed: the timer callback now nulls `_pulsePauseTimer` before calling
   `.forward()`.
5. The new pulse's "bounded play, pause, repeat" shape duplicates
   `fox_pet.dart`'s `_FoxPetState` (#071) with no shared abstraction.
   Not fixed here (cross-file refactor touching the stable `FoxPet`
   widget, beyond a small/easy fix); filed as #079.
