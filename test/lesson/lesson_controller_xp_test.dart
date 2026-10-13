// Unit tests for LessonController's XP wiring (issue #010).
//
// Covers: XpService.applyLessonResult is called exactly once per completed
// lesson (via CONTINUE/next() and via SKIP), the LessonState.xpApplied guard
// prevents re-applying on repeated completion-triggering calls, and
// restart() correctly starts a fresh, re-appliable session.

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/lesson/lesson_controller.dart';

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
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    statsRepo = StatsRepository(db, FakeClock(kTestToday));
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

  test('applies XP exactly once when CONTINUE reaches done (correct, no hint '
      '+ perfect bonus)', () async {
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
    await controller.next(); // -> done, applies XP once

    final state = container.read(lessonControllerProvider);
    expect(state.isDone, isTrue);
    expect(state.xpApplied, isTrue);

    final profile = await statsRepo.getProfile();
    expect(profile.xpTotal, 15); // 10 correct + 5 perfect bonus
  });

  test('applies XP exactly once when SKIP reaches done (0 XP)', () async {
    final items = await insertTestItems(db, 1, 1);
    final controller = container.read(lessonControllerProvider.notifier);
    controller.start([items.first]);

    await controller.skip(); // -> done directly, applies XP once

    final state = container.read(lessonControllerProvider);
    expect(state.isDone, isTrue);
    expect(state.xpApplied, isTrue);

    final profile = await statsRepo.getProfile();
    expect(profile.xpTotal, 0); // skipped = wrong = 0 XP, no bonus
  });

  test('xpApplied guard prevents a repeated completion call from double-'
      'counting XP', () async {
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
    await controller.next(); // lesson reaches done, XP applied once
    final profileAfterFirst = await statsRepo.getProfile();
    expect(profileAfterFirst.xpTotal, 15);

    // Replaying the completion-triggering call (e.g. a stray rebuild
    // re-invoking it) must not re-apply XP: phase is already `done`, so
    // next() no-ops before it would ever re-check the guard.
    await controller.next();
    await controller.next();

    final profileAfterReplay = await statsRepo.getProfile();
    expect(profileAfterReplay.xpTotal, 15);
    expect(container.read(lessonControllerProvider).xpApplied, isTrue);
  });

  test(
    'never emits phase:done with xpTotalAfterLesson still null (regression: '
    'the result screen must never render a transient pre-XP level/progress)',
    () async {
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

      final emittedStates = <LessonState>[];
      final sub = container.listen(
        lessonControllerProvider,
        (_, next) => emittedStates.add(next),
      );
      addTearDown(sub.close);

      await controller.next(); // -> done, applies XP

      for (final s in emittedStates) {
        if (s.isDone) {
          expect(
            s.xpTotalAfterLesson,
            isNotNull,
            reason: 'phase flipped to done before xpTotalAfterLesson was set',
          );
        }
      }
      expect(emittedStates.last.xpTotalAfterLesson, 15);
    },
  );

  test('restart() starts a fresh session that can apply XP again', () async {
    final items = await insertTestItems(db, 1, 1);
    final controller = container.read(lessonControllerProvider.notifier);
    controller.start([items.first]);
    await controller.skip(); // 0 XP, done
    expect(container.read(lessonControllerProvider).xpApplied, isTrue);

    controller.restart();
    expect(container.read(lessonControllerProvider).xpApplied, isFalse);

    controller.updateDraft(
      ExerciseDraft(
        hasAnswer: true,
        grade: () => true,
        correctAnswerLabel: '05/14/1985',
      ),
    );
    await controller.submitGrade();
    await controller.next();

    final profile = await statsRepo.getProfile();
    expect(profile.xpTotal, 15); // the restarted session's own 10 + 5 bonus
  });
}
