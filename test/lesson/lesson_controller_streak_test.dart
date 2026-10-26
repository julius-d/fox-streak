// Unit tests for LessonController's streak wiring (issue #011).
//
// Covers: StreakService.recordActivity is called exactly once per completed
// lesson (via CONTINUE/next() and via SKIP), reusing #010's xpApplied guard
// (no second guard), a lesson with 0 correct answers still extends the
// streak, and restart() correctly starts a fresh, re-appliable session.

import 'package:drift/drift.dart';
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

import '../data/test_helpers.dart';

Future<List<Item>> insertTestItems(AppDatabase db, int setId, int count) async {
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
  final items = <Item>[];
  for (var i = 0; i < count; i++) {
    final id = await db
        .into(db.items)
        .insert(
          ItemsCompanion.insert(
            setId: setId,
            type: 'date',
            prompt: 'Birthday $i',
            answer: '1985-05-14',
            position: i,
          ),
        );
    items.add(
      Item(
        id: id,
        setId: setId,
        type: 'date',
        prompt: 'Birthday $i',
        answer: '1985-05-14',
        position: i,
      ),
    );
  }
  return items;
}

void main() {
  late AppDatabase db;
  late StatsRepository statsRepo;
  late FakeClock clock;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = FakeClock(kTestToday);
    statsRepo = StatsRepository(db, clock);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
        petCatalogLoaderProvider.overrideWithValue(
          () async => const <PetEntry>[],
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  test('CONTINUE reaching done applies the streak exactly once', () async {
    final items = await insertTestItems(db, 1, 1);
    final controller = container.read(lessonControllerProvider.notifier);
    controller.start([items.first]);
    controller.updateDraft(
      ExerciseDraft(
        hasAnswer: true,
        grade: () => true,
        correctAnswerLabel: '05/14/1985',
      ),
    );

    await controller.submitGrade(); // -> feedback
    await controller.next(); // -> done, applies XP + streak once

    final state = container.read(lessonControllerProvider);
    expect(state.isDone, isTrue);
    expect(state.streakCountAfterLesson, 1);

    final profile = await statsRepo.getProfile();
    expect(profile.streakCount, 1);
    expect(profile.lastActiveDay, clock.todayDayString());
  });

  test(
    'SKIP reaching done still extends the streak (0 correct answers)',
    () async {
      final items = await insertTestItems(db, 1, 1);
      final controller = container.read(lessonControllerProvider.notifier);
      controller.start([items.first]);

      await controller.skip(); // -> done directly, 0 XP but streak still +1

      final state = container.read(lessonControllerProvider);
      expect(state.isDone, isTrue);
      expect(state.streakCountAfterLesson, 1);

      final profile = await statsRepo.getProfile();
      expect(profile.streakCount, 1);
    },
  );

  test('the shared xpApplied guard prevents a repeated completion call from '
      'double-counting the streak', () async {
    final items = await insertTestItems(db, 1, 1);
    final controller = container.read(lessonControllerProvider.notifier);
    controller.start([items.first]);
    controller.updateDraft(
      ExerciseDraft(
        hasAnswer: true,
        grade: () => true,
        correctAnswerLabel: '05/14/1985',
      ),
    );

    await controller.submitGrade();
    await controller.next(); // lesson reaches done, streak applied once
    final profileAfterFirst = await statsRepo.getProfile();
    expect(profileAfterFirst.streakCount, 1);

    // Replaying the completion-triggering call (e.g. a stray rebuild
    // re-invoking it) must not re-apply the streak.
    await controller.next();
    await controller.next();

    final profileAfterReplay = await statsRepo.getProfile();
    expect(profileAfterReplay.streakCount, 1);
    expect(container.read(lessonControllerProvider).xpApplied, isTrue);
  });

  test('a same-day second lesson does not double-count the streak', () async {
    final items = await insertTestItems(db, 1, 2);
    final controller = container.read(lessonControllerProvider.notifier);

    controller.start([items[0]]);
    await controller.skip();
    expect(container.read(lessonControllerProvider).streakCountAfterLesson, 1);

    // A second, independent lesson session on the same day.
    controller.start([items[1]]);
    await controller.skip();
    expect(container.read(lessonControllerProvider).streakCountAfterLesson, 1);

    final profile = await statsRepo.getProfile();
    expect(profile.streakCount, 1);
  });

  test(
    'restart() starts a fresh session that advances the streak on a new day',
    () async {
      final items = await insertTestItems(db, 1, 1);
      final controller = container.read(lessonControllerProvider.notifier);
      controller.start([items.first]);
      await controller.skip();
      expect(container.read(lessonControllerProvider).xpApplied, isTrue);

      clock.setNow(kTestToday.add(const Duration(days: 1)));
      controller.restart();
      expect(container.read(lessonControllerProvider).xpApplied, isFalse);

      await controller.skip();

      final profile = await statsRepo.getProfile();
      expect(profile.streakCount, 2);
      expect(
        container.read(lessonControllerProvider).streakCountAfterLesson,
        2,
      );
    },
  );
}
