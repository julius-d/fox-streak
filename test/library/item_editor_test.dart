// Widget tests for the per-type item editors (issue #004).
//
// Pumps `ItemEditorDialog` through a harness button with an in-memory DB +
// `FakeClock` overrides. Covers: vocab-valid with 3 distractors,
// vocab-missing-direction-blocked (nullable initial),
// distractor-duplicating-answer-blocked (editor-only),
// phone-grouping-display-but-digits-stored, phone-paste-with-separators,
// phone-too-short rejected, date-auto-advance (+ backspace-back),
// date-future / pre-1900 / 30.02 rejected, edit-prefill (phone grouped,
// date split, vocab choices kept), no-save-on-invalid.
//
// Pumping note (from #003): never use `pumpAndSettle()` with drift `watch()`
// streams under fake async — use bounded 100ms pumps capped at 50 (`settle`).
// Pre-verify unmount must pump WITH a duration (`unmount`).

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/library/item_editor.dart';
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
/// invariant check passes.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

class _EditorHarness extends StatelessWidget {
  final int setId;
  final Item? existing;

  const _EditorHarness({required this.setId, this.existing});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          key: const Key('openEditorButton'),
          onPressed: () => showDialog<bool>(
            context: context,
            builder: (_) => ItemEditorDialog(setId: setId, existing: existing),
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}

Future<({AppDatabase db, SetsRepository repo, int setId})> pumpEditor(
  WidgetTester tester,
  FakeClock clock, {
  Item? existing,
  Locale locale = const Locale('en'),
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
  final repo = SetsRepository(db, clock);
  final setId = await repo.createSet(title: 'Test', createdBy: 'Mama');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
        setsRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        locale: locale,
        theme: FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _EditorHarness(setId: setId, existing: existing),
      ),
    ),
  );
  await settle(tester);
  await tester.tap(find.byKey(const Key('openEditorButton')));
  await settle(tester);
  return (db: db, repo: repo, setId: setId);
}

Future<void> switchType(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('itemTypeField')));
  await settle(tester);
  await tester.tap(find.text(label).last);
  await settle(tester);
}

String? focusedDateLabel(WidgetTester tester) =>
    tester.binding.focusManager.primaryFocus?.debugLabel;

bool hasFocus(WidgetTester tester, String key) =>
    focusedDateLabel(tester) ==
    switch (key) {
      'itemDayField' => 'itemDay',
      'itemMonthField' => 'itemMonth',
      'itemYearField' => 'itemYear',
      _ => key,
    };

