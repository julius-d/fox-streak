// Integration test for issue #031's double-tap guard, exercised through
// the real LessonScreen rather than the controller directly.
//
// test/lesson/lesson_controller_double_tap_test.dart proves the controller
// itself can't duplicate an attempts row/outcome. This test proves the
// *shell* actually closes the gap a code reviewer flagged on #031: CHECK
// and Skip are both live UI targets during the `answering` phase, so a
// Skip tap landing while CHECK's write is still in flight is exactly as
// unsafe as a literal double-tap on the same button. It must not be able
// to skip (or otherwise re-touch) the item CHECK is mid-grading.
//
// `_SlowStatsRepository` wraps the real repository with a timer-based
// delay on `recordAttempt` so the test can `pump()` (zero elapsed time)
// mid-write and observe `LessonState.busy` reliably, instead of racing
// against drift's real (microtask-fast) write.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/lesson/lesson_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

class _FixedClock extends Clock {
  @override
  DateTime now() => DateTime(2026, 10, 12, 12);
}

class _SlowStatsRepository extends StatsRepository {
  _SlowStatsRepository(super.db, super.clock);

  @override
  Future<int> recordAttempt({
    required int itemId,
    required bool ok,
    DateTime? now,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return super.recordAttempt(itemId: itemId, ok: ok, now: now);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Skip tap while CHECK is still in flight does not skip the item',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final setId = await db
          .into(db.questionSets)
          .insert(
            QuestionSetsCompanion.insert(
              title: 'Test set',
              createdBy: 'tester',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      final itemId = await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              setId: setId,
              type: 'choice',
              prompt: 'Hund',
              answer: 'dog',
              position: 0,
            ),
          );
      final item = Item(
        id: itemId,
        setId: setId,
        type: 'choice',
        prompt: 'Hund',
        answer: 'dog',
        position: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            systemClockProvider.overrideWithValue(_FixedClock()),
            statsRepositoryProvider.overrideWithValue(
              _SlowStatsRepository(db, _FixedClock()),
            ),
          ],
          child: MaterialApp(
            theme: FoxStreakTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LessonScreen(setId: setId, items: [item]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Answer, then press CHECK — this kicks off the (artificially slow)
      // recordAttempt write, which hasn't resolved yet after a zero-time
      // pump.
      await tester.tap(find.text('dog'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pump();

      // CHECK is disabled while its own write is still in flight.
      expect(
        tester
            .widget<FoxCheckButton>(find.byKey(const Key('checkButton')))
            .onPressed,
        isNull,
      );

      // Skip is hidden from the overflow menu for the same reason — it's
      // not a safe action to allow while CHECK's write is in flight.
      await tester.tap(find.byKey(const Key('lessonOverflowMenu')));
      await tester.pump();
      expect(find.byKey(const Key('skipItemMenuItem')), findsNothing);
      // Close the menu without selecting anything.
      await tester.tapAt(const Offset(1, 1));
      await tester.pump();

      // Let the delayed write resolve and the lesson settle into feedback.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lessonFeedbackBanner')), findsOneWidget);
      // Exactly one attempt was recorded for the item — CHECK's grade, not
      // a duplicate from a dropped-then-retried Skip.
      final attempts = await db.select(db.attempts).get();
      expect(attempts.length, 1);
    },
  );
}
