# Issue 073: Loot box opens immediately instead of starting closed; add a tap-hint pulse

Status: open | Priority: P2 | Type: fix | Refined-at: 2026-10-26

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

- [ ] On every fresh push of `LootboxScreen`, the box renders fully closed
      (the asset's last frame, no motion) immediately — true both when the
      Lottie composition loads fast and when it's still loading.
- [ ] Tapping plays the existing opening Lottie in reverse (`1.0 → 0.0`),
      ending on the open/first frame, then transitions to the revealed
      phase — visually identical motion to today's intended design, just
      correctly triggered and in the right direction.
- [ ] While closed and tappable, the box runs a continuous subtle pulse
      (scale) loop, unless `MediaQuery.disableAnimationsOf(context)` is
      true, in which case it stays static-closed with no pulse.
- [ ] Tapping stops the pulse and starts the opening animation with no
      visible jump/snap, regardless of which point in the pulse cycle the
      tap lands on.
- [ ] Tapping again while opening (already non-interactive) remains a
      no-op, unchanged from today.
- [ ] The revealed phase (`FoxCelebration` + reward content) is unaffected.
- [ ] New/updated tests in `test/mascot/mascot_screens_test.dart` (or a new
      `lootbox_screen_test.dart`) cover: the box is static-closed (value
      `1.0`) on initial build (regression test for this bug), the pulse
      runs while closed, the pulse is skipped when `disableAnimations` is
      true (mirroring `test/widgets/kit_test.dart`'s existing
      `FoxProgressBar` reduce-motion test), and tapping reverses the
      controller to `0.0` and reaches `revealed`.
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
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
