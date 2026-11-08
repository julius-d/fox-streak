// Shell test for session-aware distractors (issue #120): after a correct
// choice card, the next choice card must not offer that answer as a
// distractor while enough other answers exist.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/lesson/lesson_screen.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
import 'package:fox_streak_app/src/stats/pet_service.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/test/data/test_helpers.dart';

class _NoSound extends FoxSoundEnabled {
  @override
  bool build() => false;
}

Future<List<Item>> _persistItems(AppDatabase db) async {
  await db
      .into(db.questionSets)
      .insert(
        QuestionSetsCompanion.insert(
          packId: 1,
          id: const Value(1),
          title: 'Set',
          createdBy: 'test',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  final items = <Item>[];
  for (var i = 0; i < 8; i++) {
    final id = await db
        .into(db.items)
        .insert(
          ItemsCompanion.insert(
            setId: 1,
            type: 'choice',
            prompt: 'Prompt $i',
            answer: 'answer$i',
            position: i,
          ),
        );
    items.add(
      Item(
        id: id,
        setId: 1,
        type: 'choice',
        prompt: 'Prompt $i',
        answer: 'answer$i',
        hint: '',
        position: i,
      ),
    );
  }
  return items;
}

void main() {
  testWidgets('next choice card does not offer the previous correct answer', (
    tester,
  ) async {
    // Unseeded queue shuffle: repeat so that a regression (3 of 7 odds of
    // the answer reappearing) cannot pass by luck.
    for (var round = 0; round < 8; round++) {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final items = (await tester.runAsync(() => _persistItems(db)))!;
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(round),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            systemClockProvider.overrideWithValue(
              FakeClock(DateTime(2026, 10, 11, 12)),
            ),
            petCatalogLoaderProvider.overrideWithValue(
              () async => const <PetEntry>[],
            ),
            foxSoundEnabledProvider.overrideWith(_NoSound.new),
          ],
          child: MaterialApp(
            theme: FoxStreakTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LessonScreen(setId: 1, items: items),
          ),
        ),
      );
      await tester.pump();

      final first = items.firstWhere(
        (i) => find.text(i.prompt).evaluate().isNotEmpty,
      );
      await tester.tap(find.text(first.answer));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(first.prompt), findsNothing);
      expect(find.text(first.answer), findsNothing);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('choiceOption$i')), findsOneWidget);
      }
    }
  });
}
