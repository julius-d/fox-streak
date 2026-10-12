# Issue 009: Date exercise — calendar-styled date entry

Status: open | Priority: P0 | Type: feature | Refined-at: 2026-10-12

## Goal
"Day of birth" trainer: learner sees a person/event prompt and recalls the date by typing it into a calendar-styled card.

## Decisions (2026-10-11 / 2026-10-12, with repo owner)
- Full date only (2026-10-11): day-only vs full-date mode — rejected per #002 (full date only, ISO `YYYY-MM-DD`, range `1900-01-01..today`). No `granularity` column in schema v1.
- Input mode (2026-10-12): **fields only, no tappable day-grid**. The exercise reuses the same 3-field (day/month/year) auto-advance pattern as #004's `DateFields` editor, wrapped in a calendar-styled card (border + calendar-glyph header). No month-view grid, no year-jump dropdown/scroll, no new calendar package dependency — this supersedes the original "calendar month view" / "fast year jump" draft wording and #004's "editor vs. exercise" divergence note (see Follow-up).
- Default state (2026-10-12): fields start **empty** — no pre-fill, no hint of the correct answer.
- Reveal-hint (2026-10-12): added, mirrors #008's dial-pad eye-icon — reveals the correct date (via `formatDateForDisplay`) temporarily and sets `hintUsed: true` for the future #010 5-XP tier.
- A11y fallback (2026-10-12): dropped as a separate concept. Since there is only one input mode (standard text fields), the original "keyboard-accessible fallback" criterion is satisfied by giving each field proper semantics/labels — no second entry mode needed.

## Acceptance criteria
- [ ] Prompt shows e.g. "Mamas Geburtstag" above a calendar-styled card (bordered, calendar-glyph header) containing 3 numeric fields (day/month/year); locale-aware order (DE: day-month-year, EN: month-day-year); all 3 fields start empty.
- [ ] Auto-advance to the next field when the current one is complete (2 digits day/month, 4 digits year); backspace-on-empty moves back to the previous field (same behavior as #004 `DateFields`).
- [ ] CHECK enabled once all 3 fields are non-empty (`hasAnswer`); grading composes a zero-padded `YYYY-MM-DD` string and compares it exactly to the item's stored answer — no live calendar-validity check at input time (an impossible date like `30.02` simply fails to match and grades wrong).
- [ ] Reveal-hint: eye-icon button shows the correct date (via #004 `formatDateForDisplay`) temporarily; using it sets `hintUsed: true` on the outcome (future #010 5-XP tier), same affordance as #008.
- [ ] Feedback banner's `correctAnswerLabel` uses #004 `formatDateForDisplay` (DE `14.05.1985`, EN `05/14/1985`), never raw ISO.
- [ ] Each field has a screen-reader label (day/month/year) and standard keyboard/focus traversal; min 48dp touch target per field.
- [ ] Follows #015: kit tokens only (`FoxSpacing`/`FoxRadius`/colors for the card border + header), no ad-hoc styling, all strings via `lib/l10n` arb params (DE + EN).

## Tasks
1. `DateExercise` widget (`lib/src/exercises/date_exercise.dart`): calendar-styled card (border + calendar-glyph header) wrapping 3 numeric fields; reuse/adapt #004 `DateFields`' auto-advance + backspace-back focus logic; fields start empty; locale order via `Localizations.localeOf`.
2. Reveal-hint: eye-icon `IconButton` shows `formatDateForDisplay(item.answer, locale)` temporarily, sets `hintUsed: true` via the `ExerciseDraft` contract (#005).
3. Grading: compose zero-padded `YYYY-MM-DD` from the 3 fields; `grade: () => composed == item.answer`; `correctAnswerLabel: formatDateForDisplay(item.answer, locale)`.
4. Lesson shell dispatch: wire `'date'` item type to `DateExercise` in `lib/src/lesson/lesson_screen.dart` (mirrors #008 Task 4).
5. l10n: arb keys for date-field labels/placeholders + reveal-hint strings (reuse #004 wording where identical; add exercise-scoped keys otherwise) in `app_en.arb` / `app_de.arb`.
6. Stable keys for #016: card-scoped keys distinct from #004's editor keys, e.g. `dateExerciseDayField`, `dateExerciseMonthField`, `dateExerciseYearField`, `dateExerciseHintButton`.
7. Tests: leap-year dates grade correctly, ISO zero-padding, auto-advance + backspace-back, CHECK disabled until all 3 fields filled, hint reveal sets `hintUsed: true`, banner always shows locale-aware label (never raw ISO).

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
