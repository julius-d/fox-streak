# Issue 003: Set library + CRUD UI (parents/teachers/learners create sets)

Status: open | Priority: P0 | Type: feature

## Goal
Anyone can create a set of question-answer pairs without an account.

## Duolingo reference
Duolingo has course creation tools; ours is simpler: user-generated decks like Quizlet, but with our 3 fixed types.

## Acceptance criteria
- [ ] Home library lists sets: title, item count, type icons (vocab/phone/date). No "last score" here — moved to #005/#012 (no per-set score query in #002).
- [ ] Create / rename / duplicate (`(copy)` suffix per `duplicateSet`) / delete set (delete with confirm dialog; cancel is a no-op)
- [ ] Add / edit / delete items inside a set (navigation shell + list/detail wiring in this issue; all item field widgets owned by #004 `ItemEditor`)
- [ ] Validation mirrors #002 / `validation.dart` exactly: trim-then-require non-empty prompt/answer; phone via `isValidPhoneAnswer` (normalize strip spaces/`-`/`/`/`(`/`)`/`.`/`+`, then `^[0-9]{3,15}$`, leading `0` kept); date via `isValidDateAnswer` (strict ISO `YYYY-MM-DD`, `1900-01-01..today` local); vocab requires `direction` (`deEn|enDe`), non-vocab must omit `direction`/`choices`
- [ ] New-set form captures: title (non-empty after trim), creator name as free text (non-empty after trim, max 50 chars, e.g. "Mama", "Ms. Smith"), optional description. See #002 follow-up: `created_by` enum (`parent|teacher|learner`) must be loosened to free text first.
- [ ] Teen-friendly: large tap targets (min 48dp), German + English UI strings. This issue adds the minimal `flutter_localizations` scaffold + `app_de/app_en.arb` for library/detail strings only; full copy deck + onboarding stays in #012.
- [ ] Empty state CTA ("Try demo set") triggers `SeedLoader` import (dependency: #002 seed files, real content: #013); loading/error states shown, picker-cancel equivalent is a no-op. Onboarding slides stay in #012.
- [ ] Library watches `watchAllSets`; counts/icons via `watchItemsForSet` (or a count provider); fixed icon map for vocab/phone/date. Riverpod providers from #002 (`setsRepositoryProvider`, `appDatabaseProvider`) are the only data access.

## Tasks
1. Screens with fixed roles: `LibraryScreen` (list + FAB), `SetDetailScreen` (item list + overflow menu, no field editing), `SetEditorScreen` (edits set title/description/creator only, not items).
2. FAB "New set" -> title + creator free-text field + optional description. Sets are untyped containers; each item picks one of the 3 types at add-time via #004 `ItemEditor`. No per-set type field.
3. Empty states + sample CTA wired to `SeedLoader` (`seedLoaderProvider`); specify loading/error states.
4. Widget tests (pump `LibraryScreen` with `NativeDatabase.memory()` override + `FakeClock` from `test/data/test_helpers.dart`): create-valid, create-empty-title-blocked, rename, duplicate (`(copy)`), delete-confirm/cancel, paste-with-separators phone, future-date rejected.
5. Set-detail overflow menu: Share (via `share_plus`) + Import (via `file_picker` + `importSetFromJson` from #002), `.foxstreak.json` filename. Verifiable export-warning criteria (real-number dialog, `SetImportException` snackbar, picker-cancel) are owned and tested in #008 — this issue only wires the buttons/dialog hook.
6. i18n scaffold: add `flutter_localizations` + `intl`, `l10n.yaml`, DE/EN arb files, wire `localizationsDelegates`/`supportedLocales` in `main.dart`.
7. Delete-with-confirm implementation + test (was AC-only before).

## Out of scope
Exercise gameplay itself (see #005-#009), XP display/scoring (#010), item images/animations (#014 — text-only `prompt`/`answer` rendering in v1, no image columns/widgets), full i18n copy deck + onboarding (#012).
