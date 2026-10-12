# Issue 024: Move lesson Quit/Skip into a 3-dot overflow menu

Status: open | Priority: P2 | Type: UX | Refined-at: 2026-10-12

## Goal
The Skip button on the lesson card currently renders as a full-width `FoxSecondaryButton` stacked directly under the primary CHECK button (`lesson_screen.dart`) — same width and visual weight as the main CTA, so it reads as a second, near-equal action rather than an escape hatch. Replace the AppBar's standalone quit-X icon and the stacked Skip button with a single 3-dot overflow menu (reusing the `PopupMenuButton` pattern already used in `set_detail_screen.dart`/`library_screen.dart`), containing "Quit lesson" and, pre-check only, "Skip".

## Decisions (2026-10-12, with repo owner)
- Both actions move into one `PopupMenuButton` in the lesson `AppBar.actions`, replacing the current standalone quit-X `IconButton`. The stacked `FoxSecondaryButton` Skip is removed from the bottom button column entirely.
- The menu itself is **always visible** during the lesson (never hidden), since Quit must stay reachable pre- and post-check per #005's "no dead-ends" rule. Only the **"Skip" item** is conditionally included: present while `phase == answering`, omitted from `itemBuilder`'s list once `phase == feedback` (post-check) — mirrors today's `if (!isFeedback)` guard, just applied to the menu item instead of the button.
- Tapping "Skip" in the menu skips immediately (calls `controller.skip()`), no added confirmation dialog — same behavior as today, only the entry point moves. Tapping "Quit lesson" keeps the existing `FoxConfirmDialog` confirm step (`confirmQuitLessonButton`), unchanged.
- The result screen's own back/quit handling (no confirm, nothing left to lose per #005) is untouched — this issue only affects the AppBar during the `answering`/`feedback` phases, not `LessonResultScreen`.

## Acceptance criteria
- [ ] `lesson_screen.dart` AppBar: standalone quit-X `IconButton` (`:162-167`) replaced with `PopupMenuButton<String>` (new key `lessonOverflowMenu`, `tooltip: l10n.lessonActions`), `onSelected` switching on `'quit'` → `handleBack()`, `'skip'` → `controller.skip()`.
- [ ] `itemBuilder` always includes `PopupMenuItem(value: 'quit', key: Key('quitLessonMenuItem'), child: Text(l10n.lessonQuit))`; includes `PopupMenuItem(value: 'skip', key: Key('skipItemMenuItem'), child: Text(l10n.lessonSkip))` only when `state.phase == LessonPhase.answering`.
- [ ] Bottom button column (`:236-264`) loses the stacked Skip `FoxSecondaryButton` entirely; only the `FoxCheckButton` remains there.
- [ ] `app_en.arb` / `app_de.arb`: add `lessonActions` tooltip string (DE + EN), modeled on the existing `setActions` entry. Reuse existing `lessonQuit` / `lessonSkip` strings as the menu item labels — no new copy needed for those.
- [ ] Stable keys for #016 (e2e harness): `quitLessonButton` and `skipItemButton` keys are retired (no longer rendered as standalone buttons); replaced by `lessonOverflowMenu` (opens the menu) + `quitLessonMenuItem` / `skipItemMenuItem` (select the action). `confirmQuitLessonButton` is unchanged. Any existing widget/e2e test driving the old keys is updated to open the menu first.
- [ ] a11y: `PopupMenuButton`'s default icon-button touch target (48dp) satisfies the kit floor without extra work; `tooltip` provides the screen-reader label for the trigger, menu item `Text` provides labels for each entry — no new `Semantics` needed beyond what `PopupMenuButton`/`PopupMenuItem` already provide.
- [ ] Existing lesson shell tests (`test/lesson/lesson_shell_test.dart`) updated: `skip-counts-wrong` and `quit-confirm-*` cases now open `lessonOverflowMenu` before tapping `skipItemMenuItem` / `quitLessonMenuItem`; add a case asserting `skipItemMenuItem` is absent from the menu once `phase == feedback`.
- [ ] `flutter analyze` clean, `dart format` clean, `flutter test` green.

## Tasks
1. `lesson_screen.dart`: replace the quit-X `IconButton` with a `PopupMenuButton<String>` per the Decisions above; remove the stacked Skip button from `_buildLessonBody`.
2. `app_en.arb` / `app_de.arb`: add `lessonActions` tooltip key; no changes needed to `lessonQuit`/`lessonSkip` (reused as-is).
3. Update `test/lesson/lesson_shell_test.dart`: adapt existing skip/quit test flows to go through the new menu; add the post-check "Skip absent from menu" case.
4. Grep the repo for the retired `quitLessonButton` / `skipItemButton` keys (any other test or doc reference) and update to the new keys.

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
