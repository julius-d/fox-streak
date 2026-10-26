# Issue 078: Split lesson completion into four sequential screens (loot box → streak → XP → summary)

Status: open | Priority: P1 | Type: UX | Refined-at: 2026-10-26

## Goal

Today, finishing a lesson shows one screen (`LessonResultScreen`) that mixes
score, pet celebration, XP count-up/level-up, and streak into a single wall
of content, with only "Practice again" / "Back to library" at the bottom —
and the daily loot box (when one applies) is shown *after* that, only once
the user taps back. Replace this with four focused screens shown in
sequence right after the lesson finishes, each celebrating one thing at a
time, ending on a summary screen with four explicit next-step options.

## Decisions (2026-10-26, with repo owner)

**Sequence, each screen shown full-screen, one at a time:**

1. **Loot box** (`lib/src/pet/lootbox_screen.dart`, existing, #059/#065/#069,
   reveal direction currently being fixed by #073) — shown first, only if
   this lesson actually won a loot box (`lootboxReward != null`, same
   condition already in `LessonController`/`_continueFromResult` today).
2. **Streak saved** (new screen) — shown next, only if *this* completion is
   what advanced or started today's streak, i.e.
   `StreakService.recordActivity()`'s existing `StreakUpdate.isNewDay`
   flag is `true`. That flag already exists in `lib/src/stats/streak_service.dart`
   but currently isn't threaded through `LessonController`/`LessonState` —
   it needs a new `streakIsNewDayAfterLesson` (or similar) field alongside
   `streakCountAfterLesson`. On a 2nd/3rd lesson the same day (streak
   already secured, `isNewDay: false`), this screen is skipped — matches
   today's always-on streak text being too noisy for repeat same-day
   lessons.
3. **XP up** (new screen) — shown next, always. Carries over today's
   XP-earned count-up (`_XpCountUp`), the perfect-score bonus callout
   (`lessonXpBonusCallout`), the level-up callout + confetti + chime
   (`_LevelUpEffects`, only when `leveledUp`), and the level progress bar
   (`FoxLevelProgressBar`) — all moved as-is from today's
   `LessonResultScreen` onto this dedicated screen.
4. **Summary** (today's `LessonResultScreen`, trimmed) — shown last, always.
   Keeps the pet celebration (`FoxCelebration` + `FoxPet`) and the score
   text (`lessonScoreSummary`, correct/total), but replaces the two
   existing buttons with four (see below).

Each of the first three screens has exactly one button, reusing the
existing `lessonContinue` ("Continue") string — no new l10n string needed,
and no back-navigation out of the sequence (consistent with how
`LootboxScreen` already behaves).

**Summary screen's four buttons**, in this order:

- **Home** — returns to the Home screen, regardless of where the lesson
  was originally entered from (Home's Continue button, Library's play
  icon, or a set's "Start lesson" FAB).
- **Set overview** — opens `SetDetailScreen` for the set just practiced,
  also regardless of entry point.
- **Redo whole set** — today's "Practice again": reshuffles the full set
  (`LessonController.restart()`), same screen.
- **Redo missed items** — new: restarts with only this session's
  not-answered-correctly items (`LessonItemOutcome.correct == false`,
  which also covers skipped items — skipping and answering wrong both
  count as "missed"). Omitted entirely (3-button screen) on a perfect
  score, since there's nothing to redo.

This drops the entry-point-aware `backLabel`/"Back to library" vs. "Back
to home" distinction from issue #034 — Home and Set overview are both
always-valid destinations now, so that caller-supplied-label plumbing in
`lesson_screen.dart`/`lesson_result.dart` can be retired.

**Visual weight**: "Redo missed items" is the primary button when present
(most learning-relevant next action); the other three are secondary. On a
perfect score (no missed items to redo), "Redo whole set" becomes the
primary button instead. Order stays Home / Set overview / Redo whole set /
Redo missed items regardless of which one is primary.

**Pet celebration** stays on the summary screen, above the score — it's
dropped from the loot box/streak/XP screens, which each already have their
own reward-specific visual.

## Acceptance Criteria

- [ ] On lesson completion, screens are shown in order — loot box (if
      earned) → streak saved (if `isNewDay`) → XP up (always) → summary
      (always) — each a full screen the user must tap through, no
      skipping ahead and no back-navigation mid-sequence.
- [ ] Loot box screen is unchanged in content/behavior (only its place in
      the sequence moves — it now appears immediately on lesson
      completion instead of on exit).
- [ ] Streak saved screen only appears when `StreakUpdate.isNewDay` is
      true for this lesson; a 2nd/3rd same-day lesson skips straight past
      it. Shows the existing streak text + `StreakBadge` content, moved
      from today's result screen.
- [ ] XP up screen always appears and carries over, unchanged: XP count-up,
      perfect-score bonus callout, level-up callout + confetti + chime
      (only when leveled up), level progress bar.
- [ ] Summary screen always appears last: pet celebration, score text
      (correct/total + %), and four buttons — Home, Set overview, Redo
      whole set, Redo missed items (omitted when there are zero missed
      items) — in that order, with the primary button chosen per the
      visual-weight rule above.
- [ ] "Redo whole set" and "Redo missed items" both restart in place (same
      `LessonScreen`/`LessonController` instance, no re-navigation) the
      same way today's "Practice again" does.
- [ ] "Home" and "Set overview" both work correctly regardless of which
      entry point originally launched the lesson (Home, Library row,
      Set detail FAB).
- [ ] `backLabel`/#034's entry-point-specific label plumbing is removed
      from `LessonScreen`/`LessonResultScreen` call sites now that both
      Home and Set overview are always shown.
- [ ] New/updated tests cover: the full sequence order (with and without a
      loot box reward, with and without `isNewDay`), the streak screen
      being skipped on a same-day repeat lesson, the summary screen's
      4-vs-3-button perfect-score case, and that redo-missed only
      includes wrong/skipped items.
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
      `dart fix --dry-run`, and `flutter test` are all clean.

## Tasks

1. `lib/src/stats/streak_service.dart` / `LessonController`: thread
   `StreakUpdate.isNewDay` through `_completeLesson` into a new
   `LessonState` field so the UI can decide whether to show the streak
   screen.
2. Add `LessonController` support for restarting with an explicit item
   subset (for "Redo missed items"), alongside the existing
   `restart()`/`start()` reshuffle-the-full-set path.
3. Extract a new `StreakSavedScreen` and `XpUpScreen` (naming TBD at
   implementation time) out of today's `lib/src/lesson/lesson_result.dart`,
   reusing its existing sub-widgets (`_XpCountUp`, `_LevelUpEffects`,
   `StreakBadge` usage) rather than rewriting them.
4. Trim `LessonResultScreen` down to the summary screen: pet celebration,
   score text, and the new four-button row/column.
5. In `lesson_screen.dart`, change the phase-`done` handling so completion
   drives the full sequential push (loot box → streak → XP → summary)
   instead of today's single `_buildResultScreen` swap plus the
   on-exit-only loot box push in `_continueFromResult`.
6. Wire the summary screen's Home/Set overview buttons to the right
   navigation (clearing back to Home, or to `SetDetailScreen` for the
   practiced set) regardless of entry point; remove the now-unused
   `backLabel` parameter and its call-site plumbing (#034).
7. Add new l10n strings (DE + EN) for "Set overview", "Redo whole set",
   "Redo missed items", and the streak-saved screen's heading.
8. Add the tests from Acceptance Criteria.
9. Run the Verify commands below.

## Out of scope

- Redesigning the loot box's own open animation/content (#073 covers its
  reveal-direction bug separately).
- Loot box trigger cadence or reward odds (#065/#067/#069).
- Any new art/Lottie for the streak-saved or XP-up screens beyond reusing
  existing #015 kit widgets.
- Streak freeze/shop mechanics.

## Dependencies

Builds on #010 (XP), #011 (streak), #015 (design kit), #059 (loot box).
Independent of #073 (loot box reveal-direction fix) but touches the same
screen's place in the completion flow — rebase/re-check after whichever of
the two lands second.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
