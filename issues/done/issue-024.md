# Issue 024: Move lesson Quit/Skip into a 3-dot overflow menu

Status: done | Priority: P2 | Type: UX | Refined-at: 2026-10-12

## Goal
The Skip button on the lesson card currently renders as a full-width `FoxSecondaryButton` stacked directly under the primary CHECK button (`lesson_screen.dart`) — same width and visual weight as the main CTA, so it reads as a second, near-equal action rather than an escape hatch. Replace the AppBar's standalone quit-X icon and the stacked Skip button with a single 3-dot overflow menu (reusing the `PopupMenuButton` pattern already used in `set_detail_screen.dart`/`library_screen.dart`), containing "Quit lesson" and, pre-check only, "Skip".

## Decisions (2026-10-12, with repo owner)
- Both actions move into one `PopupMenuButton` in the lesson `AppBar.actions`, replacing the current standalone quit-X `IconButton`. The stacked `FoxSecondaryButton` Skip is removed from the bottom button column entirely.
- The menu itself is **always visible** during the lesson (never hidden), since Quit must stay reachable pre- and post-check per #005's "no dead-ends" rule. Only the **"Skip" item** is conditionally included: present while `phase == answering`, omitted from `itemBuilder`'s list once `phase == feedback` (post-check) — mirrors today's `if (!isFeedback)` guard, just applied to the menu item instead of the button.
- Tapping "Skip" in the menu skips immediately (calls `controller.skip()`), no added confirmation dialog — same behavior as today, only the entry point moves. Tapping "Quit lesson" keeps the existing `FoxConfirmDialog` confirm step (`confirmQuitLessonButton`), unchanged.
- The result screen's own back/quit handling (no confirm, nothing left to lose per #005) is untouched — this issue only affects the AppBar during the `answering`/`feedback` phases, not `LessonResultScreen`.

## Acceptance criteria
- [x] `lesson_screen.dart` AppBar: standalone quit-X `IconButton` (`:162-167`) replaced with `PopupMenuButton<String>` (new key `lessonOverflowMenu`, `tooltip: l10n.lessonActions`), `onSelected` switching on `'quit'` → `handleBack()`, `'skip'` → `controller.skip()`.
- [x] `itemBuilder` always includes `PopupMenuItem(value: 'quit', key: Key('quitLessonMenuItem'), child: Text(l10n.lessonQuit))`; includes `PopupMenuItem(value: 'skip', key: Key('skipItemMenuItem'), child: Text(l10n.lessonSkip))` only when `state.phase == LessonPhase.answering`.
- [x] Bottom button column (`:236-264`) loses the stacked Skip `FoxSecondaryButton` entirely; only the `FoxCheckButton` remains there.
- [x] `app_en.arb` / `app_de.arb`: add `lessonActions` tooltip string (DE + EN), modeled on the existing `setActions` entry. Reuse existing `lessonQuit` / `lessonSkip` strings as the menu item labels — no new copy needed for those.
- [x] Stable keys for #016 (e2e harness): `quitLessonButton` and `skipItemButton` keys are retired (no longer rendered as standalone buttons); replaced by `lessonOverflowMenu` (opens the menu) + `quitLessonMenuItem` / `skipItemMenuItem` (select the action). `confirmQuitLessonButton` is unchanged. Any existing widget/e2e test driving the old keys is updated to open the menu first.
- [x] a11y: `PopupMenuButton`'s default icon-button touch target (48dp) satisfies the kit floor without extra work; `tooltip` provides the screen-reader label for the trigger, menu item `Text` provides labels for each entry — no new `Semantics` needed beyond what `PopupMenuButton`/`PopupMenuItem` already provide.
- [x] Existing lesson shell tests (`test/lesson/lesson_shell_test.dart`) updated: `skip-counts-wrong` and `quit-confirm-*` cases now open `lessonOverflowMenu` before tapping `skipItemMenuItem` / `quitLessonMenuItem`; add a case asserting `skipItemMenuItem` is absent from the menu once `phase == feedback`.
- [x] `flutter analyze` clean, `dart format` clean, `flutter test` green.

