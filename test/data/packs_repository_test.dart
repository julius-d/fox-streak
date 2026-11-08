// Tests for PacksRepository and the pack rules of SetsRepository (issue
// #121): ordering, own-vs-downloaded rules, deletion, default pack, moves.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/packs_repository.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';

import 'test_helpers.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late PacksRepository packs;
  late SetsRepository sets;

  setUp(() {
    db = makeTestDb();
    clock = FakeClock(kTestToday);
    packs = PacksRepository(db, clock);
    sets = SetsRepository(db, clock);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertDownloadedPack(
    String title, {
    required String packId,
    required int downloadedAt,
  }) => db
      .into(db.packs)
      .insert(
        PacksCompanion.insert(
          title: title,
          createdAt: downloadedAt,
          sourceUrl: const Value('https://a.example/m.json'),
          sourcePackId: Value(packId),
          downloadedAt: Value(downloadedAt),
        ),
      );

  Future<int> makeSet(String title, {int? packId}) =>
      sets.createSet(title: title, createdBy: 'me', packId: packId);

  test('a fresh database has exactly one empty own pack "My sets"', () async {
    final all = await packs.getAllPacks();
    expect(all, hasLength(1));
    expect(all.single.title, 'My sets');
    expect(all.single.isOwn, isTrue);
    expect(await packs.countSets(all.single.id), 0);
  });

  group('ordering', () {
    test('own packs first by creation, then downloaded by download date, '
        'regardless of insertion order', () async {
      clock.setNow(DateTime(2026, 10, 12));
      final ownLater = await packs.createPack('Own later');
      final dlOld = await insertDownloadedPack(
        'Old download',
        packId: 'p1',
        downloadedAt: 1,
      );
      final dlNew = await insertDownloadedPack(
        'New download',
        packId: 'p2',
        downloadedAt: 2,
      );
      final defaultId = (await packs.getAllPacks()).first.id;

      final order = (await packs.getAllPacks()).map((p) => p.id).toList();
      expect(order, [defaultId, ownLater, dlOld, dlNew]);
    });

    test('does not reorder with usage', () async {
      final second = await packs.createPack('Second');
      final first = (await packs.getAllPacks()).first.id;
      await makeSet('A', packId: second);
      expect((await packs.getAllPacks()).map((p) => p.id), [first, second]);
    });
  });

  group('createPack / renamePack', () {
    test('trims the title and rejects blank ones', () async {
      final id = await packs.createPack('  Trip  ');
      expect((await packs.getPackById(id))!.title, 'Trip');
      expect(() => packs.createPack('   '), throwsArgumentError);
    });

    test('renames own packs', () async {
      final id = await packs.createPack('Old');
      await packs.renamePack(id, 'New');
      expect((await packs.getPackById(id))!.title, 'New');
    });

    test('downloaded packs cannot be renamed', () async {
      final id = await insertDownloadedPack(
        'Remote',
        packId: 'p',
        downloadedAt: 1,
      );
      await expectLater(packs.renamePack(id, 'Mine'), throwsArgumentError);
    });
  });

  group('deletePack', () {
    test('takes its sets (and items) with it', () async {
      final pack = await packs.createPack('Doomed');
      final setId = await makeSet('In doomed', packId: pack);
      await sets.addItem(
        setId: setId,
        type: 'freeText',
        prompt: 'a',
        answer: 'b',
        promptLang: 'en',
        answerLang: 'de',
      );
      final keptSet = await makeSet('Kept');

      expect(await packs.countSets(pack), 1);
      await packs.deletePack(pack);

      expect(await sets.getSetById(setId), isNull);
      expect(await sets.getSetById(keptSet), isNotNull);
      expect(await db.select(db.items).get(), isEmpty);
    });

    test('deleting the last pack recreates an empty "My sets"', () async {
      final only = (await packs.getAllPacks()).single;
      await makeSet('Gone soon');
      await packs.deletePack(only.id);

      final all = await packs.getAllPacks();
      expect(all, hasLength(1));
      expect(all.single.title, 'My sets');
      expect(all.single.id, isNot(only.id));
      expect(await sets.getAllSets(), isEmpty);
    });

    test('a downloaded pack can be deleted', () async {
      final id = await insertDownloadedPack('R', packId: 'p', downloadedAt: 1);
      await packs.deletePack(id);
      expect(await packs.getPackById(id), isNull);
    });
  });

  test('setCollapsed persists the collapse state', () async {
    final id = (await packs.getAllPacks()).single.id;
    expect((await packs.getPackById(id))!.collapsed, isFalse);
    await packs.setCollapsed(id, collapsed: true);
    expect((await packs.getPackById(id))!.collapsed, isTrue);
  });

  group('defaultOwnPackId', () {
    test('is the only pack when there is one', () async {
      final only = (await packs.getAllPacks()).single.id;
      expect(await packs.defaultOwnPackId(), only);
    });

    test('is the own pack that last received a set', () async {
      final other = await packs.createPack('Other');
      await makeSet('A');
      clock.setNow(kTestToday.add(const Duration(minutes: 1)));
      await makeSet('B', packId: other);
      expect(await packs.defaultOwnPackId(), other);
    });

    test('creates "My sets" when only downloaded packs exist', () async {
      await packs.deletePack((await packs.getAllPacks()).single.id);
      final dl = await insertDownloadedPack('R', packId: 'p', downloadedAt: 1);
      // Deleting the last (own) pack recreated one; remove it again.
      for (final p in await packs.getAllPacks()) {
        if (p.id != dl) await packs.deletePack(p.id);
      }
      expect((await packs.getAllPacks()).map((p) => p.id), [dl]);

      final id = await packs.defaultOwnPackId();
      final created = (await packs.getPackById(id))!;
      expect(created.isOwn, isTrue);
      expect(created.title, 'My sets');
    });
  });

  group('sets and packs', () {
    test('createSet defaults to the first own pack', () async {
      final defaultPack = (await packs.getAllPacks()).single.id;
      final id = await makeSet('A');
      expect((await sets.getSetById(id))!.packId, defaultPack);
    });

    test('createSet rejects downloaded and unknown packs', () async {
      final dl = await insertDownloadedPack('R', packId: 'p', downloadedAt: 1);
      await expectLater(makeSet('A', packId: dl), throwsArgumentError);
      await expectLater(makeSet('A', packId: 9999), throwsArgumentError);
    });

    test('importSetFromJson lands in the chosen pack', () async {
      final target = await packs.createPack('Target');
      final id = await sets.importSetFromJson({
        'format': 'foxstreak-set',
        'version': 1,
        'title': 'Imported',
        'createdBy': 'me',
        'items': <Map<String, dynamic>>[],
      }, packId: target);
      expect((await sets.getSetById(id))!.packId, target);
    });

    test('exported sets carry no pack info', () async {
      final id = await makeSet('A');
      final json = await sets.exportSetToJson(id);
      expect(json.keys, isNot(contains('packId')));
      expect(json.keys, isNot(contains('pack')));
    });

    test('duplicateSet stays in the source pack', () async {
      final other = await packs.createPack('Other');
      final id = await makeSet('A', packId: other);
      final copy = await sets.duplicateSet(id);
      expect((await sets.getSetById(copy))!.packId, other);
    });

    test(
      'duplicating a downloaded set yields an own set in an own pack',
      () async {
        final dl = await insertDownloadedPack(
          'R',
          packId: 'p',
          downloadedAt: 1,
        );
        final remote = await sets.importSetFromJson({
          'format': 'foxstreak-set',
          'version': 1,
          'title': 'Remote',
          'createdBy': 'x',
          'items': <Map<String, dynamic>>[],
        }, packId: dl);
        final copy = await sets.duplicateSet(remote);
        final copyPack = (await packs.getPackById(
          (await sets.getSetById(copy))!.packId,
        ))!;
        expect(copyPack.isOwn, isTrue);
      },
    );

    test('moveSetToPack moves between own packs', () async {
      final other = await packs.createPack('Other');
      final id = await makeSet('A');
      final before = (await sets.getSetById(id))!;
      await sets.moveSetToPack(id, other);
      final after = (await sets.getSetById(id))!;
      expect(after.packId, other);
      // A move is not an edit.
      expect(after.updatedAt, before.updatedAt);
    });

    test('moveSetToPack refuses downloaded targets and sources', () async {
      final dl = await insertDownloadedPack('R', packId: 'p', downloadedAt: 1);
      final own = await makeSet('A');
      await expectLater(sets.moveSetToPack(own, dl), throwsArgumentError);

      final downloadedSet = await sets.importSetFromJson({
        'format': 'foxstreak-set',
        'version': 1,
        'title': 'Remote set',
        'createdBy': 'x',
        'items': <Map<String, dynamic>>[],
      }, packId: dl);
      final ownPack = (await packs.getAllPacks()).first.id;
      await expectLater(
        sets.moveSetToPack(downloadedSet, ownPack),
        throwsArgumentError,
      );
    });
  });

  test('the same (source, pack id) cannot exist twice', () async {
    await insertDownloadedPack('R', packId: 'p', downloadedAt: 1);
    await expectLater(
      insertDownloadedPack('R again', packId: 'p', downloadedAt: 2),
      throwsA(anything),
    );
  });
}
