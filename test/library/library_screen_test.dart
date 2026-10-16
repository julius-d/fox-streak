// Widget tests for the set library (issue #003).
//
// Pumps `LibraryScreen` with an in-memory DB + `FakeClock` override.
// Covers: create-valid, create-empty-title-blocked, rename, duplicate
// (`(copy)`), delete-confirm/cancel, paste-with-separators phone,
// future-date rejected.
//
// NOTE on pumping: do NOT use `pumpAndSettle()` here. With drift `watch()`
// streams under fake async it was observed spinning for the full 10-minute
// timeout while identical bounded pumps settle in ~2 frames (bisect-5).
// `settle()` below caps the frames and fails loudly instead of hanging.
// Similarly, the pre-verify unmount must pump WITH a duration: disposing
// Riverpod stream subscriptions asks drift to close query streams via a
// zero-duration timer, and duration-less pumps never advance fake time far
// enough to flush it (`_unmount`).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/lesson/lesson_screen.dart';
import 'package:fox_streak_app/src/library/library_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

import '../data/test_helpers.dart';

/// Pumps frames until none are scheduled (or [cap] is hit, which fails).
Future<void> settle(WidgetTester tester, {int cap = 50}) async {
  for (var i = 0; i < cap; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) return;
  }
  fail('UI did not settle after $cap frames');
}

/// Unmounts the tree and flushes drift's stream-close timer so the fake-async
/// invariant check passes (see note above).
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<AppDatabase> pumpLibrary(WidgetTester tester, FakeClock clock) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
      ],
      child: MaterialApp(
        theme: FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LibraryScreen(),
      ),
    ),
  );
  await settle(tester);
  return db;
}

SetsRepository repoOf(AppDatabase db, FakeClock clock) =>
    SetsRepository(db, clock);

