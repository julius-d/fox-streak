// Integration test for issue #072 — tapping "Practice again" must reset the
// lesson progress bar to empty instantly, not drain backward over ~300ms.
//
// Drives the real `LessonScreen` through a two-item lesson to completion via
// the overflow menu's Skip (so the test doesn't depend on which choice
// renders where), taps "Practice again", then checks the `lessonProgressBar`'s
// underlying `LinearProgressIndicator` well before the #066 300ms tween could
// have resolved: it must already read 0, proving the bar remounted instead of
// tweening the 1.0 -> 0.0 drop.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/lesson/lesson_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'practice again resets the lesson progress bar to empty instantly',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 26, 9));

      final setId = await db
          .into(db.questionSets)
          .insert(
            QuestionSetsCompanion.insert(
              title: 'Animals',
              description: const Value(''),
              createdBy: 'test',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      final items = <Item>[];
      for (final (prompt, answer, position) in [
        ('der Hund', 'dog', 0),
        ('die Katze', 'cat', 1),
      ]) {
        final id = await db
            .into(db.items)
            .insert(
              ItemsCompanion.insert(
                setId: setId,
                type: 'choice',
                prompt: prompt,
                answer: answer,
                position: position,
              ),
            );
        items.add(
          Item(
            id: id,
            setId: setId,
            type: 'choice',
            prompt: prompt,
            answer: answer,
            position: position,
          ),
        );
      }

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
            home: LessonScreen(setId: setId, items: items),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Skip both items via the overflow menu to reach the result screen
      // with the bar at full, regardless of which item renders first.
      for (var i = 0; i < items.length; i++) {
        await tester.tap(find.byKey(const Key('lessonOverflowMenu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('skipItemMenuItem')));
        await tester.pumpAndSettle();
      }
      // This fresh profile's first-ever lesson also advances the streak.
      await dismissCompletionScreens(tester);
      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);

      Finder progressFill() => find.descendant(
        of: find.byKey(const Key('lessonProgressBar')),
        matching: find.byType(LinearProgressIndicator),
      );
      expect(
        tester.widget<LinearProgressIndicator>(progressFill()).value,
        closeTo(1.0, 1e-9),
      );

      // Tap Practice again, then pump for far less than the #066 300ms
      // tween duration — long enough for a backward-draining bar to still
      // read well above empty, too short for it to have resolved on its own.
      await tester.tap(find.byKey(const Key('redoWholeSetButton')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.widget<LinearProgressIndicator>(progressFill()).value,
        closeTo(0.0, 1e-9),
      );

      // Drains any remaining scheduled animations so none is still pending
      // when the widget tree is torn down.
      await tester.pumpAndSettle();
    },
  );
}
