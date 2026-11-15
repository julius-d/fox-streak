// Set mastery (issue #134): the `SetMastery` math and
// `StatsRepository.watchSetMastery`'s two-clean-answers-in-a-row rule.

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/set_mastery.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';

import 'test_helpers.dart';

void main() {
  group('SetMastery', () {
    test('kind: no items -> none, unanswered -> fresh, answered -> crowns', () {
      expect(SetMastery.empty.kind, MasteryKind.none);
      expect(
        const SetMastery(itemCount: 3, masteredCount: 0, practiced: false).kind,
        MasteryKind.fresh,
      );
      expect(
        const SetMastery(itemCount: 3, masteredCount: 0, practiced: true).kind,
        MasteryKind.crowns,
      );
    });

    test('crowns are the mastered share x 5, continuous and exact', () {
      SetMastery of(int mastered, int total) => SetMastery(
        itemCount: total,
        masteredCount: mastered,
        practiced: true,
      );
      expect(of(9, 20).crowns, 2.25);
      expect(of(1, 50).crowns, closeTo(0.1, 1e-9));
      expect(of(3, 5).crowns, 3.0);
      expect(of(3, 3).crowns, 5.0);
      expect(of(0, 3).crowns, 0);
      expect(SetMastery.empty.crowns, 0);
    });

    test('percent rounds down: only a fully mastered set is 100', () {
      expect(
        const SetMastery(
          itemCount: 20,
          masteredCount: 9,
          practiced: true,
        ).percent,
        45,
      );
      expect(
        const SetMastery(
          itemCount: 300,
          masteredCount: 299,
          practiced: true,
        ).percent,
        99,
      );
      expect(
        const SetMastery(
          itemCount: 4,
          masteredCount: 4,
          practiced: true,
        ).isComplete,
        isTrue,
      );
      expect(SetMastery.empty.isComplete, isFalse);
    });
  });

  group('watchSetMastery', () {
    late AppDatabase db;
    late StatsRepository stats;
    late SetsRepository sets;
    late FakeClock clock;
    var tick = 0;

    setUp(() {
      db = makeTestDb();
      clock = FakeClock(kTestToday);
      stats = StatsRepository(db, clock);
      sets = SetsRepository(db, clock);
      tick = 0;
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> seedSet(int itemCount, {String title = 'S'}) async {
      final setId = await sets.createSet(title: title, createdBy: 'teacher');
      for (var i = 0; i < itemCount; i++) {
        await sets.addItem(
          setId: setId,
          type: 'freeText',
          prompt: 'P$i',
          answer: 'A$i',
        );
      }
      return setId;
    }

    Future<List<int>> itemIds(int setId) async => [
      for (final item in await sets.getItemsForSet(setId)) item.id,
    ];

    /// Records answers for [itemId] oldest first, one second apart.
    Future<void> answer(int itemId, List<bool> oks, {List<bool>? hints}) async {
      for (var i = 0; i < oks.length; i++) {
        await stats.recordAttempt(
          itemId: itemId,
          ok: oks[i],
          hintUsed: hints?[i] ?? false,
          now: kTestToday.add(Duration(seconds: tick++)),
        );
      }
    }

    Future<SetMastery> masteryOf(int setId) async =>
        (await stats.watchSetMastery().first)[setId] ?? SetMastery.empty;

    test('two clean correct answers in a row master an item', () async {
      final setId = await seedSet(2);
      final ids = await itemIds(setId);
      await answer(ids[0], [true, true]);

      expect(
        await masteryOf(setId),
        const SetMastery(itemCount: 2, masteredCount: 1, practiced: true),
      );
    });

    test('a single correct answer is not enough', () async {
      final setId = await seedSet(1);
      await answer((await itemIds(setId)).single, [true]);

      final mastery = await masteryOf(setId);
      expect(mastery.masteredCount, 0);
      expect(mastery.kind, MasteryKind.crowns);
    });

    test('a wrong (or skipped) latest answer un-masters the item until two '
        'clean answers again', () async {
      final setId = await seedSet(1);
      final id = (await itemIds(setId)).single;
      await answer(id, [true, true, false]);
      expect((await masteryOf(setId)).masteredCount, 0);

      await answer(id, [true]);
      expect((await masteryOf(setId)).masteredCount, 0);

      await answer(id, [true]);
      expect((await masteryOf(setId)).masteredCount, 1);
    });

    test('a correct answer with a hint un-masters the item', () async {
      final setId = await seedSet(1);
      final id = (await itemIds(setId)).single;
      await answer(id, [true, true, true], hints: [false, false, true]);
      expect((await masteryOf(setId)).masteredCount, 0);

      await answer(id, [true, true]);
      expect((await masteryOf(setId)).masteredCount, 1);
    });

    test('only the two most recent answers count, also for equal '
        'timestamps', () async {
      final setId = await seedSet(1);
      final id = (await itemIds(setId)).single;
      for (final ok in [false, true, true]) {
        await stats.recordAttempt(itemId: id, ok: ok, now: kTestToday);
      }
      expect((await masteryOf(setId)).masteredCount, 1);

      await stats.recordAttempt(itemId: id, ok: false, now: kTestToday);
      expect((await masteryOf(setId)).masteredCount, 0);
    });

    test('answers recorded without a hint flag (pre-#134 rows) count as '
        'hint-free', () async {
      final setId = await seedSet(1);
      final id = (await itemIds(setId)).single;
      for (var i = 0; i < 2; i++) {
        await db
            .into(db.attempts)
            .insert(AttemptsCompanion.insert(itemId: id, ok: true, at: i));
      }
      expect((await masteryOf(setId)).masteredCount, 1);
    });

    test('a set with items but no answer is fresh; any answer, even a skip, '
        'makes it show crowns', () async {
      final setId = await seedSet(3);
      expect((await masteryOf(setId)).kind, MasteryKind.fresh);

      await answer((await itemIds(setId)).first, [false]);
      expect(
        await masteryOf(setId),
        const SetMastery(itemCount: 3, masteredCount: 0, practiced: true),
      );
    });

    test('a set without items is absent (empty)', () async {
      final setId = await seedSet(0);
      expect((await stats.watchSetMastery().first).containsKey(setId), false);
      expect((await masteryOf(setId)).kind, MasteryKind.none);
    });

    test('adding items lowers the share, deleting recalculates it, editing '
        'keeps the mastered status', () async {
      final setId = await seedSet(2);
      final ids = await itemIds(setId);
      await answer(ids[0], [true, true]);
      await answer(ids[1], [true, true]);
      expect((await masteryOf(setId)).crowns, 5);

      await sets.addItem(
        setId: setId,
        type: 'freeText',
        prompt: 'new',
        answer: 'new',
      );
      expect(
        await masteryOf(setId),
        const SetMastery(itemCount: 3, masteredCount: 2, practiced: true),
      );

      await sets.updateItem(id: ids[0], prompt: 'edited', answer: 'edited');
      expect((await masteryOf(setId)).masteredCount, 2);

      await sets.deleteItem(ids[1]);
      expect(
        await masteryOf(setId),
        const SetMastery(itemCount: 2, masteredCount: 1, practiced: true),
      );
    });

    test('sets are counted independently', () async {
      final a = await seedSet(2, title: 'A');
      final b = await seedSet(4, title: 'B');
      await answer((await itemIds(a)).first, [true, true]);

      final all = await stats.watchSetMastery().first;
      expect(all[a]!.masteredCount, 1);
      expect(all[b]!.kind, MasteryKind.fresh);
    });

    test('duplicated and imported sets start as fresh', () async {
      final setId = await seedSet(2);
      for (final id in await itemIds(setId)) {
        await answer(id, [true, true]);
      }
      final copyId = await sets.duplicateSet(setId);
      final json = await sets.exportSetToJson(setId, today: kTestToday);
      final importedId = await sets.importSetFromJson(
        Map<String, dynamic>.from(json),
        today: kTestToday,
      );

      expect((await masteryOf(setId)).isComplete, isTrue);
      expect((await masteryOf(copyId)).kind, MasteryKind.fresh);
      expect((await masteryOf(importedId)).kind, MasteryKind.fresh);
    });

    test('re-emits when an answer is recorded', () async {
      final setId = await seedSet(1);
      final id = (await itemIds(setId)).single;
      final emitted = stats.watchSetMastery().map((all) => all[setId]?.kind);
      final expectation = expectLater(
        emitted,
        emitsInOrder([MasteryKind.fresh, MasteryKind.crowns]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await answer(id, [true]);
      await expectation;
    });
  });
}
