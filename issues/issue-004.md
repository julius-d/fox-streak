# Issue 004: Question editors for 3 content types

Status: done | Priority: P0 | Type: feature | Refined-at: 2026-10-11

## Goal
Replace the minimal `ItemEditorDialog` shell from #003 with tailored editors per item type (vocab DE<->EN, phone numbers, birth dates), so parents/teachers/learners can create valid items without knowing the storage format. Validation mirrors #002 `validation.dart` exactly; storage formats never change (phone digits-only, date ISO).

## Decisions (2026-10-11, with repo owner)
- Phone display: **simple grouping** (display-only spaces for readability, e.g. `0171 123 4567`); stored value stays digits-only.
- Distractors: **editor provides 3 optional fields only**; no auto-suggest/generator in this issue. Lesson-time fallback (same-set pick, placeholder) is owned by #006.
- Hint column + type-switch-on-edit semantics: **out of scope** for this issue (deferred).
- Date editor: **no `showDatePicker` / month-grid scrolling**. Calendar-styled card containing **3 numeric fields** (day / month / year) with **auto-advance** on fill to minimize tapping. Display order/format is locale-aware (DE: `TT.MM.JJJJ`, EN: `MM/DD/YYYY`); stored value is always ISO `YYYY-MM-DD`.

## Acceptance criteria
- [ ] General: one reusable `ItemEditor` switching fields by `type`; inline field errors; no save on invalid; existing widget keys stable (`itemTypeField`, `itemPromptField`, `itemAnswerField`, `itemDirectionField`, `saveItemButton`) for #016; new finder keys `itemChoice0Field`, `itemChoice1Field`, `itemChoice2Field`, `itemDayField`, `itemMonthField`, `itemYearField` (phone reuses `itemAnswerField`) for #016.
- [ ] Vocab editor: `prompt` + `answer` text fields (trim-then-require non-empty), direction toggle DE->EN / EN->DE (`SegmentedButton`, required, `validateDirection`; new items start with `null` direction — no pre-select — and show an inline error until picked; existing items keep their stored value), 3 optional distractor fields validated by `validateChoices` for non-empty strings plus an editor-only duplicate-vs-`answer` check (trim/case-insensitive; `validation.dart`/`SetsRepository`/codec unchanged — duplicates stay importable, #006 fallback tolerates them); blank distractors allowed (fallback in #006); existing `choices` preserved on edit.
- [ ] Phone editor: name label (`prompt`) + digit-only field (reuses `itemAnswerField` key); numeric keyboard with no `+` key; live simple grouping (display-only, storage untouched; exact spacing is implementer choice — tests assert digits-stored + spaces-display-only only); paste auto-strips spaces/`-`/`/`/`(`/`)`/`.`/`+` via `normalizePhone`; stored value matches `^[0-9]{3,15}$` with leading `0` kept (e.g. `0164256737871`); invalid shows `errorInvalidPhone`. Edit mode pre-fills the grouped display from stored digits.
- [ ] Date editor: label (`prompt`) + calendar-styled card with 3 numeric inputs (`itemDayField`, `itemMonthField`, `itemYearField`; day 1-31, month 1-12, year 1900-today); locale-aware order (DE: day-month-year, EN: month-day-year) and locale-aware display via the new `formatDateForDisplay` pure helper owned by this issue (DE `14.05.1985`, EN `05/14/1985`; #009 reuses it for grading feedback); auto-advance to next field when current is complete (2 digits day/month, 4 digits year) plus backspace-on-empty goes back; numeric keyboards; composed value stored as ISO `YYYY-MM-DD`; range `1900-01-01..today` via `isValidDateAnswer` with `today` from injected `Clock` (`systemClockProvider`, `FakeClock` in tests); invalid (incl. future, pre-1900, impossible like 30.02, non-leap 29.02) shows `errorInvalidDate`. Edit mode splits stored ISO into the 3 fields.
- [ ] Follows #015: reuses tokens + kit (`FoxPrimaryButton`/`FoxSecondaryButton`, `FoxFeedbackBanner` for save errors, spacing/radius tokens), min 48dp targets, no ad-hoc styling or raw colors; all new strings via `lib/l10n` arb params (DE + EN), labels wrap never clip.
- [ ] Widget tests green (see Tasks).

## Tasks
1. Replace `ItemEditorDialog` field section with per-type subforms (`VocabFields`, `PhoneField`, `DateFields`) switching on `_type`; keep dialog shell + save flow (`SetsRepository.addItem`/`updateItem`, `FoxFeedbackBanner` on repo error). Never touch `hint` (leave `Value.absent` / `''` default) so existing hints are preserved.
2. Vocab: wire direction segmented control (required, nullable initial for new items, inline error via `validateDirection`) + 3 optional distractor `TextFormField`s (`itemChoice0/1/2Field`, `choices`); trim before validate/save; editor-only reject of distractor duplicating `answer`; omit `direction`/`choices` for non-vocab on save.
3. Phone: `TextInputType.number`, `FilteringTextInputFormatter.digitsOnly` + paste-strip via `normalizePhone`; live grouping formatter (display-only, cursor-stable); validator `isValidPhoneAnswer`; save passes raw input (repo normalizes), test asserts stored digits-only.
4. Date: `DateFields` widget — 3 numeric fields in a calendar-styled card (`FoxSpacing`/`FoxRadius` tokens), focus-node auto-advance (day→month→year, backspace-on-empty goes back), validators per part + composed `isValidDateAnswer(today)` with `today` from `ref.watch(systemClockProvider)`; locale order via `Localizations.localeOf`; display via new pure `formatDateForDisplay(isoDay, locale)` helper (unit-tested, reused by #009); save composes ISO `YYYY-MM-DD`. Edit mode splits stored ISO into day/month/year.
5. l10n: add arb keys for distractor labels/placeholders, date day/month/year labels, date display hints, plus error keys `errorDuplicateChoice` and date-part errors (DE + EN, hand-written delegate per #003 OneDrive note — no `flutter gen-l10n` in this checkout).
6. Tests (`test/library/item_editor_test.dart`, `NativeDatabase.memory()` + `FakeClock` overrides via `ProviderScope` (`appDatabaseProvider`, `setsRepositoryProvider`, `systemClockProvider`), bounded pumps per #003 harness learning — never `pumpAndSettle` on `watch()` streams, reuse `settle()` helper): vocab-valid with 3 distractors, vocab-missing-direction-blocked (nullable initial), distractor-duplicating-answer-blocked (editor-only), phone-grouping-display-but-digits-stored, phone-paste-with-separators accepted, phone-too-short rejected, date-auto-advance (+ backspace-back), date-future rejected, date-pre-1900 rejected, date-30.02 rejected, edit-prefill (phone grouped, date split), no-save-on-invalid.

## Out of scope
- `hint` column UI (stays `''` default; no field in this issue).
- Type-switch-on-edit clearing semantics (keep #003 behavior; full spec deferred).
- Distractor auto-suggest/generator (lesson-time fallback in #006).
- Exercise gameplay (#005–#009), XP (#010), streak (#011), onboarding/copy deck (#012), images/lottie (#014).

## Dependencies
- Builds on #002 (`validation.dart`: `isValidPhoneAnswer`/`normalizePhone`, `isValidDateAnswer`, `validateDirection`/`validateChoices` for non-empty; duplicate-vs-answer stays editor-only, storage contracts unchanged) and #003 (`ItemEditorDialog` shell, arb scaffold, stable keys).
- Follows #015 (kit reuse). Intentional divergence from #009: the *editor* uses fast-typing 3-field input while the *exercise* uses a month-view calendar — creation vs. recall contexts.
- Needs #006 to consume `choices` (blank-tolerant).

## Notes
Assumption: phone = memorize numbers (own/family/emergency); date = memorize birthdays. Correct in this file if wrong.

## Verify
```powershell
flutter analyze        # must be clean (includes riverpod_lint)
dart format --output=none --set-exit-if-changed .  # must be clean
flutter test           # new item-editor widget tests + all existing green
```

## Summary (done 2026-10-11)
- Implemented: `ItemEditorDialog` per-type subforms in `lib/src/library/item_editor.dart` (vocab prompt/answer + required nullable-initial direction `SegmentedButton` + 3 optional distractors with editor-only duplicate-vs-answer check; phone `itemAnswerField` with `PhoneGroupingFormatter` display-only grouping; date calendar-styled card with locale-ordered day/month/year fields, auto-advance + backspace-back, composed ISO validated by `isValidDateAnswer` with `systemClockProvider` today); new pure helpers `lib/src/library/date_display.dart` (`formatDateForDisplay`, reused by #009) + `lib/src/library/phone_formatting.dart` (`groupPhoneForDisplay`, `PhoneGroupingFormatter`); arb keys (distractor/day/month/year labels + hints, `errorDuplicateChoice`, day/month/year part errors) mirrored in hand-written `app_localizations.dart`. `hint` never touched.
- Key facts for follow-ups: `SegmentedButton` needs `emptySelectionAllowed: true` for the nullable initial (else it asserts); pre-1900/future/impossible dates all surface `errorInvalidDate` (composed check runs even when a part field fails, alongside part errors); phone saves raw input, repo normalises; empty choices save as `null`.
- Tests: `test/library/item_editor_test.dart` (16 widget tests, bounded-pump harness) + `test/library/formatting_test.dart` (9 unit tests); `library_screen_test` future-date case migrated to the 3-field date UI.
- Verify: `flutter analyze` clean, `dart format` clean, `dart fix` clean, `flutter test` 121/121 pass.
- Toolchain note: fresh worktrees must seed `.dart_tool/hooks_runner/shared/` (sqlite3.dll download cache) from an existing checkout, else the sqlite3 hook fails on network/cert; `build/` + `.dart_tool/` stay gitignored.
