# Issue 009: Date exercise — calendar-styled date entry

Status: done | Priority: P0 | Type: feature | Refined-at: 2026-10-12 | Completed-at: 2026-10-12

## Goal
"Day of birth" trainer: learner sees a person/event prompt and recalls the date by typing it into a calendar-styled card.

## Decisions (2026-10-11 / 2026-10-12, with repo owner)
- Full date only (2026-10-11): day-only vs full-date mode — rejected per #002 (full date only, ISO `YYYY-MM-DD`, range `1900-01-01..today`). No `granularity` column in schema v1.
- Input mode (2026-10-12): **fields only, no tappable day-grid**. The exercise reuses the same 3-field (day/month/year) auto-advance pattern as #004's `DateFields` editor, wrapped in a calendar-styled card (border + calendar-glyph header). No month-view grid, no year-jump dropdown/scroll, no new calendar package dependency — this supersedes the original "calendar month view" / "fast year jump" draft wording and #004's "editor vs. exercise" divergence note (see Follow-up).
- Default state (2026-10-12): fields start **empty** — no pre-fill, no hint of the correct answer.
- Reveal-hint (2026-10-12): added, mirrors #008's dial-pad eye-icon — reveals the correct date (via `formatDateForDisplay`) temporarily and sets `hintUsed: true` for the future #010 5-XP tier.
- A11y fallback (2026-10-12): dropped as a separate concept. Since there is only one input mode (standard text fields), the original "keyboard-accessible fallback" criterion is satisfied by giving each field proper semantics/labels — no second entry mode needed.

