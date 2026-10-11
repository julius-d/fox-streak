# Issue 005: Lesson player shell (Duolingo-style loop)

Status: open | Priority: P0 | Type: core | Refined-at: 2026-10-11

## Goal
One bite-size session runner used by all exercise types, like Duolingo lessons: top progress bar, 1 question per screen, CHECK button, instant right/wrong feedback, end summary with score. This issue owns the shell + controller + exercise-card contract; #006–#009 plug their cards into it.

## Decisions (2026-10-11, with repo owner)
- Queue: **whole shuffled set capped at 20** (`queue = items.shuffled().take(20)`; shuffle once at lesson start, `Random` seedable in tests). No length picker in v1. Empty set never starts (entry button disabled / `FoxEmptyState` CTA back to library); sets of 1–20 run as-is. No re-queue of wrong items in v1.
- Grading: **one-shot per card**. CHECK grades once, banner shows the correct answer on wrong, CONTINUE advances. No in-card retry. Per-item outcomes (`{itemId, correct, skipped, firstTry: true, hintUsed: false}` — `hintUsed` reserved for #008 reveal-hint → #010 5-XP tier, always false in v1) are recorded so #010 second-try/hint XP tiers stay a future hook.
- Skip + contract: **explicit Skip pre-check only** (counts as wrong, always available while answering; hidden/disabled once CHECK grades — CONTINUE is the only post-check advance). Quit-X stays always available pre- and post-check. **#005 owns the shared `ExerciseCard` contract** that #006–#009 implement (draft-answer reporting + grade hook), plus a `FakeExerciseCard` for shell tests. Prose contract + `FakeExerciseCard` example snippet below (no rigid Dart interface in v1):
  ```dart
  // Card reports draft state; shell calls grade() only on CHECK.
  // correctAnswerLabel feeds the wrong-banner; hintLabel (optional,
  // e.g. #007 first-letter hint) shows alongside it.
  onStateChanged(ExerciseDraft(
    hasAnswer: true,
    grade: () => typed == item.answer, // card-owned grading
    correctAnswerLabel: item.answer, // date cards: formatDateForDisplay
    hintLabel: null,
  ));
  ```
- Result: **score now, XP/streak stubs**. Result screen shows score % + correct count with mascot celebration (`lit` if score > 0, `empty` on 0 — no pass/fail gate in v1); XP/streak rows are stubs. The shell builds an in-memory `LessonResult` (per-item outcomes) and writes `attempts` rows **immediately on each submit/skip** (with `Clock` now via `systemClockProvider`; quit mid-lesson keeps already-answered rows, unanswered are discarded) — XP math (#010) and streak update (#011) consume the result later via the `LessonResult` provider **and** the `Navigator` return value.

## Acceptance criteria
- [ ] Entry + queue: `SetDetailScreen` gains a Practice/Start entry (`startLessonButton` as body footer / AppBar action above the list — FAB stays Add-item). Start shuffles the set's items once, caps at 20, resets index/results. Queue order stable for the session. Empty set: button disabled + `FoxEmptyState` CTA back to library (both, never starts). Controller keeps source items so Practice-again can reshuffle; shell dispatches cards by `item.type` (vocab/phone/date → #006–#009).
- [ ] Top: `FoxProgressBar` (`lessonProgressBar`, `value = outcomes.length/total`, semantics label+value) + quit-X (`quitLessonButton`) opening `FoxConfirmDialog` (`confirmQuitLessonButton`); cancel is a no-op, confirm discards session progress and pops.
- [ ] Card area: renders current item through the `ExerciseCard` contract (1 question/screen, dispatched by `item.type`). Contract: card receives `item` + `onStateChanged(ExerciseDraft(hasAnswer, grade(), correctAnswerLabel, hintLabel?))` (see Decisions snippet; shell calls `grade()` only on CHECK); shell enables CHECK iff `hasAnswer`. Input locked after CHECK.
- [ ] Bottom: one stable `FoxCheckButton` (`checkButton` key kept across phases; label flips CHECK → CONTINUE) + `FoxSecondaryButton` Skip (`skipItemButton`, always enabled **pre-check only**, hidden/disabled post-check, counts as wrong). CHECK disabled until `hasAnswer` (Skip is the no-answer escape). After CHECK: `FoxFeedbackBanner` (`lessonFeedbackBanner`, success/error variant, shows correct answer on wrong — date cards reuse #004 `formatDateForDisplay`, never raw ISO — plus optional `hintLabel`) + button tints via `correctState`.
- [ ] One-shot grading: each item yields exactly one outcome `{itemId, correct: bool, skipped: bool, firstTry: true, hintUsed: false}`; wrong/skip never re-queued; attempts rows written **immediately via existing `recordAttempt(itemId, ok, now)`** with `now` from `systemClockProvider` (attempts table only — never touches `xp_total`/`streak_count` per #002 ownership).
- [ ] End screen (`lessonResultScreen`): score % + `correct/total`, `FoxMascot` celebration (`lit` if score > 0 / `empty` on 0 — never `on-fire`; that state belongs to #011 streak moments), `FoxCelebration` micro-moment; buttons Practice again (`practiceAgainButton`, reshuffles same set) + Back to library (`backToLibraryButton`). Exposes `LessonResult{setId, itemIds, outcomes, correctCount, scorePct}` via provider **and** `Navigator` return for #010/#011; XP/streak rows shown as "coming soon" stubs or omitted — no placeholder XP math.
- [ ] No dead-ends: quit-X always available pre- and post-check (Skip pre-check only; quit also on result via back nav); state is a Riverpod `NotifierProvider` (not `autoDispose` mid-lesson) so rotation rebuilds lose nothing; system back-button during lesson routes through the same quit-confirm via `PopScope`, result-screen back pops to detail.
- [ ] Haptics: correct/wrong moments go through `FoxFeedback` behind existing `foxHapticsEnabledProvider` (default on); no settings UI in this issue (owned by #012); sound hook reserved, no new deps.
- [ ] Follows #015: reuses tokens + kit only (`FoxProgressBar`, `FoxCheckButton`, `FoxSecondaryButton`, `FoxFeedbackBanner`, `FoxConfirmDialog`, `FoxEmptyState`, `FoxMascot`/`FoxCelebration`, spacing/radius tokens), min 48dp targets, no ad-hoc styling or raw colors; all strings via `lib/l10n` arb params (DE + EN), labels wrap never clip.
- [ ] Widget tests green (see Tasks).

## Tasks
1. Model + controller (`lib/src/lesson/` new: `lesson_controller.dart`, `lesson_screen.dart`, `lesson_result.dart`, `exercise_card.dart`): `LessonState{queue: List<Item>, index, outcomes, phase: answering|feedback|done}`, `LessonController extends Notifier` with `start(items, {Random?})` (keeps source copy for `restart()`), `submitGrade(bool)`, `skip()`, `next()`, `restart()`; `LessonResult` value object + provider **and** Navigator return for #010/#011. Shell dispatches `queue[index]` by `item.type` to #006–#009 cards.
2. Shell UI: `LessonScreen` (top bar + card slot + banner slot + bottom buttons), `LessonTopBar`, `LessonResultScreen`; entry button on `SetDetailScreen` wired to `watchItemsForSet` snapshot (no new data access beyond #002 `setsRepositoryProvider`).
3. Contract + fake: `exercise_card.dart` documents `ExerciseDraft` + `ExerciseCard` widget signature (prose + example snippet in Decisions); `FakeExerciseCard` (test-only, in `test/` or `lesson/` debug export) with scripted answers for shell tests. Real cards (#006–#009) are not built here.
4. Attempts: on each graded/skip outcome call `StatsRepository.recordAttempt(itemId:…, ok:…, now: ref.watch(systemClockProvider).now())` immediately (quit keeps answered rows); assert in tests that `xp_total`/`streak_count` are untouched.
5. l10n: add arb keys (check, continue, skip, quit-lesson title/message, confirm-quit, score summary with `{correct}/{total}/{pct}` plurals, practice-again, back-to-library, empty-set note) in `app_en/app_de.arb` + hand-written delegate (no `flutter gen-l10n` in this checkout per #003 OneDrive note).
6. Tests (`test/lesson/lesson_shell_test.dart`, `NativeDatabase.memory()` + `FakeClock` overrides via `ProviderScope`, bounded pumps per #003 harness learning — never `pumpAndSettle` on `watch()` streams, reuse `settle()` helper): start-shuffles-and-caps-20, check-disabled-until-answer, correct-flow (banner success + continue advances + progress ticks), wrong-flow (banner shows correct answer, one outcome), skip-counts-wrong, quit-confirm-cancel-is-noop / quit-confirm-pops, restart-reshuffles, result-score-math, rotation-safe (pump with new surface size, index preserved), attempts-written-but-xp/streak-untouched.
7. Stable keys for #016: `startLessonButton`, `lessonProgressBar`, `quitLessonButton`, `confirmQuitLessonButton`, `checkButton` (CHECK→CONTINUE same key), `skipItemButton`, `lessonFeedbackBanner`, `lessonResultScreen`, `practiceAgainButton`, `backToLibraryButton`. Card-internal keys (dial-pad keys, calendar day cells) are owned by #006–#009.

## Out of scope
- XP formula/levels (#010) and streak update/badge (#011) — this issue only emits `LessonResult` + attempts rows.
- Hearts/lives (explicitly OFF for v1 — unlimited-lesson, no fail gate), leaderboards, shop.
- Per-type card UI + grading functions (#006 vocab-choice, #007 free-text, #008 dial-pad, #009 calendar) beyond the contract + fake.
- Settings/onboarding/copy deck (#012), images/lottie/final fox art (#014), seed content (#013), e2e harness (#016).

## Dependencies
- Builds on #002 (items + `recordAttempt` attempts-only ownership, `xp_total`←#010 / `streak_count`←#011 untouched) and #003 (`SetDetailScreen` entry point, arb scaffold, `settle()` harness learning).
- Follows #015 (kit reuse listed above; `FoxCheckButton.correctState` + `FoxFeedbackBanner` drive the feedback moment).
- Unblocks #006–#009 (implement the contract here), #010/#011 (consume `LessonResult`), #012 (settings UI for the haptics toggle, result-copy polish).

## Notes
- Duolingo reference: top progress bar, 1 question per screen, CHECK → green/red feedback banner → CONTINUE, end summary. Hearts intentionally omitted in v1.
- Assumption: single lesson = single set snapshot; mid-lesson library edits don't mutate the running queue. Correct in this file if wrong.

## Verify
```powershell
flutter analyze        # must be clean (includes riverpod_lint)
dart format --output=none --set-exit-if-changed .  # must be clean
flutter test           # new lesson-shell tests + all existing green
```
