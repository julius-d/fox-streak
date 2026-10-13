import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/set_json_codec.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';

import 'test_helpers.dart';

void main() {
  late AppDatabase db;
  late SetsRepository repo;
  late FakeClock clock;

  setUp(() {
    db = makeTestDb();
    clock = FakeClock(kTestToday);
    repo = SetsRepository(db, clock);
  });

  tearDown(() async {
    await db.close();
  });

  group('sets CRUD', () {
    test('create/get/update/delete set', () async {
      final id = await repo.createSet(
        title: 'Animals',
        description: 'd',
        createdBy: 'teacher',
      );
      var set = await repo.getSetById(id);
      expect(set?.title, 'Animals');
      expect(set?.description, 'd');
      expect(set?.createdBy, 'teacher');

      await repo.updateSet(id: id, title: 'Animals 2');
      set = await repo.getSetById(id);
      expect(set?.title, 'Animals 2');

      expect(await repo.getAllSets(), hasLength(1));
      await repo.deleteSet(id);
      expect(await repo.getSetById(id), isNull);
      expect(await repo.getAllSets(), isEmpty);
    });

    test('create rejects bad title/createdBy', () async {
      expect(
        () => repo.createSet(title: ' ', createdBy: 'Mama'),
        throwsArgumentError,
      );
      expect(
        () => repo.createSet(title: 'T', createdBy: '  '),
        throwsArgumentError,
      );
      expect(
        () => repo.createSet(title: 'T', createdBy: 'x' * 51),
        throwsArgumentError,
      );
    });

    test('create accepts free-text creator names', () async {
      for (final name in [
        'Mama',
        'Ms. Smith',
        'teacher',
        'parent',
        'learner',
      ]) {
        final id = await repo.createSet(title: 'T $name', createdBy: name);
        expect((await repo.getSetById(id))?.createdBy, name);
      }
      // Trims whitespace.
      final id = await repo.createSet(title: 'T', createdBy: '  Mama  ');
      expect((await repo.getSetById(id))?.createdBy, 'Mama');
    });

    test('watchAllSets emits', () async {
      final setId = await repo.createSet(title: 'A', createdBy: 'parent');
      await expectLater(
        repo.watchAllSets(),
        emitsThrough(
          predicate<List<QuestionSet>>(
            (sets) => sets.any((s) => s.id == setId),
          ),
        ),
      );
    });
  });

  group('items CRUD + ordering', () {
    test('add/get ordered by position, update, delete', () async {
      final setId = await repo.createSet(title: 'S', createdBy: 'teacher');
      final a = await repo.addItem(
        setId: setId,
        type: 'choice',
        prompt: 'Hund',
        answer: 'dog',
        promptLang: 'de',
        answerLang: 'en',
        choices: const ['cat'],
      );
      await repo.addItem(
        setId: setId,
        type: 'phone',
        prompt: 'Mama',
        answer: '0171 123-4567',
      );
      var items = await repo.getItemsForSet(setId);
      expect(items.map((e) => e.id), [a, items[1].id]);
      expect(items[0].position, 0);
      expect(items[1].position, 1);
      // Phone stored normalised.
      expect(items[1].answer, '01711234567');

      await repo.updateItem(id: a, prompt: 'Hund!');
      expect((await repo.getItemById(a))?.prompt, 'Hund!');

      await repo.deleteItem(a);
      items = await repo.getItemsForSet(setId);
      expect(items, hasLength(1));
    });

    test('add validates type/prompt/answer/phone/date/language pair', () async {
      final setId = await repo.createSet(title: 'S', createdBy: 'teacher');
      expect(
        () => repo.addItem(
          setId: setId,
          type: 'grammar',
          prompt: 'p',
          answer: 'a',
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.addItem(
          setId: setId,
          type: 'choice',
          prompt: ' ',
          answer: 'a',
          promptLang: 'de',
          answerLang: 'en',
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.addItem(
          setId: setId,
          type: 'choice',
          prompt: 'p',
          answer: 'a',
          promptLang: 'de',
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.addItem(
          setId: setId,
          type: 'phone',
          prompt: 'p',
          answer: '12',
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.addItem(
          setId: setId,
          type: 'date',
          prompt: 'p',
          answer: '2030-01-01',
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.addItem(
          setId: setId,
          type: 'phone',
          prompt: 'p',
          answer: '0171',
          promptLang: 'de',
          answerLang: 'en',
        ),
        throwsArgumentError,
      );
    });

    test('choice accepts a language pair present or absent (#022); forbids '
        'an unpaired single language', () async {
      final setId = await repo.createSet(title: 'S', createdBy: 'teacher');
      final withoutPair = await repo.addItem(
        setId: setId,
        type: 'choice',
        prompt: 'Capital of France',
        answer: 'Paris',
      );
      final withoutPairItem = await repo.getItemById(withoutPair);
      expect(withoutPairItem?.promptLang, isNull);
      expect(withoutPairItem?.answerLang, isNull);

      final withPair = await repo.addItem(
        setId: setId,
        type: 'choice',
        prompt: 'Hund',
        answer: 'dog',
        promptLang: 'de',
        answerLang: 'en',
      );
      final withPairItem = await repo.getItemById(withPair);
      expect(withPairItem?.promptLang, 'de');
      expect(withPairItem?.answerLang, 'en');
    });

    test(
      'freeText accepts language pair present or absent; forbids choices',
      () async {
        final setId = await repo.createSet(title: 'S', createdBy: 'teacher');
        final withoutPair = await repo.addItem(
          setId: setId,
          type: 'freeText',
          prompt: 'p',
          answer: 'a',
        );
        final withoutPairItem = await repo.getItemById(withoutPair);
        expect(withoutPairItem?.promptLang, isNull);
        expect(withoutPairItem?.answerLang, isNull);

        final withPair = await repo.addItem(
          setId: setId,
          type: 'freeText',
          prompt: 'p',
          answer: 'a',
          promptLang: 'de',
          answerLang: 'en',
        );
        final withPairItem = await repo.getItemById(withPair);
        expect(withPairItem?.promptLang, 'de');
        expect(withPairItem?.answerLang, 'en');

        expect(
          () => repo.addItem(
            setId: setId,
            type: 'freeText',
            prompt: 'p',
            answer: 'a',
            choices: const ['x'],
          ),
          throwsArgumentError,
        );
      },
    );

    test('updateItem: switching type to choice/freeText never requires a '
        'language pair (#022); switching to phone/date clears it', () async {
      final setId = await repo.createSet(title: 'S', createdBy: 'teacher');
      final itemId = await repo.addItem(
        setId: setId,
        type: 'phone',
        prompt: 'p',
        answer: '0171234',
      );

      await repo.updateItem(id: itemId, type: 'choice');
      expect((await repo.getItemById(itemId))?.type, 'choice');
      expect((await repo.getItemById(itemId))?.promptLang, isNull);

      await repo.updateItem(
        id: itemId,
        languagePairUpdate: () => (promptLang: 'de', answerLang: 'en'),
      );
      expect((await repo.getItemById(itemId))?.promptLang, 'de');

      // Phone's own answer-format check still applies: the stored answer
      // ('0171234') is already phone-valid, so only the pair is cleared.
      await repo.updateItem(id: itemId, type: 'phone');
      expect((await repo.getItemById(itemId))?.type, 'phone');
      expect((await repo.getItemById(itemId))?.promptLang, isNull);
      expect((await repo.getItemById(itemId))?.answerLang, isNull);
    });

    test('reorder persists new positions; rejects mismatched ids', () async {
      final setId = await repo.createSet(title: 'S', createdBy: 'teacher');
      final ids = <int>[];
      for (var i = 0; i < 3; i++) {
        ids.add(
          await repo.addItem(
            setId: setId,
            type: 'phone',
            prompt: 'P$i',
            answer: '0171000$i',
          ),
        );
      }
      final reversed = ids.reversed.toList();
      await repo.reorderItems(setId, reversed);
      final items = await repo.getItemsForSet(setId);
      expect(items.map((e) => e.id).toList(), reversed);

      expect(() => repo.reorderItems(setId, [ids.first]), throwsArgumentError);
      expect(
        () => repo.reorderItems(setId, [...ids, 99999]),
        throwsArgumentError,
      );
    });

    test('watchItemsForSet emits in position order', () async {
      final setId = await repo.createSet(title: 'S', createdBy: 'teacher');
      final itemId = await repo.addItem(
        setId: setId,
        type: 'phone',
        prompt: 'P',
        answer: '0171',
      );
      await expectLater(
        repo.watchItemsForSet(setId),
        emitsThrough(
          predicate<List<Item>>(
            (items) => items.length == 1 && items.single.id == itemId,
          ),
        ),
      );
    });
  });

  group('cascade + duplicate', () {
    test('deleting a set cascades to items and attempts', () async {
      final setId = await repo.createSet(title: 'S', createdBy: 'teacher');
      final itemId = await repo.addItem(
        setId: setId,
        type: 'phone',
        prompt: 'P',
        answer: '0171',
      );
      await db
          .into(db.attempts)
          .insert(AttemptsCompanion.insert(itemId: itemId, ok: true, at: 1));

      await repo.deleteSet(setId);
      expect(await repo.getItemsForSet(setId), isEmpty);
      expect(
        await (db.select(
          db.attempts,
        )..where((t) => t.itemId.equals(itemId))).get(),
        isEmpty,
      );
    });

    test('deleting an item cascades to its attempts', () async {
      final setId = await repo.createSet(title: 'S', createdBy: 'teacher');
      final itemId = await repo.addItem(
        setId: setId,
        type: 'phone',
        prompt: 'P',
        answer: '0171',
      );
      await db
          .into(db.attempts)
          .insert(AttemptsCompanion.insert(itemId: itemId, ok: false, at: 1));
      await repo.deleteItem(itemId);
      expect(
        await (db.select(
          db.attempts,
        )..where((t) => t.itemId.equals(itemId))).get(),
        isEmpty,
      );
    });

    test('duplicateSet deep-copies with new ids and "(copy)" title', () async {
      final setId = await repo.createSet(
        title: 'Orig',
        description: 'd',
        createdBy: 'parent',
      );
      await repo.addItem(
        setId: setId,
        type: 'choice',
        prompt: 'Hund',
        answer: 'dog',
        promptLang: 'de',
        answerLang: 'en',
        choices: const ['cat'],
      );
      await repo.addItem(
        setId: setId,
        type: 'date',
        prompt: 'B',
        answer: '1985-05-14',
      );

      final copyId = await repo.duplicateSet(setId);
      expect(copyId, isNot(setId));
      final copy = await repo.getSetById(copyId);
      expect(copy?.title, 'Orig (copy)');
      final origItems = await repo.getItemsForSet(setId);
      final copyItems = await repo.getItemsForSet(copyId);
      expect(copyItems, hasLength(origItems.length));
      expect(
        copyItems.map((e) => e.id).toSet(),
        isNot(contains(origItems.first.id)),
      );
      expect(copyItems.map((e) => e.prompt), origItems.map((e) => e.prompt));
      expect(() => repo.duplicateSet(99999), throwsArgumentError);
    });
  });

  group('export/import round-trip', () {
    test('export produces valid v1 map; import creates new set', () async {
      final setId = await repo.createSet(
        title: 'Share',
        description: 'd',
        createdBy: 'teacher',
      );
      await repo.addItem(
        setId: setId,
        type: 'choice',
        prompt: 'Hund',
        answer: 'dog',
        promptLang: 'de',
        answerLang: 'en',
        choices: const ['cat', 'mouse'],
      );
      await repo.addItem(
        setId: setId,
        type: 'phone',
        prompt: 'Mama',
        answer: '01711234567',
      );
      await repo.addItem(
        setId: setId,
        type: 'date',
        prompt: 'B',
        answer: '1985-05-14',
      );

      final exported = await repo.exportSetToJson(setId, today: kTestToday);
      expect(exported['format'], 'foxstreak-set');
      expect(exported['version'], 1);

      final newId = await repo.importSetFromJson(exported, today: kTestToday);
      expect(newId, isNot(setId));
      final items = await repo.getItemsForSet(newId);
      expect(items, hasLength(3));
      // Re-export of the copy matches the original payload.
      final reExported = await repo.exportSetToJson(newId, today: kTestToday);
      expect(reExported['items'], exported['items']);
    });

    test('import rejects bad schema with SetImportException', () async {
      expect(
        () => repo.importSetFromJson({'format': 'x'}, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
      expect(
        () => repo.importSetFromJson({
          'format': 'foxstreak-set',
          'version': 99,
        }, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
      expect(
        () => repo.importSetFromJson({
          'format': 'foxstreak-set',
          'version': 1,
          'title': 'T',
          'createdBy': 'teacher',
          'items': [
            {'type': 'phone', 'prompt': 'P', 'answer': '1'},
          ],
        }, today: kTestToday),
        throwsA(isA<SetImportException>()),
      );
      // Failed import creates nothing.
      expect(await repo.getAllSets(), isEmpty);
    });

    test('import assigns positions in file order', () async {
      final id = await repo.importSetFromJson({
        'format': 'foxstreak-set',
        'version': 1,
        'title': 'T',
        'createdBy': 'learner',
        'items': [
          {'type': 'phone', 'prompt': 'A', 'answer': '111'},
          {'type': 'phone', 'prompt': 'B', 'answer': '222'},
        ],
      }, today: kTestToday);
      final items = await repo.getItemsForSet(id);
      expect(items.map((e) => e.prompt), ['A', 'B']);
      expect(items.map((e) => e.position), [0, 1]);
    });
  });

  group('timestamps', () {
    test('create/update touch updatedAt via clock', () async {
      clock.setNow(DateTime(2026, 10, 10, 10));
      final id = await repo.createSet(title: 'S', createdBy: 'teacher');
      var set = (await repo.getSetById(id))!;
      final created = set.updatedAt;

      clock.setNow(DateTime(2026, 10, 11, 10));
      await repo.updateSet(id: id, title: 'S2');
      set = (await repo.getSetById(id))!;
      expect(set.updatedAt, greaterThan(created));
    });
  });
}
