// Widget tests for the set create/edit form's category picker (issue #045).
//
// Pumps `SetEditorScreen` with an in-memory DB + `FakeClock` override.
// Covers: new sets default to `vocab`, picking a category persists it on
// create, editing an existing set pre-fills the picker from
// `existing.category` (null -> vocab).
//
// NOTE on pumping: do NOT use `pumpAndSettle()` — same drift `watch()`
// fake-async caveat as `library_screen_test.dart`'s own `settle()`.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/library/set_editor_screen.dart';
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

Future<void> pumpEditor(
  WidgetTester tester,
  AppDatabase db,
  FakeClock clock, [
  QuestionSet? existing,
]) async {
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
        home: SetEditorScreen(existing: existing),
      ),
    ),
  );
  await settle(tester);
}

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('new set defaults to the vocab category segment selected', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    await pumpEditor(tester, db, clock);

    final segmented = tester.widget<SegmentedButton<String>>(
      find.byKey(const Key('categoryField')),
    );
    expect(segmented.selected, {'vocab'});

    await unmount(tester);
  });

  testWidgets('creating a set without touching the picker saves "vocab"', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final repo = SetsRepository(db, clock);

    await pumpEditor(tester, db, clock);

    await tester.enterText(find.byKey(const Key('titleField')), 'Birthdays');
    await tester.enterText(find.byKey(const Key('creatorField')), 'Mama');
    await tester.tap(find.byKey(const Key('saveSetButton')));
    await settle(tester);

    final sets = await repo.getAllSets();
    expect(sets.single.category, 'vocab');

    await unmount(tester);
  });

  testWidgets('picking "Math" before saving creates the set with that '
      'category', (tester) async {
    final clock = FakeClock(kTestToday);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final repo = SetsRepository(db, clock);

    await pumpEditor(tester, db, clock);

    await tester.enterText(find.byKey(const Key('titleField')), 'Facts');
    await tester.enterText(find.byKey(const Key('creatorField')), 'Mama');
    await tester.tap(find.byKey(const Key('categoryOption-math')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('saveSetButton')));
    await settle(tester);

    final sets = await repo.getAllSets();
    expect(sets.single.category, 'math');

    await unmount(tester);
  });

  testWidgets('editing a set pre-fills the picker from existing.category', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final repo = SetsRepository(db, clock);
    final setId = await repo.createSet(
      title: 'Capitals',
      createdBy: 'Mama',
      category: 'geography',
    );
    final existing = await repo.getSetById(setId);

    await pumpEditor(tester, db, clock, existing);

    final segmented = tester.widget<SegmentedButton<String>>(
      find.byKey(const Key('categoryField')),
    );
    expect(segmented.selected, {'geography'});

    await unmount(tester);
  });

  testWidgets(
    'editing a legacy set (category null) pre-fills the picker as vocab',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());
      final repo = SetsRepository(db, clock);
      final setId = await repo.createSet(title: 'Old', createdBy: 'Mama');
      final existing = await repo.getSetById(setId);
      expect(existing?.category, isNull);

      await pumpEditor(tester, db, clock, existing);

      final segmented = tester.widget<SegmentedButton<String>>(
        find.byKey(const Key('categoryField')),
      );
      expect(segmented.selected, {'vocab'});

      await unmount(tester);
    },
  );

  testWidgets('all 4 category labels are shown', (tester) async {
    final clock = FakeClock(kTestToday);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    await pumpEditor(tester, db, clock);

    expect(find.text(l10n.categoryVocab), findsOneWidget);
    expect(find.text(l10n.categoryMath), findsOneWidget);
    expect(find.text(l10n.categoryGeography), findsOneWidget);
    expect(find.text(l10n.categoryGeneral), findsOneWidget);

    await unmount(tester);
  });
}
