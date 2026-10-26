# Issue 071: Pet animation loops with a random pause instead of playing once

Status: done | Priority: P3 | Type: feature | Refined-at: 2026-10-26 | Completed-at: 2026-10-26

## Goal

Make the collectible pet's Lottie animation (`FoxMascot`, soon `FoxPet` per
#068) loop indefinitely instead of today's single play-through — play once,
wait a random, longer pause, play again — everywhere a pet is shown, while
respecting the OS "reduce motion" accessibility setting the same way
`FoxProgressBar` (#010) already does.

## Decisions (2026-10-26, with repo owner)

- **Depends on #068 (Mascot → Pet rename)**: written against today's
  `Mascot...` symbols/files as a placeholder, same note as #069 — apply to
  the renamed `Pet...` equivalents if #068 lands first.
- **Applies uniformly, every call site**: Home's tap-to-collect target,
  onboarding, lesson-result celebration, `FoxEmptyState` headers, the lootbox
  reveal, and the collection-screen grid (up to 11 tiles looping
  independently/concurrently) — no site-specific exception.
- **Loop shape**: play the Lottie once at normal speed, then wait a random
  pause of 3–8 seconds (re-rolled independently each cycle, not fixed once
  per widget instance), then play again from the start; repeat indefinitely
  for as long as the widget stays mounted.
- **Respects reduce motion, reusing #010's existing pattern**:
  `MediaQuery.disableAnimationsOf(context)` — when `true`, the pet plays
  once and holds its final frame (today's `repeat: false` behavior,
  unchanged); when `false` (default), the loop/pause behavior above applies.
  No new app-specific toggle/provider — this is the same OS-level signal
  `FoxProgressBar` already checks, not a new `foxPetLoopEnabledProvider`-style
  seam.
- **Testable randomness**: the pause's `Random` is an optional constructor
  parameter (default `Random()`), mirroring `lootbox_reward.dart`'s
  `drawCoinAmount(Random random)` seam, so tests can inject a seeded
  `Random` and assert the pause falls in [3s, 8s].
- **Existing tests updated, not worked around**: any widget/golden test that
  currently `pumpAndSettle()`s a screen/widget containing a pet must
  explicitly wrap it in a `MediaQuery` override with `disableAnimations:
  true` first (precedent already in `kit_test.dart:231`), so the pet
  doesn't loop indefinitely during the test and `pumpAndSettle()` still
  completes.
- **The play-through itself is unchanged**: same Lottie composition, same
  speed, same `BoxFit.contain` sizing — only what happens *after* a
  play-through completes is new.

## Acceptance criteria

- [ ] With reduce motion off, a pet's Lottie plays once, pauses a random
  3–8s, then plays again, indefinitely, for as long as the widget is
  mounted.
- [ ] With reduce motion on (`MediaQuery.disableAnimationsOf` true), a pet's
  Lottie plays once and holds its final frame — no loop, no pause — matching
  today's behavior.
- [ ] Behavior is identical at every current `FoxMascot`/`FoxPet` call site
  (Home, onboarding, lesson result, `FoxEmptyState`, lootbox reveal,
  collection grid) — no site-specific override.
- [ ] The pause duration is re-randomized each cycle, not fixed once per
  widget lifetime.
- [ ] A new test injects a seeded `Random` and asserts the scheduled pause
  falls within [3s, 8s] across multiple draws.
- [ ] A new test confirms that with `disableAnimations: true`, the widget
  never schedules a replay/pause after its first play-through completes.
- [ ] Every existing widget/golden test rendering a pet-bearing widget/screen
  and calling `pumpAndSettle()` is updated to set `disableAnimations: true`
  first and still passes — specifically `kit_golden_test.dart`'s
  `fox_mascot_*`/`fox_empty_state_*` cases, `kit_test.dart`'s pet/empty-state
  cases, and `mascot_screens_test.dart`'s lootbox/collection
  `pumpAndSettle()` calls.
- [ ] No timer/animation leak: the loop's pending timer/animation is
  cancelled on widget dispose (no lingering-timer test failures, no work
  after unmount).
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md's
  Verify section.

## Tasks

1. In `lib/src/widgets/fox_mascot.dart` (→ `fox_pet.dart` once #068 lands),
   convert `FoxMascot`/`FoxPet` from a `StatelessWidget` to a
   `StatefulWidget`: on composition load, if
   `!MediaQuery.disableAnimationsOf(context)`, once the Lottie's
   `AnimationController` finishes a play-through, schedule a
   `Timer`/`Future.delayed` for a random duration in [3s, 8s] (via an
   injectable `Random`), then replay from the start; repeat. Cancel the
   pending timer in `dispose()`.
2. Accept an optional `Random? random` constructor parameter (default
   `Random()`) for test seeding, following `lootbox_reward.dart`'s
   `drawCoinAmount(Random random)` seam.
3. Update the widget's doc comment (currently explains why it plays once,
   citing the `pumpAndSettle()` risk) to describe the new loop-with-pause
   behavior and the reduce-motion exception.
4. Update `test/widgets/kit_test.dart` and `test/golden/kit_golden_test.dart`'s
   pet/empty-state cases to wrap with
   `MediaQuery(data: ...copyWith(disableAnimations: true))` before
   `pumpAndSettle()`.
5. Update `test/mascot/mascot_screens_test.dart`'s `pumpAndSettle()` calls
   (lootbox reveal, collection screen) the same way.
6. Add new tests per the acceptance criteria (seeded-`Random` pause-range
   assertion, reduce-motion-disables-loop assertion, dispose-cancels-timer
   assertion).

## Out of scope

- Any change to the Lottie assets themselves, their play speed, or their
  visual content.
- The lootbox-opening/coin-reveal one-off effect animations
  (`lootbox_screen.dart`'s open/coin assets) — those remain single-play
  effects, not pets.
- Any new user-facing settings UI — this only reads the existing OS-level
  reduce-motion signal, same as #010.
- The Mascot → Pet rename itself (#068) — a dependency, not part of this
  issue's work.

## Dependencies

- Depends on #068 (Mascot → Pet rename): written against today's `Mascot...`
  names as a placeholder; apply to the renamed `Pet...` equivalents if #068
  lands first (same note as #069).
- Builds on #010/#015's `MediaQuery.disableAnimationsOf` reduce-motion
  pattern (`FoxProgressBar`) — reused here, not reinvented.
- Touches every screen using `FoxMascot`/`FoxPet`: Home (#012/#059),
  onboarding (#012), lesson result (#005–#009), `FoxEmptyState` (#015),
  lootbox reveal + collection screen (#059).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

`FoxPet` (`lib/src/widgets/fox_pet.dart`) became a `StatefulWidget` driving
its own `AnimationController` + `Timer` loop: play once, then (unless
`MediaQuery.disableAnimationsOf`) wait a random `drawFoxPetPause(Random)`
draw in [3s, 8s] and replay, forever. `didUpdateWidget` cancels any pending
pause timer when `pet.id` changes, since every call site passes no `Key`
and can reuse the same State (e.g. re-equipping on `PetCollectionScreen`
while Home stays mounted underneath). No call-site changes needed — the
loop is entirely internal to `FoxPet`.

Tests: `test/widgets/fox_pet_test.dart` (new) covers the pause bounds, the
loop/reduce-motion behavior, dispose cancelling its timer, and the pet-swap
stale-timer regression. `integration_test/issue071_pet_loop_test.dart`
(new) proves the loop through real Home/app wiring. Existing
`pumpAndSettle()`-based tests touching a pet (`kit_golden_test.dart`,
`kit_test.dart`, `pet_screens_test.dart`) now force reduce motion on first.
No visual change, so no new screenshots.

## Code review

- Stale `_pauseTimer` leaked across a pet swap (no `Key` at call sites, so
  re-equipping reuses the same State) could fire a stray restart later.
  Fixed: added `didUpdateWidget` cancelling the pending timer on `pet.id`
  change, plus a regression test proving it (fails without the fix).
- The original "dispose cancels the pending timer" test pumped well past
  the pause after disposal, which let the leaked timer fire harmlessly
  before the framework's own pending-timer check ever ran — passing even
  without the `dispose()` cancellation it claimed to cover.
  Fixed: removed that post-dispose pump so the framework's end-of-test
  invariant check is the one actually exercised.
