// Shared on-device harness for the four critical-flow specs (issue #016).
//
// Every flow spec boots the real `FoxStreakApp` (not a bare screen) under an
// isolated in-memory DB + overridable `Clock` — never the real `fox_streak`
// on-device database — with no network access anywhere in the flows.
//
// Stable finder keys this harness relies on (see each screen for the full
// list; this is the cross-flow subset):
// - Library: `newSetFab`, `setTile-<id>` (row, no longer a tap target —
//   #042), `playSet-<id>` (opens `LessonScreen` directly), `editSet-<id>`
//   (opens `SetDetailScreen`), `setMenu-<id>` (rename/duplicate/delete),
//   `tryDemoSetButton`.
// - Set editor: `titleField`, `creatorField`, `descriptionField`,
//   `saveSetButton`; delete confirm: `confirmDeleteSetButton`.
// - Set detail: `addItemFab`, `startLessonFab`, `setOverflowMenu`
//   (share/import), `itemTile-<id>`, `editItem-<id>`, `deleteItem-<id>`.
// - Item editor: `itemTypeField`, `itemPromptField`, `itemAnswerField`
//   (shared by choice/freeText/phone), `itemDayField`/`itemMonthField`/
//   `itemYearField`, `saveItemButton`.
// - Lesson shell: `lessonProgressBar`, `lessonOverflowMenu`
//   (`quitLessonMenuItem`/`skipItemMenuItem`), `checkButton` (CHECK then
//   CONTINUE, same key), `lessonFeedbackBanner`, `lessonResultScreen`,
//   `practiceAgainButton`, `backToLibraryButton`.
// - Exercise cards: `choiceOption0`..`3`, `freeTextAnswerField`,
//   `dialPadKey<digit|backspace>`, `dateExerciseDayField`/`...MonthField`/
//   `...YearField`.
// - Result widgets: `xpEarnedLabel`, `xpBonusCallout`, `levelProgressBar`,
//   `streakBadge`, `streakCountLabel`.
//
// Native `share_plus` / `file_picker` calls are stubbed at the platform
// (`SharePlatform`/`FilePickerPlatform`) level in the share-round-trip flow
// only — no real share sheet or file dialog ever opens in these tests.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/main.dart';
import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/lesson/lesson_screen.dart';
import 'package:fox_streak_app/src/mascot/mascot_catalog.dart';
import 'package:fox_streak_app/src/stats/mascot_service.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

export 'package:fox_streak_app/test/data/test_helpers.dart' show FakeClock;

/// Isolated in-memory DB for a single test — never the real on-device file.
AppDatabase makeIntegrationTestDb() =>
    AppDatabase.forTesting(NativeDatabase.memory());

/// Bounded settle for screens backed by a Drift `watch()` stream (Library,
/// Set detail): raw `pumpAndSettle()` can spin for minutes on these (see
/// `test/library/library_screen_test.dart`'s own `settle()` — same root
/// cause). On a real device/desktop run there's a second, opposite risk:
/// the DB write and the stream's UI-rebuild notification aren't on the same
/// event-loop tick, so a single "no frame scheduled right now" reading can
/// fire *before* the delayed notification arrives, reporting settled one
/// beat too early. Requiring 3 consecutive clean pumps (not just one)
/// absorbs that gap without reintroducing an unbounded spin.
Future<void> settle(WidgetTester tester, {int cap = 150}) async {
  var cleanStreak = 0;
  for (var i = 0; i < cap; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.binding.hasScheduledFrame) {
      cleanStreak = 0;
    } else {
      cleanStreak++;
      if (cleanStreak >= 3) return;
    }
  }
  fail('UI did not settle after $cap frames');
}

