// Widget tests for the set detail screen's floating actions (issue #042).
//
// Pumps `SetDetailScreen` with an in-memory DB + `FakeClock` override.
// Covers: both FABs stay visible without scrolling through a long item
// list, "Start lesson" shows the empty-set snackbar instead of navigating
// when the set has no items, and navigates to `LessonScreen` when it does.
//
// NOTE on pumping: do NOT use `pumpAndSettle()` here — same drift `watch()`
// fake-async caveat as `library_screen_test.dart`'s own `settle()`.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/lesson/lesson_screen.dart';
import 'package:fox_streak_app/src/library/set_detail_screen.dart';
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

Future<void> pumpSetDetail(
  WidgetTester tester,
  AppDatabase db,
  FakeClock clock,
  int setId, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
      ],
      child: MaterialApp(
        locale: locale,
        theme: FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SetDetailScreen(setId: setId),
      ),
    ),
  );
  await settle(tester);
}

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets(
    'both FABs stay visible without scrolling, even with a long item list',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());
      final repo = SetsRepository(db, clock);
      final setId = await repo.createSet(title: 'Many', createdBy: 'Mama');
      for (var i = 0; i < 30; i++) {
        await repo.addItem(
          setId: setId,
          type: 'choice',
          prompt: 'Q$i',
          answer: 'A$i',
        );
      }

      await pumpSetDetail(tester, db, clock, setId);

      expect(find.byKey(const Key('addItemFab')), findsOneWidget);
      expect(find.byKey(const Key('startLessonFab')), findsOneWidget);

      // Scroll the item list; the FABs float outside the scroll view.
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await settle(tester);

      expect(find.byKey(const Key('addItemFab')), findsOneWidget);
      expect(find.byKey(const Key('startLessonFab')), findsOneWidget);

      await unmount(tester);
    },
  );

  testWidgets(
    '"Start lesson" shows the empty-set snackbar instead of navigating '
    'when the set has no items',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());
      final repo = SetsRepository(db, clock);
      final setId = await repo.createSet(title: 'Empty', createdBy: 'Mama');

      await pumpSetDetail(tester, db, clock, setId);

      expect(find.byKey(const Key('startLessonFab')), findsOneWidget);

      await tester.tap(find.byKey(const Key('startLessonFab')));
      await settle(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(l10n.lessonEmptySetNote),
        ),
        findsOneWidget,
      );
      expect(find.byType(LessonScreen), findsNothing);

      await unmount(tester);
    },
  );

  testWidgets(
    '"Start lesson" navigates to LessonScreen when the set has items',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());
      final repo = SetsRepository(db, clock);
      final setId = await repo.createSet(title: 'Animals', createdBy: 'Mama');
      await repo.addItem(
        setId: setId,
        type: 'choice',
        prompt: 'Hund',
        answer: 'dog',
      );

      await pumpSetDetail(tester, db, clock, setId);

      await tester.tap(find.byKey(const Key('startLessonFab')));
      await settle(tester);

      expect(find.byType(LessonScreen), findsOneWidget);
      expect(find.byKey(const Key('setOverflowMenu')), findsNothing);

      await unmount(tester);
    },
  );

  testWidgets('a choice item in a math set shows the math category icon, not '
      'translate (#045)', (tester) async {
    final clock = FakeClock(kTestToday);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final repo = SetsRepository(db, clock);
    final setId = await repo.createSet(
      title: 'Facts',
      createdBy: 'Mama',
      category: 'math',
    );
    final itemId = await repo.addItem(
      setId: setId,
      type: 'choice',
      prompt: '2 × 3',
      answer: '6',
    );

    await pumpSetDetail(tester, db, clock, setId);

    final icon = tester.widget<Icon>(find.byKey(Key('itemTypeIcon-$itemId')));
    expect(icon.icon, Icons.calculate);
    expect(icon.icon, isNot(Icons.translate));

    await unmount(tester);
  });

  testWidgets(
    'date item subtitle shows locale-formatted date, not raw ISO '
    '(issue #049)',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());
      final repo = SetsRepository(db, clock);
      final setId = await repo.createSet(title: 'Birthdays', createdBy: 'Mama');
      final itemId = await repo.addItem(
        setId: setId,
        type: 'date',
        prompt: "Mama's birthday",
        answer: '1985-05-14',
      );

      await pumpSetDetail(
        tester,
        db,
        clock,
        setId,
        locale: const Locale('de'),
      );

      final subtitle = tester.widget<Text>(
        find
            .descendant(
              of: find.byKey(Key('itemTile-$itemId')),
              matching: find.byType(Text),
            )
            .at(1),
      );
      expect(subtitle.data, contains('14.05.1985'));
      expect(subtitle.data, isNot(contains('1985-05-14')));

      await unmount(tester);
    },
  );

  testWidgets(
    'phone item subtitle shows grouped digits, not raw unformatted '
    'digits (issue #049)',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());
      final repo = SetsRepository(db, clock);
      final setId = await repo.createSet(title: 'Contacts', createdBy: 'Mama');
      final itemId = await repo.addItem(
        setId: setId,
        type: 'phone',
        prompt: 'Oma',
        answer: '01711234567',
      );

      await pumpSetDetail(tester, db, clock, setId);

      final subtitle = tester.widget<Text>(
        find
            .descendant(
              of: find.byKey(Key('itemTile-$itemId')),
              matching: find.byType(Text),
            )
            .at(1),
      );
      expect(subtitle.data, contains('017 112 345 67'));
      expect(subtitle.data, isNot(contains('01711234567')));

      await unmount(tester);
    },
  );
}
