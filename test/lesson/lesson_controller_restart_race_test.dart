// Regression test for issue #033: start()/restart() are synchronous and
// don't go through the #031 `_actionInFlight` guard, so calling restart()
// while a submitGrade/skip/next call is still mid-`await` (e.g. during
// `_completeLesson`'s XP/streak writes) must not let that stale call's
// resumed `state = ...` writes clobber the fresh post-restart state, and
// must not leave `_actionInFlight` stuck so the next legitimate action on
// the new session gets silently dropped.

import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/lesson/lesson_controller.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
import 'package:fox_streak_app/src/stats/pet_service.dart';
import 'package:fox_streak_app/src/stats/xp_service.dart';

import '../data/test_helpers.dart';

/// XpService whose [applyLessonResult] blocks on [gate] until the test
/// completes it, so a test can call `restart()` while `_completeLesson`'s
/// XP write is still in flight.
class _PausingXpService extends XpService {
  _PausingXpService(super.statsRepo, super.clock);

  final Completer<void> gate = Completer<void>();

  @override
  Future<XpApplication> applyLessonResult(LessonResult result) async {
    await gate.future;
    return super.applyLessonResult(result);
  }
}

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
  late StatsRepository statsRepo;
  late _PausingXpService pausingXp;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    statsRepo = StatsRepository(db, FakeClock(kTestToday));
    pausingXp = _PausingXpService(statsRepo, FakeClock(kTestToday));
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(FakeClock(kTestToday)),
        petCatalogLoaderProvider.overrideWithValue(
          () async => const <PetEntry>[],
        ),
        xpServiceProvider.overrideWithValue(pausingXp),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  test('restart() mid-flight does not get clobbered by the stale next() once '
      'its paused XP write resolves', () async {
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
    await controller.submitGrade(); // -> feedback

    // Fire the completing next() but don't await it: it runs
    // synchronously up to the paused XP write inside _completeLesson,
    // then suspends.
    final staleNext = controller.next();

    // restart() while that await is still pending — this is the race
    // from issue #033.
    controller.restart();

    final freshState = container.read(lessonControllerProvider);
    expect(freshState.phase, LessonPhase.answering);
    expect(freshState.outcomes, isEmpty);
    expect(freshState.xpApplied, isFalse);
    // The in-flight guard must not be stuck on because of the stale
    // next() call — a legitimate action on the new session must work.
    expect(freshState.busy, isFalse);

    // Let the stale next() resume and finish.
    pausingXp.gate.complete();
    await staleNext;

    final afterStale = container.read(lessonControllerProvider);
    expect(afterStale.phase, LessonPhase.answering);
    expect(afterStale.outcomes, isEmpty);
    expect(afterStale.xpApplied, isFalse);
    expect(afterStale.xpTotalAfterLesson, isNull);
    expect(afterStale.streakCountAfterLesson, isNull);
    expect(afterStale.busy, isFalse);
  });

  test('restart() mid-flight clears the in-flight guard so the next action on '
      'the fresh session is not silently dropped', () async {
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
    await controller.submitGrade(); // -> feedback

    final staleNext = controller.next();
    controller.restart();

    // A legitimate action on the fresh session, fired while the stale
    // next() is still suspended, must not be dropped by the guard.
    controller.updateDraft(
      ExerciseDraft(
        hasAnswer: true,
        grade: () => true,
        correctAnswerLabel: '05/14/1985',
      ),
    );
    await controller.submitGrade();

    final afterFreshAction = container.read(lessonControllerProvider);
    expect(afterFreshAction.phase, LessonPhase.feedback);
    expect(afterFreshAction.outcomes.length, 1);

    pausingXp.gate.complete();
    await staleNext;

    // The stale completion must still not have clobbered the fresh
    // session's progress.
    final finalState = container.read(lessonControllerProvider);
    expect(finalState.phase, LessonPhase.feedback);
    expect(finalState.outcomes.length, 1);
  });
}