void main() {
  testWidgets('create-valid set appears in library', (tester) async {
    final clock = FakeClock(kTestToday);
    await pumpLibrary(tester, clock);

    // Empty state CTA is shown.
    expect(find.byKey(const Key('tryDemoSetButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('newSetFab')));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('titleField')), 'Animals');
    await tester.enterText(find.byKey(const Key('creatorField')), 'Mama');
    await tester.enterText(
      find.byKey(const Key('descriptionField')),
      'First set',
    );
    await tester.tap(find.byKey(const Key('saveSetButton')));
    await settle(tester);

    expect(find.text('Animals'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('create-empty-title-blocked shows error and saves nothing', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final db = await pumpLibrary(tester, clock);

    await tester.tap(find.byKey(const Key('newSetFab')));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('creatorField')), 'Mama');
    await tester.tap(find.byKey(const Key('saveSetButton')));
    await settle(tester);

    // Inline validation error, still on the editor.
    expect(find.text('This field is required'), findsOneWidget);
    expect(find.byKey(const Key('titleField')), findsOneWidget);

    // Nothing persisted.
    final sets = await db.select(db.questionSets).get();
    expect(sets, isEmpty);
    await unmount(tester);
  });

  testWidgets('rename updates the set title', (tester) async {
    final clock = FakeClock(kTestToday);
    final db = await pumpLibrary(tester, clock);
    final repo = repoOf(db, clock);
    final id = await repo.createSet(title: 'Orig', createdBy: 'Mama');
    await settle(tester);

    await tester.tap(find.byKey(Key('setMenu-$id')));
    await settle(tester);
    await tester.tap(find.text('Rename'));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('titleField')), 'Renamed');
    await tester.tap(find.byKey(const Key('saveSetButton')));
    await settle(tester);

    expect(find.text('Renamed'), findsOneWidget);
    expect((await repo.getSetById(id))?.title, 'Renamed');
    await unmount(tester);
  });

  testWidgets('duplicate creates a "(copy)" set', (tester) async {
    final clock = FakeClock(kTestToday);
    final db = await pumpLibrary(tester, clock);
    final repo = repoOf(db, clock);
    final id = await repo.createSet(title: 'Orig', createdBy: 'Mama');
    await settle(tester);

    await tester.tap(find.byKey(Key('setMenu-$id')));
    await settle(tester);
    await tester.tap(find.text('Duplicate'));
    await settle(tester);

    expect(find.text('Orig (copy)'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('delete-cancel is a no-op, delete-confirm removes the set', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final db = await pumpLibrary(tester, clock);
    final repo = repoOf(db, clock);
    final id = await repo.createSet(title: 'Gone?', createdBy: 'Mama');
    await settle(tester);

    // Cancel path.
    await tester.tap(find.byKey(Key('setMenu-$id')));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(find.text('Delete set?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancelDeleteSetButton')));
    await settle(tester);
    expect(find.text('Gone?'), findsOneWidget);
    expect(await repo.getSetById(id), isNotNull);

    // Confirm path.
    await tester.tap(find.byKey(Key('setMenu-$id')));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirmDeleteSetButton')));
    await settle(tester);
    expect(find.text('Gone?'), findsNothing);
    expect(await repo.getSetById(id), isNull);
    await unmount(tester);
  });

  testWidgets('phone item with separators is stored normalised', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final db = await pumpLibrary(tester, clock);
    final repo = repoOf(db, clock);
    final id = await repo.createSet(title: 'Contacts', createdBy: 'Mama');
    await settle(tester);

    await tester.tap(find.byKey(Key('editSet-$id')));
    await settle(tester);

    await tester.tap(find.byKey(const Key('addItemFab')));
    await settle(tester);

    // Pick the phone type.
    await tester.tap(find.byKey(const Key('itemTypeField')));
    await settle(tester);
    await tester.tap(find.text('Phone').last);
    await settle(tester);

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Mama');
    await tester.enterText(
      find.byKey(const Key('itemAnswerField')),
      '0171 123-4567',
    );
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    // Stored digits-only.
    final items = await repo.getItemsForSet(id);
    expect(items, hasLength(1));
    expect(items.single.answer, '01711234567');
    expect(find.textContaining('01711234567'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('future-date item is rejected with inline error', (tester) async {
    final clock = FakeClock(kTestToday);
    final db = await pumpLibrary(tester, clock);
    final repo = repoOf(db, clock);
    final id = await repo.createSet(title: 'Birthdays', createdBy: 'Mama');
    await settle(tester);

    await tester.tap(find.byKey(Key('editSet-$id')));
    await settle(tester);

    await tester.tap(find.byKey(const Key('addItemFab')));
    await settle(tester);

    await tester.tap(find.byKey(const Key('itemTypeField')));
    await settle(tester);
    await tester.tap(find.text('Birthday').last);
    await settle(tester);

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Future');
    // New date editor (issue #004): 3 numeric fields, EN order month-day-year.
    await tester.enterText(find.byKey(const Key('itemMonthField')), '10');
    await tester.enterText(find.byKey(const Key('itemDayField')), '12');
    await tester.enterText(find.byKey(const Key('itemYearField')), '2026');
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    expect(find.text('Use YYYY-MM-DD (1900-01-01…today)'), findsOneWidget);
    expect(await repo.getItemsForSet(id), isEmpty);
    await unmount(tester);
  });

  testWidgets(
    'play icon shows the empty-set snackbar instead of navigating when the '
    'set has no items (issue #042)',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final db = await pumpLibrary(tester, clock);
      final repo = repoOf(db, clock);
      final id = await repo.createSet(title: 'Empty', createdBy: 'Mama');
      await settle(tester);

      await tester.tap(find.byKey(Key('playSet-$id')));
      await settle(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Add items to start practicing!'), findsOneWidget);
      expect(find.byType(LessonScreen), findsNothing);
      await unmount(tester);
    },
  );

  testWidgets(
    'play icon navigates straight to LessonScreen, skipping SetDetailScreen, '
    'when the set has items (issue #042)',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final db = await pumpLibrary(tester, clock);
      final repo = repoOf(db, clock);
      final id = await repo.createSet(title: 'Animals', createdBy: 'Mama');
      await repo.addItem(
        setId: id,
        type: 'choice',
        prompt: 'Hund',
        answer: 'dog',
      );
      await settle(tester);

      await tester.tap(find.byKey(Key('playSet-$id')));
      await settle(tester);

      expect(find.byType(LessonScreen), findsOneWidget);
      expect(find.byKey(const Key('setOverflowMenu')), findsNothing);
      await unmount(tester);
    },
  );
}