/// Boots the real `FoxStreakApp` with [db]/[clock] overridden, then settles.
///
/// Every flow spec uses this (not a bare screen pump) so the harness proves
/// the real app wiring — navigation, providers, l10n — not just one widget.
///
/// [mascotCatalogLoader], if given, overrides #059's
/// `mascotCatalogLoaderProvider` — for a flow that completes several
/// same-day lessons and doesn't care about mascots, so the lootbox
/// trigger never touches the real asset bundle (a disconnected `Future`
/// the widget-test pump loop has no scheduled frame to wait on, which can
/// leave a dangling platform-channel timer at teardown).
Future<void> pumpFoxStreakApp(
  WidgetTester tester, {
  required AppDatabase db,
  required Clock clock,
  Future<List<MascotEntry>> Function()? mascotCatalogLoader,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
        if (mascotCatalogLoader != null)
          mascotCatalogLoaderProvider.overrideWithValue(mascotCatalogLoader),
      ],
      child: const FoxStreakApp(),
    ),
  );
  await settle(tester);
}

/// Finds the `ListTile` (set row or item row) whose visible text is [text].
///
/// `MaterialPageRoute`/`DialogRoute` default to `maintainState: true`, so a
/// just-popped editor's `TextFormField` with the same text can still be
/// mounted (off-stage) when the next assertion runs — a bare `find.text`
/// then matches both it and the real row, failing with "too many". Scoping
/// to `ListTile` descendants excludes that stale editor text entirely.
///
/// `test/library/set_detail_screen_test.dart` carries its own copy of this
/// (widget tests under `test/` can't depend on `integration_test/`) — keep
/// both in sync if this logic changes.
Finder listTileWithText(String text) {
  final textInTile = find.descendant(
    of: find.byType(ListTile),
    matching: find.text(text),
  );
  return find.ancestor(of: textInTile, matching: find.byType(ListTile));
}

/// Finds the edit icon button for the Library set row titled [title], which
/// opens `SetDetailScreen` — the row itself is no longer a tap target
/// (issue #042).
Finder editSetButton(String title) => find.descendant(
  of: listTileWithText(title),
  matching: find.byIcon(Icons.edit),
);

/// Finds the play icon button for the Library set row titled [title], which
/// jumps straight into `LessonScreen`, skipping `SetDetailScreen` (#042).
Finder playSetButton(String title) => find.descendant(
  of: listTileWithText(title),
  matching: find.byIcon(Icons.play_arrow),
);

/// Boots the real `LessonScreen` directly (no Home/Library navigation),
/// for flows that only care about lesson play-through/XP/streak.
///
/// Callers that pump more than one lesson in the same test (e.g. flow 3's
/// day-1/day-1-replay/day-2 sequence) *must* vary [items] between calls:
/// repeated `pumpWidget` calls reconcile a same-type, unkeyed `LessonScreen`
/// as an *update* of the existing element rather than a fresh mount, so
/// `initState`'s `controller.start()` would never re-run and the screen
/// would keep showing the previous lesson's already-`done` state. Keying on
/// the item ids forces a real remount each time.
///
/// [mascotCatalogLoader] — see `pumpFoxStreakApp`'s doc for why a flow
/// that completes several same-day lessons without caring about mascots
/// should pass one here.
Future<void> pumpLessonScreen(
  WidgetTester tester, {
  required AppDatabase db,
  required Clock clock,
  required int setId,
  required List<Item> items,
  Future<List<MascotEntry>> Function()? mascotCatalogLoader,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
        if (mascotCatalogLoader != null)
          mascotCatalogLoaderProvider.overrideWithValue(mascotCatalogLoader),
      ],
      child: MaterialApp(
        theme: FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LessonScreen(
          key: ValueKey(items.map((item) => item.id).join(',')),
          setId: setId,
          items: items,
        ),
      ),
    ),
  );
  await settle(tester);
}

/// Fresh installs land on first-run onboarding (#012); skips it and opens
/// the real `LibraryScreen` via Home's "Browse sets" button, for flows that
/// only care about the library, not onboarding itself.
Future<void> skipOnboardingAndOpenLibrary(WidgetTester tester) async {
  final skip = find.byKey(const Key('onboardingSkipButton'));
  if (skip.evaluate().isNotEmpty) {
    await tester.tap(skip);
    await settle(tester);
  }
  await tester.tap(find.byKey(const Key('homeBrowseSetsButton')));
  await settle(tester);
}
