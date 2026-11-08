// Unit tests for LessonController's hintUsed propagation (issue #009 fix).
//
// Exercises the controller directly via a ProviderContainer (no widget
// tree needed) to prove `submitGrade()` and `skip()` both copy the live
// draft's `ExerciseDraft.hintUsed` onto the recorded `LessonItemOutcome`,
// instead of the old hardcoded `false`.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/lesson/lesson_controller.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
import 'package:fox_streak_app/src/stats/pet_service.dart';

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

  test('submitGrade copies draft.hintUsed onto the outcome', () async {
    final item = await insertTestItem(db, 1);
    final controller = container.read(lessonControllerProvider.notifier);
    controller.start([item]);
    controller.updateDraft(
      ExerciseDraft(
        hasAnswer: true,
        grade: () => true,
        correctAnswerLabel: '05/14/1985',
        hintUsed: true,
      ),
    );

    await controller.submitGrade();

    expect(
      container.read(lessonControllerProvider).outcomes.single.hintUsed,
      isTrue,
    );
  });

  test(
    'submitGrade keeps hintUsed false when the hint was never revealed',
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
        container.read(lessonControllerProvider).outcomes.single.hintUsed,
        isFalse,
      );
    },
  );

  test('skip copies the current draft.hintUsed onto the outcome', () async {
    final item = await insertTestItem(db, 1);
    final controller = container.read(lessonControllerProvider.notifier);
    controller.start([item]);
    controller.updateDraft(
      ExerciseDraft(
        hasAnswer: false,
        grade: () => false,
        correctAnswerLabel: '05/14/1985',
        hintUsed: true,
      ),
    );

    await controller.skip();

    expect(
      container.read(lessonControllerProvider).outcomes.single.hintUsed,
      isTrue,
    );
  });

  test('skip defaults hintUsed to false when there is no draft yet', () async {
    final item = await insertTestItem(db, 1);
    final controller = container.read(lessonControllerProvider.notifier);
    controller.start([item]);

    await controller.skip();

    expect(
      container.read(lessonControllerProvider).outcomes.single.hintUsed,
      isFalse,
    );
  });

  group('distractor pool (issue #116)', () {
    Future<List<Item>> makeItems(int count) async {
      final items = <Item>[await insertTestItem(db, 1)];
      for (var i = 1; i < count; i++) {
        final id = await db
            .into(db.items)
            .insert(
              ItemsCompanion.insert(
                setId: 1,
                type: 'date',
                prompt: 'Birthday $i',
                answer: '1985-05-1$i',
                position: i,
              ),
            );
        items.add(
          Item(
            id: id,
            setId: 1,
            type: 'date',
            prompt: 'Birthday $i',
            answer: '1985-05-1$i',
            position: i,
          ),
        );
      }
      return items;
    }

    test('redo with a single missed item keeps the full pool', () async {
      final items = await makeItems(4);
      final controller = container.read(lessonControllerProvider.notifier);
      controller.start(items);

      controller.restartWithItems([items.first]);

      final state = container.read(lessonControllerProvider);
      expect(state.queue, [items.first]);
      expect(state.sourceItems, items);
    });

    test('consecutive redo rounds keep the original full pool', () async {
      final items = await makeItems(4);
      final controller = container.read(lessonControllerProvider.notifier);
      controller.start(items);

      controller.restartWithItems([items[0], items[1]]);
      controller.restartWithItems([items[1]]);

      final state = container.read(lessonControllerProvider);
      expect(state.queue, [items[1]]);
      expect(state.sourceItems, items);
    });

    test('start() sets the pool to the given items again', () async {
      final items = await makeItems(4);
      final controller = container.read(lessonControllerProvider.notifier);
      controller.start(items);
      controller.restartWithItems([items.first]);

      controller.start(items.take(2).toList());

      final state = container.read(lessonControllerProvider);
      expect(state.sourceItems, items.take(2).toList());
    });

    test('restartWithItems([]) is a no-op and leaves the pool', () async {
      final items = await makeItems(4);
      final controller = container.read(lessonControllerProvider.notifier);
      controller.start(items);
      final before = container.read(lessonControllerProvider);

      controller.restartWithItems([]);

      final after = container.read(lessonControllerProvider);
      expect(after.sourceItems, items);
      expect(after.attempt, before.attempt);
    });
  });

  test('restartWithItems carries earlier rounds into sessionOutcomes; start '
      'resets them (#120)', () async {
    final item = await insertTestItem(db, 1);
    final controller = container.read(lessonControllerProvider.notifier);
    controller.start([item]);
    await controller.skip();

    controller.restartWithItems([item]);
    final redo = container.read(lessonControllerProvider);
    expect(redo.outcomes, isEmpty);
    expect(redo.previousOutcomes.single.correct, isFalse);
    expect(redo.sessionOutcomes.single.itemId, item.id);

    controller.start([item]);
    final fresh = container.read(lessonControllerProvider);
    expect(fresh.previousOutcomes, isEmpty);
    expect(fresh.sessionOutcomes, isEmpty);
  });
}
