// Widget tests for the per-type item editors (issue #004; #022 replaced the
// required `direction` SegmentedButton with an optional language-pair
// toggle shared by choice/freeText).
//
// Pumps `ItemEditorDialog` through a harness button with an in-memory DB +
// `FakeClock` overrides. Covers: choice-valid with language pair + 3
// distractors, choice-valid-without-language-pair (#022 non-rejecting
// path), language-pair-toggle-off-by-default,
// language-pair-same-language-blocked,
// distractor-duplicating-answer-blocked (editor-only),
// freeText-valid-without-language-pair (#026/#022 non-rejecting path),
// phone-grouping-display-but-digits-stored, phone-paste-with-separators,
// phone-too-short rejected, date-auto-advance (+ backspace-back),
// date-future / pre-1900 / 30.02 rejected, edit-prefill (phone grouped,
// date split, choice choices + language pair kept), no-save-on-invalid.
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

/// Taps the language-pair toggle, then picks [promptLang]/[answerLang] from
/// the two dropdowns it reveals.
Future<void> enableLanguagePair(
  WidgetTester tester,
  String promptLang,
  String answerLang,
) async {
  await tester.tap(find.byKey(const Key('itemLanguagePairToggle')));
  await settle(tester);
  await tester.tap(find.byKey(const Key('itemPromptLangField')));
  await settle(tester);
  await tester.tap(find.text(promptLang).last);
  await settle(tester);
  await tester.tap(find.byKey(const Key('itemAnswerLangField')));
  await settle(tester);
  await tester.tap(find.text(answerLang).last);
  await settle(tester);
}

