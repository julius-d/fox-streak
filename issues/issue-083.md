# Issue 083: Streak-saved screen polish (flicker, confetti, DE wording)

Status: open | Priority: P2 | Type: polish | Refined-at: 2026-10-31

## Context

Three small, unrelated polish items on the streak-saved moment of the
post-lesson completion sequence (#078: `LootboxScreen` -> `StreakSavedScreen`
-> `XpUpScreen` -> `LessonResultScreen`, in
`lib/src/lesson/lesson_screen.dart`'s `_runCompletionSequence`).

**Flicker root cause**: `LessonScreen.build` (lesson_screen.dart:150-156)
computes `result` and renders `LessonResultScreen` (the summary screen,
which includes `FoxPet` via `FoxCelebration` in `lesson_result.dart`) as
the current route body as soon as `state.isDone` is true — same frame.
The completion-sequence screens (`LootboxScreen`/`StreakSavedScreen`/
`XpUpScreen`) are only pushed on top afterward, deferred to an
`addPostFrameCallback` (`_ensureCompletionSequenceStarted`,
lesson_screen.dart:440-449), because pushing a route during build isn't
safe. The result: `LessonResultScreen` (with the pet) is actually painted
for one frame before the first completion-sequence screen covers it —
the flash the issue reports.

**Confetti precedent**: `XpUpScreen` already has a confetti pattern
(`_LevelUpEffects` / `_LevelUpEffectsState`, xp_up_screen.dart:133-186)
using the `confetti` package (already a pubspec dependency, added for
#053's level-up burst) — `ConfettiController` + `ConfettiWidget`,
explosive, 60 particles, played once in `initState`. That screen also
plays a sound chime (`FoxSoundPlayer.playLevelUp()`) alongside its
confetti, but `FoxSoundPlayer` (`lib/src/widgets/fox_sound.dart`) has no
streak-specific sound today — only `playLevelUp()` and `playCorrect()`.

**DE wording**: three strings in `lib/l10n/app_de.arb` currently call the
streak "Serie" instead of "Streak": `lessonStreakResultText`,
`lessonStreakSavedHeading`, and `onboardingSlide1Body`.

## Goal

Polish the streak-saved celebration moment:

1. Stop the one-frame flash of the lesson-summary/pet screen that appears
   before the first completion-sequence screen (loot box or streak-saved)
   is shown.
2. Add a confetti burst to `StreakSavedScreen`, matching `XpUpScreen`'s
   existing visual pattern.
3. Use "Streak" instead of "Serie" for the streak concept in German.

## Decisions

- **Flicker fix is left to implementation** — this issue documents the
  root cause (above); the fix just needs to ensure no frame renders
  `LessonResultScreen`/`FoxPet` before the completion sequence has started
  covering it.
- **Confetti is visual-only, no new sound.** Reuse the `_LevelUpEffects`
  pattern verbatim (`ConfettiController`/`ConfettiWidget`, explosive, 60
  particles). Unlike `XpUpScreen`'s confetti (gated on `leveledUp`),
  `StreakSavedScreen`'s confetti is unconditional — the screen itself is
  only shown when the streak actually advanced. No new sound asset/
  `FoxSoundPlayer` method: there's no streak chime today, and the
  completion sequence can already play `StreakSavedScreen` immediately
  before `XpUpScreen`'s own level-up chime, so a second distinct chime
  back-to-back would add noise without adding a new signal the confetti
  doesn't already give.
- **DE wording**:
  - `lessonStreakResultText`: `"{streakCount} Tage Serie!"` ->
    `"{streakCount}-Tage-Streak!"` (mirrors the English
    `"{streakCount}-day streak!"` hyphenated-compound form).
  - `lessonStreakSavedHeading`: `"Serie gesichert!"` -> `"Streak
    gesichert!"`.
  - `onboardingSlide1Body`: `"Übe jeden Tag ein bisschen und lass deine
    Serie wachsen."` -> `"Übe jeden Tag ein bisschen und lass deinen
    Streak wachsen."` (masculine "der Streak", common colloquial usage —
    note the article changes from "deine" to "deinen").

## Acceptance criteria

- [ ] No frame renders `LessonResultScreen` (or `FoxPet`) before the first
  completion-sequence screen is on top, for both the loot-box-first and
  streak-saved-first cases.
- [ ] `StreakSavedScreen` shows a confetti burst (same visual shape as
  `XpUpScreen`'s `_LevelUpEffects`), triggered exactly once per screen
  instance (no replay on an ancestor rebuild), with no new sound.
- [ ] DE arb strings updated exactly as specified in Decisions; EN
  strings unchanged. `app_localizations.dart` regenerated/hand-mirrored
  per `lib/l10n/README.md`.
- [ ] Tests cover: no pet/summary flash before the sequence (e.g. a pump
  that checks the first post-completion frame), the confetti widget
  appearing once on `StreakSavedScreen` and not replaying on rebuild, and
  the updated DE strings.
- [ ] `flutter analyze`, `dart format --output=none
  --set-exit-if-changed .`, `dart fix --dry-run`, and `flutter test` are
  all clean per AGENTS.md's Verify section.

## Out of scope

- Any new streak-specific sound asset or `FoxSoundPlayer` method.
- Changing the completion-sequence screen order or which screens appear
  (#078) — only removing the pre-sequence flash.
- Any other German/English wording for "streak" outside the three
  strings listed (e.g. `StreakBadge`'s `streakCountLabel`, which is just
  a bare number already language-neutral).

## Dependencies

- Builds on #078's completion-sequence split (`LootboxScreen` ->
  `StreakSavedScreen` -> `XpUpScreen` -> `LessonResultScreen`).
- Reuses #053's `confetti` dependency and `_LevelUpEffects` pattern
  (`xp_up_screen.dart`).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