## Acceptance criteria
- [x] Prompt shows e.g. "Mamas Geburtstag" above a calendar-styled card (bordered, calendar-glyph header) containing 3 numeric fields (day/month/year); locale-aware order (DE: day-month-year, EN: month-day-year); all 3 fields start empty.
- [x] Auto-advance to the next field when the current one is complete (2 digits day/month, 4 digits year); backspace-on-empty moves back to the previous field (same behavior as #004 `DateFields`).
- [x] CHECK enabled once all 3 fields are non-empty (`hasAnswer`); grading composes a zero-padded `YYYY-MM-DD` string and compares it exactly to the item's stored answer — no live calendar-validity check at input time (an impossible date like `30.02` simply fails to match and grades wrong).
- [x] Reveal-hint: eye-icon button shows the correct date (via #004 `formatDateForDisplay`) temporarily; using it sets `hintUsed: true` on the outcome (future #010 5-XP tier), same affordance as #008.
- [x] Feedback banner's `correctAnswerLabel` uses #004 `formatDateForDisplay` (DE `14.05.1985`, EN `05/14/1985`), never raw ISO.
- [x] Each field has a screen-reader label (day/month/year) and standard keyboard/focus traversal; min 48dp touch target per field.
- [x] Follows #015: kit tokens only (`FoxSpacing`/`FoxRadius`/colors for the card border + header), no ad-hoc styling, all strings via `lib/l10n` arb params (DE + EN).

## Tasks
1. `DateExercise` widget (`lib/src/exercises/date_exercise.dart`): calendar-styled card (border + calendar-glyph header) wrapping 3 numeric fields; reuse/adapt #004 `DateFields`' auto-advance + backspace-back focus logic; fields start empty; locale order via `Localizations.localeOf`. — **Done**
2. Reveal-hint: eye-icon `IconButton` shows `formatDateForDisplay(item.answer, locale)` temporarily, sets `hintUsed: true` via the `ExerciseDraft` contract (#005). — **Done**
3. Grading: compose zero-padded `YYYY-MM-DD` from the 3 fields; `grade: () => composed == item.answer`; `correctAnswerLabel: formatDateForDisplay(item.answer, locale)`. — **Done**
4. Lesson shell dispatch: wire `'date'` item type to `DateExercise` in `lib/src/lesson/lesson_screen.dart` (mirrors #008 Task 4). — **Done**
5. l10n: arb keys for date-field labels/placeholders + reveal-hint strings (reuse #004 wording where identical; add exercise-scoped keys otherwise) in `app_en.arb` / `app_de.arb`. — **Done** (reused `itemDayLabel`/`itemMonthLabel`/`itemYearLabel`; added only `exerciseDateRevealHintAria`)
6. Stable keys for #016: card-scoped keys distinct from #004's editor keys, e.g. `dateExerciseDayField`, `dateExerciseMonthField`, `dateExerciseYearField`, `dateExerciseHintButton`. — **Done**
7. Tests: leap-year dates grade correctly, ISO zero-padding, auto-advance + backspace-back, CHECK disabled until all 3 fields filled, hint reveal sets `hintUsed: true`, banner always shows locale-aware label (never raw ISO). — **Done** (`test/exercises/date_exercise_test.dart`, 8 tests)

## Out of scope
- Tappable day-grid / month view, year-jump dropdown or scroll control, any new calendar package dependency — dropped per 2026-10-12 decision.
- Live per-field date-validity checking (impossible dates aren't blocked at input time, they just grade wrong); full `isValidDateAnswer` validation stays editor-only (#004).
- XP math (#010), streak (#011).

## Dependencies
- Builds on #002 (full-date ISO `YYYY-MM-DD`, range `1900-01-01..today`) and #004 (`formatDateForDisplay`, and now the same 3-field auto-advance UI pattern as `DateFields`).
- Implements the #005 `ExerciseCard` contract (`ExerciseDraft(hasAnswer, grade(), correctAnswerLabel, hintLabel?)`); reveal-hint sets `hintUsed: true` in the #005 outcome hook, consumed later by #010's 5-XP tier.
- Follows #015 (kit reuse).

## Follow-up (from #005 review 2026-10-11, updated 2026-10-12)
- Implements the #005 `ExerciseCard` contract; wrong-banner `correctAnswerLabel` reuses #004 `formatDateForDisplay` (never raw ISO).
- Owns card-internal stable keys for #016: the 3 date fields + hint button (no calendar day cells / year jump — dropped per the 2026-10-12 input-mode decision above).

## Verify
```powershell
flutter analyze        # must be clean (includes riverpod_lint)
dart format --output=none --set-exit-if-changed .  # must be clean
flutter test           # new date-exercise tests + all existing green
```

## Summary (done 2026-10-12)
- New `DateExercise` widget (`lib/src/exercises/date_exercise.dart`): bordered calendar-glyph card wrapping locale-ordered day/month/year fields (auto-advance + backspace-back, adapted from #004's inline editor logic), eye-icon reveal-hint (2s auto-hide, like #008), zero-padded ISO grading, `correctAnswerLabel` always via `formatDateForDisplay`. Wired into `lesson_screen.dart`'s `'date'` dispatch.
- Fixed a latent gap in the shared `ExerciseDraft`/`LessonItemOutcome` contract: `hintUsed` had no field on `ExerciseDraft` and both `LessonController.submitGrade` and `.skip` hardcoded `hintUsed: false`, so #008's phone reveal-hint never actually reached the outcome despite its AC claiming so. Added `ExerciseDraft.hintUsed`, wired both controller methods to read the live draft, and fixed `DialPadExercise` to set it — both #008 and #009 now genuinely satisfy the "future #010 5-XP tier" hook. Added a shared `exerciseCardMinHeight(context)` helper (`exercise_card.dart`) to de-duplicate the identical `ConstrainedBox` sizing formula #008 and #009 each had inline.
- l10n: only one new key needed (`exerciseDateRevealHintAria`); field labels reuse #004's `itemDayLabel`/`itemMonthLabel`/`itemYearLabel`.
- Tests: `test/exercises/date_exercise_test.dart` (8 widget tests), `test/exercises/dial_pad_exercise_test.dart` (2, new — #008 had none), `test/lesson/lesson_controller_test.dart` (4, new — direct `ProviderContainer` coverage for the `hintUsed` wiring on both `submitGrade`/`skip`). `integration_test/date_exercise_test.dart` (new — first integration test in the repo; added `integration_test` dev dependency) drives the real widget end-to-end and was run successfully against a local macOS build.
- All 148 existing + new tests pass; `flutter analyze`, `dart format`, `dart fix --dry-run` clean.
- Filed #025 (tech-debt, P3) for the remaining duplication: the day/month/year auto-advance/backspace-back focus logic is copy-adapted (not shared) between #004's date editor and this issue's date exercise.