void main() {
  testWidgets(
    'choice-valid with a language pair saves promptLang/answerLang + choices',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final env = await pumpEditor(tester, clock);

      await tester.enterText(find.byKey(const Key('itemPromptField')), 'Hund');
      await tester.enterText(find.byKey(const Key('itemAnswerField')), 'dog');
      await enableLanguagePair(tester, 'German', 'English');
      await tester.enterText(find.byKey(const Key('itemChoice0Field')), 'cat');
      await tester.enterText(
        find.byKey(const Key('itemChoice1Field')),
        'mouse',
      );
      await tester.enterText(find.byKey(const Key('itemChoice2Field')), 'bird');
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);

      final items = await env.repo.getItemsForSet(env.setId);
      expect(items, hasLength(1));
      expect(items.single.type, 'choice');
      expect(items.single.promptLang, 'de');
      expect(items.single.answerLang, 'en');
      expect((jsonDecode(items.single.choices!) as List).cast<String>(), [
        'cat',
        'mouse',
        'bird',
      ]);
      await unmount(tester);
    },
  );

  testWidgets(
    'choice-valid-without-language-pair saves (#022 non-rejecting path, '
    'toggle off by default)',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final env = await pumpEditor(tester, clock);

      // Toggle off by default for new items: no dropdowns shown.
      expect(find.byKey(const Key('itemPromptLangField')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('itemPromptField')),
        'Capital of France',
      );
      await tester.enterText(find.byKey(const Key('itemAnswerField')), 'Paris');
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);

      final items = await env.repo.getItemsForSet(env.setId);
      expect(items, hasLength(1));
      expect(items.single.type, 'choice');
      expect(items.single.promptLang, isNull);
      expect(items.single.answerLang, isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'freeText-valid-without-language-pair saves (#026/#022 non-rejecting '
    'path)',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final env = await pumpEditor(tester, clock);
      await switchType(tester, 'Word (type answer)');

      await tester.enterText(find.byKey(const Key('itemPromptField')), 'Hund');
      await tester.enterText(find.byKey(const Key('itemAnswerField')), 'dog');
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);

      final items = await env.repo.getItemsForSet(env.setId);
      expect(items, hasLength(1));
      expect(items.single.type, 'freeText');
      expect(items.single.answer, 'dog');
      expect(items.single.promptLang, isNull);
      expect(items.single.answerLang, isNull);
      expect(items.single.choices, isNull);
      await unmount(tester);
    },
  );

  testWidgets('language-pair-same-language-blocked shows inline error', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final env = await pumpEditor(tester, clock);

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Hund');
    await tester.enterText(find.byKey(const Key('itemAnswerField')), 'dog');
    await enableLanguagePair(tester, 'German', 'German');
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    expect(find.text('Languages must differ'), findsOneWidget);
    expect(await env.repo.getItemsForSet(env.setId), isEmpty);
    await unmount(tester);
  });

  testWidgets('distractor-duplicating-answer-blocked is editor-only', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final env = await pumpEditor(tester, clock);

    await tester.enterText(find.byKey(const Key('itemPromptField')), 'Hund');
    await tester.enterText(find.byKey(const Key('itemAnswerField')), 'dog');
    // Trim/case-insensitive duplicate of the answer.
    await tester.enterText(find.byKey(const Key('itemChoice0Field')), ' Dog ');
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    expect(find.text('Must be different from the answer'), findsOneWidget);
    expect(await env.repo.getItemsForSet(env.setId), isEmpty);
    await unmount(tester);
  });

  testWidgets(
    'switching from choice (half-picked language pair) to phone saves '
    '(regression: stale toggle state must not block a type it does not '
    'apply to)',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final env = await pumpEditor(tester, clock);

      // Enable the toggle but pick only one side, then abandon choice for
      // phone — the half-picked pair must not survive the type switch.
      await tester.tap(find.byKey(const Key('itemLanguagePairToggle')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('itemPromptLangField')));
      await settle(tester);
      await tester.tap(find.text('German').last);
      await settle(tester);

      await switchType(tester, 'Phone');

      await tester.enterText(find.byKey(const Key('itemPromptField')), 'Mama');
      await tester.enterText(
        find.byKey(const Key('itemAnswerField')),
        '01711234567',
      );
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);

      final items = await env.repo.getItemsForSet(env.setId);
      expect(items, hasLength(1));
      expect(items.single.type, 'phone');
      expect(items.single.promptLang, isNull);
      expect(items.single.answerLang, isNull);
      await unmount(tester);
    },
  );

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

  testWidgets('edit-prefill choice keeps language pair and choices', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final repo = SetsRepository(db, clock);
    final setId = await repo.createSet(title: 'Test', createdBy: 'Mama');
    final itemId = await repo.addItem(
      setId: setId,
      type: 'choice',
      prompt: 'Hund',
      answer: 'dog',
      promptLang: 'en',
      answerLang: 'de',
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

    // Toggle on by default when editing an item with an existing pair.
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('itemLanguagePairToggle')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('itemPromptLangField')),
          )
          .initialValue,
      'en',
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('itemAnswerLangField')),
          )
          .initialValue,
      'de',
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
    expect(updated?.promptLang, 'en');
    expect(updated?.answerLang, 'de');
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
            type: 'choice',
            prompt: 'Hund',
            answer: 'dog',
            promptLang: const Value('de'),
            answerLang: const Value('en'),
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

  testWidgets(
    'language-pair-toggle reveals dropdowns on, hides+clears off (#022)',
    (tester) async {
      final clock = FakeClock(kTestToday);
      await pumpEditor(tester, clock);

      expect(find.byKey(const Key('itemLanguagePairToggle')), findsOneWidget);
      expect(find.byKey(const Key('itemPromptLangField')), findsNothing);
      expect(find.byKey(const Key('itemAnswerLangField')), findsNothing);

      await tester.tap(find.byKey(const Key('itemLanguagePairToggle')));
      await settle(tester);
      expect(find.byKey(const Key('itemPromptLangField')), findsOneWidget);
      expect(find.byKey(const Key('itemAnswerLangField')), findsOneWidget);

      await tester.tap(find.byKey(const Key('itemPromptLangField')));
      await settle(tester);
      await tester.tap(find.text('German').last);
      await settle(tester);

      // Toggling back off hides the dropdowns again (and clears the pick,
      // verified indirectly: re-enabling starts from nothing selected).
      await tester.tap(find.byKey(const Key('itemLanguagePairToggle')));
      await settle(tester);
      expect(find.byKey(const Key('itemPromptLangField')), findsNothing);

      await tester.tap(find.byKey(const Key('itemLanguagePairToggle')));
      await settle(tester);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const Key('itemPromptLangField')),
            )
            .initialValue,
        isNull,
      );
    },
  );

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