void main() {
  testWidgets('vocab-valid with 3 distractors saves direction and choices', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final env = await pumpEditor(tester, clock);

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Hund');
    await tester.enterText(find.byKey(const Key('itemAnswerField')), 'dog');
    await tester.tap(find.text('German → English'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('itemChoice0Field')), 'cat');
    await tester.enterText(find.byKey(const Key('itemChoice1Field')), 'mouse');
    await tester.enterText(find.byKey(const Key('itemChoice2Field')), 'bird');
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    final items = await env.repo.getItemsForSet(env.setId);
    expect(items, hasLength(1));
    expect(items.single.direction, 'deEn');
    expect((jsonDecode(items.single.choices!) as List).cast<String>(), [
      'cat',
      'mouse',
      'bird',
    ]);
    await unmount(tester);
  });

  testWidgets('vocab-missing-direction-blocked starts with nothing selected', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final env = await pumpEditor(tester, clock);

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Hund');
    await tester.enterText(find.byKey(const Key('itemAnswerField')), 'dog');

    // Nullable initial: no segment pre-selected, inline error until picked.
    expect(
      tester
          .widget<SegmentedButton<String>>(
            find.byKey(const Key('itemDirectionField')),
          )
          .selected,
      isEmpty,
    );
    expect(find.text('Pick a direction'), findsOneWidget);

    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    expect(find.text('Pick a direction'), findsOneWidget);
    expect(await env.repo.getItemsForSet(env.setId), isEmpty);
    expect(find.byKey(const Key('itemPromptField')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('distractor-duplicating-answer-blocked is editor-only', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final env = await pumpEditor(tester, clock);

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Hund');
    await tester.enterText(find.byKey(const Key('itemAnswerField')), 'dog');
    await tester.tap(find.text('German → English'));
    await settle(tester);
    // Trim/case-insensitive duplicate of the answer.
    await tester.enterText(find.byKey(const Key('itemChoice0Field')), ' Dog ');
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    expect(find.text('Must be different from the answer'), findsOneWidget);
    expect(await env.repo.getItemsForSet(env.setId), isEmpty);
    await unmount(tester);
  });

  testWidgets('phone-grouping-display-but-digits-stored', (tester) async {
    final clock = FakeClock(kTestToday);
    final env = await pumpEditor(tester, clock);
    await switchType(tester, 'Phone');

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Mama');
    await tester.enterText(
      find.byKey(const Key('itemAnswerField')),
      '01711234567',
    );
    await settle(tester);

    final shown = tester
        .widget<TextFormField>(find.byKey(const Key('itemAnswerField')))
        .controller!
        .text;
    expect(shown.contains(' '), isTrue);
    expect(shown.replaceAll(' ', ''), '01711234567');

    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    final items = await env.repo.getItemsForSet(env.setId);
    expect(items, hasLength(1));
    expect(items.single.answer, '01711234567');
    await unmount(tester);
  });

  testWidgets('phone-paste-with-separators accepted', (tester) async {
    final clock = FakeClock(kTestToday);
    final env = await pumpEditor(tester, clock);
    await switchType(tester, 'Phone');

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Mama');
    await tester.enterText(
      find.byKey(const Key('itemAnswerField')),
      '0171 123-4567',
    );
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    final items = await env.repo.getItemsForSet(env.setId);
    expect(items, hasLength(1));
    expect(items.single.answer, '01711234567');
    await unmount(tester);
  });

  testWidgets('phone-too-short rejected', (tester) async {
    final clock = FakeClock(kTestToday);
    final env = await pumpEditor(tester, clock);
    await switchType(tester, 'Phone');

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Mama');
    await tester.enterText(find.byKey(const Key('itemAnswerField')), '12');
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    expect(find.text('Enter 3–15 digits'), findsOneWidget);
    expect(await env.repo.getItemsForSet(env.setId), isEmpty);
    await unmount(tester);
  });

  testWidgets('phone-letters rejected with invalid-phone error', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final env = await pumpEditor(tester, clock);
    await switchType(tester, 'Phone');

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Mama');
    await tester.enterText(find.byKey(const Key('itemAnswerField')), 'abc');
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    expect(find.text('Enter 3–15 digits'), findsOneWidget);
    expect(await env.repo.getItemsForSet(env.setId), isEmpty);
    await unmount(tester);
  });

  testWidgets('date-auto-advance and backspace-back (EN month first)', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    await pumpEditor(tester, clock);
    await switchType(tester, 'Birthday');

    await tester.enterText(find.byKey(const Key('itemMonthField')), '05');
    await settle(tester);
    expect(hasFocus(tester, 'itemDayField'), isTrue);

    // Backspace on the empty day field goes back to month.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await settle(tester);
    expect(hasFocus(tester, 'itemMonthField'), isTrue);
    await unmount(tester);
  });

  testWidgets('date-auto-advance day first in DE locale', (tester) async {
    final clock = FakeClock(kTestToday);
    await pumpEditor(tester, clock, locale: const Locale('de'));
    await switchType(tester, 'Geburtstag');

    // Locale-aware order: day before month before year.
    final dayX = tester.getCenter(find.byKey(const Key('itemDayField'))).dx;
    final monthX = tester.getCenter(find.byKey(const Key('itemMonthField'))).dx;
    final yearX = tester.getCenter(find.byKey(const Key('itemYearField'))).dx;
    expect(dayX, lessThan(monthX));
    expect(monthX, lessThan(yearX));

    await tester.enterText(find.byKey(const Key('itemDayField')), '14');
    await settle(tester);
    expect(hasFocus(tester, 'itemMonthField'), isTrue);
    await unmount(tester);
  });

  testWidgets('date EN order is month-day-year', (tester) async {
    final clock = FakeClock(kTestToday);
    await pumpEditor(tester, clock);
    await switchType(tester, 'Birthday');

    final dayX = tester.getCenter(find.byKey(const Key('itemDayField'))).dx;
    final monthX = tester.getCenter(find.byKey(const Key('itemMonthField'))).dx;
    final yearX = tester.getCenter(find.byKey(const Key('itemYearField'))).dx;
    expect(monthX, lessThan(dayX));
    expect(dayX, lessThan(yearX));
    await unmount(tester);
  });

  testWidgets('date-future rejected', (tester) async {
    final clock = FakeClock(kTestToday);
    final env = await pumpEditor(tester, clock);
    await switchType(tester, 'Birthday');

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Future');
    await tester.enterText(find.byKey(const Key('itemMonthField')), '10');
    await tester.enterText(find.byKey(const Key('itemDayField')), '12');
    await tester.enterText(find.byKey(const Key('itemYearField')), '2026');
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    expect(find.text('Use YYYY-MM-DD (1900-01-01…today)'), findsOneWidget);
    expect(await env.repo.getItemsForSet(env.setId), isEmpty);
    await unmount(tester);
  });

  testWidgets('date-pre-1900 rejected', (tester) async {
    final clock = FakeClock(kTestToday);
    final env = await pumpEditor(tester, clock);
    await switchType(tester, 'Birthday');

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Old');
    await tester.enterText(find.byKey(const Key('itemMonthField')), '12');
    await tester.enterText(find.byKey(const Key('itemDayField')), '31');
    await tester.enterText(find.byKey(const Key('itemYearField')), '1899');
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    expect(find.text('Use YYYY-MM-DD (1900-01-01…today)'), findsOneWidget);
    expect(await env.repo.getItemsForSet(env.setId), isEmpty);
    await unmount(tester);
  });

  testWidgets('date-30.02 rejected, fixing the day saves', (tester) async {
    final clock = FakeClock(kTestToday);
    final env = await pumpEditor(tester, clock);
    await switchType(tester, 'Birthday');

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Leap');
    await tester.enterText(find.byKey(const Key('itemMonthField')), '02');
    await tester.enterText(find.byKey(const Key('itemDayField')), '30');
    await tester.enterText(find.byKey(const Key('itemYearField')), '2020');
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    expect(find.text('Use YYYY-MM-DD (1900-01-01…today)'), findsOneWidget);
    expect(await env.repo.getItemsForSet(env.setId), isEmpty);

    await tester.enterText(find.byKey(const Key('itemDayField')), '28');
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    final items = await env.repo.getItemsForSet(env.setId);
    expect(items, hasLength(1));
    expect(items.single.answer, '2020-02-28');
    await unmount(tester);
  });

  testWidgets('edit-prefill shows grouped phone', (tester) async {
    final clock = FakeClock(kTestToday);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final repo = SetsRepository(db, clock);
    final setId = await repo.createSet(title: 'Test', createdBy: 'Mama');
    final itemId = await repo.addItem(
      setId: setId,
      type: 'phone',
      prompt: 'Mama',
      answer: '01711234567',
    );
    final existing = await repo.getItemById(itemId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          systemClockProvider.overrideWithValue(clock),
          setsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: FoxStreakTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _EditorHarness(setId: setId, existing: existing),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('openEditorButton')));
    await settle(tester);

    final shown = tester
        .widget<TextFormField>(find.byKey(const Key('itemAnswerField')))
        .controller!
        .text;
    expect(shown.replaceAll(' ', ''), '01711234567');
    expect(shown.contains(' '), isTrue);
    await unmount(tester);
  });

  testWidgets('edit-prefill splits stored ISO date', (tester) async {
    final clock = FakeClock(kTestToday);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final repo = SetsRepository(db, clock);
    final setId = await repo.createSet(title: 'Test', createdBy: 'Mama');
    final itemId = await repo.addItem(
      setId: setId,
      type: 'date',
      prompt: 'Mama',
      answer: '1985-05-14',
    );
    final existing = await repo.getItemById(itemId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          systemClockProvider.overrideWithValue(clock),
          setsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: FoxStreakTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _EditorHarness(setId: setId, existing: existing),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('openEditorButton')));
    await settle(tester);

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('itemDayField')))
          .controller!
          .text,
      '14',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('itemMonthField')))
          .controller!
          .text,
      '05',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('itemYearField')))
          .controller!
          .text,
      '1985',
    );
    // Locale-aware display preview (EN: MM/DD/YYYY).
    expect(find.text('05/14/1985'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('edit-prefill vocab keeps direction and choices', (tester) async {
    final clock = FakeClock(kTestToday);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final repo = SetsRepository(db, clock);
    final setId = await repo.createSet(title: 'Test', createdBy: 'Mama');
    final itemId = await repo.addItem(
      setId: setId,
      type: 'vocab',
      prompt: 'Hund',
      answer: 'dog',
      direction: 'enDe',
      choices: ['cat', 'mouse'],
    );
    final existing = await repo.getItemById(itemId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          systemClockProvider.overrideWithValue(clock),
          setsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: FoxStreakTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _EditorHarness(setId: setId, existing: existing),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('openEditorButton')));
    await settle(tester);

    expect(
      tester
          .widget<SegmentedButton<String>>(
            find.byKey(const Key('itemDirectionField')),
          )
          .selected,
      {'enDe'},
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('itemChoice0Field')))
          .controller!
          .text,
      'cat',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('itemChoice1Field')))
          .controller!
          .text,
      'mouse',
    );

    // Saving untouched preserves everything.
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);
    final updated = await repo.getItemById(itemId);
    expect(updated?.direction, 'enDe');
    expect((jsonDecode(updated!.choices!) as List).cast<String>(), [
      'cat',
      'mouse',
    ]);
    await unmount(tester);
  });

  testWidgets('edit with corrupt choices JSON opens with blank fields', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final repo = SetsRepository(db, clock);
    final setId = await repo.createSet(title: 'Test', createdBy: 'Mama');
    // Bypass the repository (which only writes validated JSON) to simulate
    // out-of-band corrupt data: valid JSON that is not a string list.
    final itemId = await db
        .into(db.items)
        .insert(
          ItemsCompanion.insert(
            setId: setId,
            type: 'vocab',
            prompt: 'Hund',
            answer: 'dog',
            direction: const Value('deEn'),
            choices: const Value('"not-a-list"'),
            position: 0,
          ),
        );
    final existing = await repo.getItemById(itemId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          systemClockProvider.overrideWithValue(clock),
          setsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: FoxStreakTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _EditorHarness(setId: setId, existing: existing),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('openEditorButton')));
    await settle(tester);

    // Dialog opens instead of crashing; distractor fields start blank.
    expect(find.byKey(const Key('itemChoice0Field')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('itemChoice0Field')))
          .controller!
          .text,
      isEmpty,
    );
    await unmount(tester);
  });

  testWidgets('no-save-on-invalid keeps the dialog open', (tester) async {
    final clock = FakeClock(kTestToday);
    final env = await pumpEditor(tester, clock);

    await tester.enterText(find.byKey(const Key('itemAnswerField')), 'dog');
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    expect(find.text('This field is required'), findsWidgets);
    expect(await env.repo.getItemsForSet(env.setId), isEmpty);
    expect(find.byKey(const Key('itemPromptField')), findsOneWidget);
    await unmount(tester);
  });
}