## Tasks
1. ~~`lesson_screen.dart`: replace the quit-X `IconButton` with a `PopupMenuButton<String>` per the Decisions above; remove the stacked Skip button from `_buildLessonBody`.~~ Done.
2. ~~`app_en.arb` / `app_de.arb`: add `lessonActions` tooltip key; no changes needed to `lessonQuit`/`lessonSkip` (reused as-is).~~ Done.
3. ~~Update `test/lesson/lesson_shell_test.dart`: adapt existing skip/quit test flows to go through the new menu; add the post-check "Skip absent from menu" case.~~ Done.
4. ~~Grep the repo for the retired `quitLessonButton` / `skipItemButton` keys (any other test or doc reference) and update to the new keys.~~ Done (only `test/lesson/lesson_shell_test.dart` referenced them; `issues/issue-005.md`'s historical AC text is left as-is, describing what was true when #005 shipped).

## Out of scope
- Any change to `controller.skip()` / `controller.handleBack()` / `recordAttempt` semantics — skip still counts as wrong, quit still discards unanswered progress. This issue is placement-only.
- Adding a confirm step to Skip (explicitly rejected — keeps it low-friction).
- `LessonResultScreen`'s back/quit handling — unaffected.
- Any other screen's AppBar — this issue only touches `LessonScreen`.

## Dependencies
- Builds on #005 (lesson shell contract, "no dead-ends" quit rule, stable-key list) and #015 (kit reuse — `PopupMenuButton` pattern already established in #004's `set_detail_screen.dart`/`library_screen.dart`).
- Touches #016's e2e harness key list (`quitLessonButton`/`skipItemButton` retired in favor of `lessonOverflowMenu` + menu-item keys) — coordinate if #016 is in flight.

## Verify
```powershell
flutter analyze        # must be clean (includes riverpod_lint)
dart format --output=none --set-exit-if-changed .  # must be clean
flutter test            # updated lesson-shell tests + all existing green
```

## Summary (done, 2026-10-13)
- `lesson_screen.dart`: AppBar quit-X → `PopupMenuButton` (`lessonOverflowMenu`); Skip item conditional on `phase == answering`; stacked `FoxSecondaryButton` Skip removed from `_buildLessonBody`.
- Added `lessonActions` l10n key (DE/EN) to both the `.arb` files and the hand-written `lib/l10n/app_localizations.dart` delegate (this repo has no working `flutter gen-l10n`, see `lib/l10n/README.md`).
- `test/lesson/lesson_shell_test.dart` updated to drive quit/skip through the menu; added `skip-absent-from-menu-post-check`. New `integration_test/lesson_overflow_menu_test.dart` drives the real `MultipleChoiceCard` end-to-end (no placeholder).
- Bug found + fixed while writing the integration test (pre-existing, unrelated to this issue, small fix so applied directly): `_buildExerciseCard` never keyed its exercise cards by `item.id`, so Flutter reused the same `State` across different items of the same type — `MultipleChoiceCard`'s shuffled options are cached in `initState`, so the second question in any same-type lesson silently showed the *previous* item's answer choices. Fixed by keying each card (`vocab`/`phone`/`date`/placeholder, and the test-only `cardBuilder` path) with `ValueKey(item.id)`; `buildDialPadExercise`/`buildDateExercise`/`LessonScreen.cardBuilder` now accept an optional `key`. Added a `flutter test`-gated regression widget test (`real vocab cards get fresh per-item state`) alongside the integration test, since the integration test alone isn't part of the normal fast gate.
- Post-review fix: both the new widget test and the integration test initially assumed `items[0]` renders first, but `LessonController.start()` shuffles the queue — this was the real cause of what looked like macOS integration-test flakiness while developing. Both tests now determine which item renders first dynamically instead of assuming insertion order.
- All 168 widget tests + the integration test pass reliably (verified across repeated runs); `flutter analyze`, `dart format`, `dart fix --dry-run` clean.
