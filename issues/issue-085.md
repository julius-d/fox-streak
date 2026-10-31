# Issue 085: Wheel of Fortune

Status: open | Priority: P3 | Type: feature | Refined-at: 2026-10-31

## Context

Today's post-lesson completion sequence (#078:
`LootboxScreen` -> `StreakSavedScreen` -> `XpUpScreen` ->
`LessonResultScreen`, driven by `LessonScreen._runCompletionSequence`) only
fills a reward moment on the day's 1st completion (streak-saved, if the
streak actually advanced) and on the 2nd/5th/8th/11th/... completion (loot
box, #067's repeating-every-3rd-after-the-first cadence). Every other
completion (3rd, 4th, 6th, 7th, 9th, 10th, ...) shows nothing but the
plain lesson-result/summary screen.

This issue adds a third reward moment — a spinnable Wheel of Fortune —
filling the 3rd/6th/9th/... slot, which never overlaps the loot box's
2/5/8/11/... slot or the streak-saved screen's day-1-only trigger.

## Goal

Give the user a wheel-of-fortune spin, awarding coins, on a cadence that
fills a currently-empty reward slot in the completion sequence.

## Decisions

- **Trigger — every 3rd completion (3, 6, 9, 12, ...), uncapped**: computed
  from the same day-scoped `lessonsCompletedToday` counter `PetService`
  already owns (`PetService.recordLessonCompletion`). Firing on
  `newCount % 3 == 0` is disjoint from the loot box's `newCount >= 2 &&
  (newCount - 2) % 3 == 0` (2, 5, 8, 11, ... are all `≡ 2 mod 3`; 3, 6, 9,
  ... are all `≡ 0 mod 3`) — the two can never trigger on the same
  completion, so no ordering/stacking question arises between them.
- **Reward — coins only, new small segment set**: unlike the loot box, the
  wheel never awards a pet. Six segments: **10, 20, 30, 50, 75, 100**
  coins, weighted toward smaller amounts via `weight(amount) = 110 -
  amount` (100 for 10 coins, down to 10 for 100 coins; total weight 375) —
  same "smaller is more likely" shape as the loot box's `drawCoinAmount`,
  but a distinct, wheel-sized table (not the loot box's 20-value table,
  which has too many entries for legible wheel slices). Coins are added to
  the same `profileStats.coinsTotal` column the loot box already writes to
  (via `StatsRepository.addCoins`), from the same `PetService` call site —
  no new "sole writer" path.
- **Spin mechanic — reward decided first, spin is cosmetic**: exactly like
  the loot box (reward persisted by `PetService.recordLessonCompletion`
  *before* the reveal screen ever opens), the coin amount is drawn by RNG
  before the wheel starts spinning. Tapping the wheel starts the spin;
  tapping again *or* an automatic stop after a short fixed delay (if the
  user never taps a second time) ends it — either way, the spin's target
  rotation is calculated to land on the segment matching the
  already-decided amount. Stop timing changes how long the spin feels,
  never the odds or the outcome.
- **Sequence placement — same "reward slot" as the loot box**: in
  `LessonScreen._runCompletionSequence`, a wheel win pushes a new
  `WheelScreen` at the same point the loot box would occupy (before
  streak-saved, before XP-up). Since the two are mutually exclusive by
  cadence, this is a sibling `if`, not a reordering of the existing
  sequence.
- **Back-nav blocked from the start**: unlike the loot box/streak-saved/
  XP-up screens (#082, still an open gap for those three), `WheelScreen`
  ships with `PopScope(canPop: false)` from day one — a spin result is
  persisted to `coinsTotal` as soon as it's drawn, same reward-visibility
  concern #082 raised for the loot box.
- **Visual — placeholder wheel, final art out of scope**: a simple
  `CustomPainter`-drawn pie-chart wheel (six colored slices labelled with
  their coin amounts, theme colors from `FoxStreakTheme`) with a rotating
  `AnimationController`-driven spin. No new Lottie/illustration asset is
  in scope — same "final art out of scope" precedent as `FoxPet`.
- **Location**: new `lib/src/lesson/wheel_screen.dart`, alongside
  `streak_saved_screen.dart`/`xp_up_screen.dart` — grouped with the other
  completion-sequence screens rather than `lib/src/pet/`, since this isn't
  pet-collection related.

## Acceptance criteria

- [ ] `PetService.recordLessonCompletion` triggers a wheel win when
  `newCount % 3 == 0` (and `newCount > 0`), returning a drawn coin amount
  alongside (not instead of) its existing loot-box-reward/`equippedPetId`
  result — the two reward fields are never both non-null for the same
  call, by construction of the disjoint cadences.
- [ ] A new weighted draw function (mirroring `drawCoinAmount`'s shape)
  picks from `{10, 20, 30, 50, 75, 100}` with weight `110 - amount`; the
  won amount is added to `coinsTotal` via the existing
  `StatsRepository.addCoins`.
- [ ] `WheelScreen` (new, `lib/src/lesson/wheel_screen.dart`) renders a
  six-segment wheel, starts spinning on tap, stops on a second tap or an
  automatic timeout, and always visually lands on the segment matching the
  amount already drawn/persisted by `PetService` — regardless of when
  (or whether) the user taps to stop it.
- [ ] `WheelScreen` has `PopScope(canPop: false)` — no system back/swipe
  dismissal mid-spin or mid-reveal.
- [ ] `LessonScreen._runCompletionSequence` pushes `WheelScreen` in the
  loot box's sequence slot when a wheel win is present, leaving the
  streak-saved/XP-up steps and their relative order unchanged.
- [ ] New DE + EN l10n strings (heading, tap-to-spin prompt, "You won
  {amount} coins!" result text, coin semantic label) — no hardcoded
  strings.
- [ ] `mascot_service_test.dart` (or wherever `PetService`'s tests live):
  new tests confirm the wheel triggers at 3, 6, 9, and an arbitrarily high
  multiple (e.g. 48), confirm no trigger at 1, 2, 4, 5, 7, 8, and confirm
  it never coincides with a loot-box trigger on the same call.
- [ ] A distribution sanity test for the new weighted draw (10 coins drawn
  more often than 100 over many seeded trials).
- [ ] A widget test drives `WheelScreen` to both an early manual stop and
  the automatic timeout and asserts the wheel lands on the same
  already-decided segment either way.
- [ ] `flutter analyze`, `dart format --output=none
  --set-exit-if-changed .`, `dart fix --dry-run`, and `flutter test` are
  all clean per AGENTS.md's Verify section.

## Tasks

1. In `lib/src/pet/lootbox_reward.dart` (or a new sibling file): add the
   wheel's coin-amount table/weight function/weighted draw, mirroring
   `kLootboxCoinAmounts`/`_weightForCoinAmount`/`drawCoinAmount`.
2. In `lib/src/stats/pet_service.dart`: extend
   `recordLessonCompletion`'s return type with a wheel-win coin amount;
   add the `newCount % 3 == 0` check and the draw/persist call (reusing
   `StatsRepository.addCoins`); update the class/method doc comments
   (cadence, ownership) to cover the wheel alongside the loot box.
3. Add `lib/src/lesson/wheel_screen.dart`: `WheelScreen` widget — six-slice
   `CustomPainter` wheel, tap-to-spin, tap-or-timeout-to-stop, forced
   landing on the predetermined amount, `PopScope(canPop: false)`, pops
   itself on Continue like the other completion screens.
4. Wire `WheelScreen` into `LessonScreen._runCompletionSequence` in the
   loot box's slot.
5. l10n: add the wheel's heading/prompt/result/semantic-label arb keys (DE
   + EN).
6. Tests per the acceptance criteria above (`pet_service_test.dart`
   cadence + distribution tests, a `wheel_screen_test.dart` widget test,
   any new migration-free since `coinsTotal` already exists).

## Out of scope

- Pets as a wheel reward — coins only, unlike the loot box.
- Spending coins (still no sink anywhere, per #065).
- Final wheel illustration/animation asset — placeholder `CustomPainter`
  wheel only.
- Retrofitting `PopScope(canPop: false)` onto the loot box/streak-saved/
  XP-up screens — that's #082's scope, not this issue's.
- Any change to the loot box's or streak-saved screen's own trigger
  cadence.

## Dependencies

- Builds on #065 (`coinsTotal` column, `StatsRepository.addCoins`) and
  #067 (the repeating-every-3rd trigger pattern this issue's cadence
  mirrors, offset to stay disjoint).
- Builds on #078's completion-sequence plumbing
  (`LessonScreen._runCompletionSequence`).
- Follows #082's `PopScope(canPop: false)` precedent proactively, rather
  than depending on #082 landing first.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
