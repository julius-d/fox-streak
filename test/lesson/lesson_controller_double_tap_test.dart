// Regression test for issue #031: a double-tap (or two near-simultaneous
// calls) on CHECK/CONTINUE/Skip firing before the first call's `await`
// resumes must not duplicate an `attempts` row or an `outcomes` entry.
//
// Each test fires the action twice back-to-back *without* awaiting the
// first call, mirroring a double-tap: both calls run synchronously up to
// their first `await` before either has a chance to update `state`.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/lesson/lesson_controller.dart';

import '../data/test_helpers.dart';

Future<Item> insertTestItem(AppDatabase db, int setId) async {
  await db
      .into(db.questionSets)
      .insert(
        QuestionSetsCompanion.insert(
          id: Value(setId),
          title: 'Test Set',
          description: const Value(''),
          createdBy: 'test',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  final id = await db
      .into(db.items)
      .insert(
        ItemsCompanion.insert(
          setId: setId,
          type: 'date',
          prompt: 'Birthday',
          answer: '1985-05-14',
          position: 0,
        ),
      );
  return Item(
    id: id,
    setId: setId,
    type: 'date',
    prompt: 'Birthday',
    answer: '1985-05-14',
    position: 0,
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(FakeClock(kTestToday)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  test('double-tap skip() records exactly one outcome/attempt', () async {
    final item = await insertTestItem(db, 1);
    final controller = container.read(lessonControllerProvider.notifier);
    controller.start([item]);

    // Fire twice without awaiting the first call — both run synchronously
    // up to their first `await` before either updates `state`.
    final first = controller.skip();
    final second = controller.skip();
    await Future.wait([first, second]);

    expect(container.read(lessonControllerProvider).outcomes.length, 1);
    expect(await container.read(statsRepositoryProvider).countAttempts(), 1);
  });

  test(
    'double-tap submitGrade() records exactly one outcome/attempt',
    () async {
      final item = await insertTestItem(db, 1);
      final controller = container.read(lessonControllerProvider.notifier);
      controller.start([item]);
      controller.updateDraft(
        ExerciseDraft(
          hasAnswer: true,
          grade: () => true,
          correctAnswerLabel: '05/14/1985',
        ),
      );

      final first = controller.submitGrade();
      final second = controller.submitGrade();
      await Future.wait([first, second]);

      expect(container.read(lessonControllerProvider).outcomes.length, 1);
      expect(await container.read(statsRepositoryProvider).countAttempts(), 1);
    },
  );

  test(
    'double-tap next() on the last item only completes the lesson once',
    () async {
      final item = await insertTestItem(db, 1);
      final controller = container.read(lessonControllerProvider.notifier);
      controller.start([item]);
      controller.updateDraft(
        ExerciseDraft(
          hasAnswer: true,
          grade: () => true,
          correctAnswerLabel: '05/14/1985',
        ),
      );
      await controller.submitGrade();
      expect(
        container.read(lessonControllerProvider).phase,
        LessonPhase.feedback,
      );

      final first = controller.next();
      final second = controller.next();
      await Future.wait([first, second]);

      final state = container.read(lessonControllerProvider);
      expect(state.phase, LessonPhase.done);
      expect(state.outcomes.length, 1);
    },
  );
}
