// Tests for MarketplaceRepository (issue #101): sources CRUD, import
// status, and the import/update orchestration on top of SetsRepository —
// in particular the item-matching logic that keeps attempt history for
// items that still match by their marketplace `id`.

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/marketplace_repository.dart';
import 'package:fox_streak_app/src/data/packs_repository.dart';
import 'package:fox_streak_app/src/data/set_json_codec.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';

import 'test_helpers.dart';

Map<String, dynamic> _setJson({
  required String title,
  String createdBy = 'teacher',
  String? description,
  List<Map<String, dynamic>> items = const [],
}) => {
  'format': 'foxstreak-set',
  'version': 1,
  'title': title,
  'createdBy': createdBy,
  'description': ?description,
  'items': items,
};

Map<String, dynamic> _phoneItem({
  required String prompt,
  required String answer,
  String? id,
}) => {'type': 'phone', 'prompt': prompt, 'answer': answer, 'id': ?id};

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late SetsRepository setsRepo;
  late MarketplaceRepository marketplaceRepo;

  setUp(() {
    db = makeTestDb();
    clock = FakeClock(kTestToday);
    setsRepo = SetsRepository(db, clock);
    marketplaceRepo = MarketplaceRepository(db, setsRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('sources', () {
    test(
      'addSource stores url + name; watchSources emits them ordered',
      () async {
        await marketplaceRepo.addSource(
          url: 'https://a.example/marketplace.json',
          name: 'A',
        );
        await marketplaceRepo.addSource(
          url: 'https://b.example/marketplace.json',
          name: 'B',
        );
        final sources = await marketplaceRepo.watchSources().first;
        expect(sources.map((s) => s.name), ['A', 'B']);
        expect(sources.map((s) => s.url), [
          'https://a.example/marketplace.json',
          'https://b.example/marketplace.json',
        ]);
      },
    );

    test('addSource rejects a duplicate url', () async {
      await marketplaceRepo.addSource(
        url: 'https://a.example/marketplace.json',
        name: 'A',
      );
      expect(
        () => marketplaceRepo.addSource(
          url: 'https://a.example/marketplace.json',
          name: 'A again',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('removeSource deletes it', () async {
      final id = await marketplaceRepo.addSource(
        url: 'https://a.example/marketplace.json',
        name: 'A',
      );
      await marketplaceRepo.removeSource(id);
      expect(await marketplaceRepo.watchSources().first, isEmpty);
    });
  });

  group('importStateFor', () {
    test('notImported when the triple was never imported', () async {
      final state = await marketplaceRepo.importStateFor(
        sourceUrl: 'https://a.example/marketplace.json',
        packId: 'pack-1',
        setId: 'set-1',
        listingUpdatedAt: '2026-10-01',
      );
      expect(state.status, MarketplaceSetStatus.notImported);
      expect(state.localSetId, isNull);
    });

    test('upToDate right after import; updateAvailable once the listing '
        'updatedAt changes', () async {
      final localSetId = await marketplaceRepo.importSet(
        localPackId: 1,
        sourceUrl: 'https://a.example/marketplace.json',
        packId: 'pack-1',
        setId: 'set-1',
        listingUpdatedAt: '2026-10-01',
        setJson: _setJson(title: 'Animals'),
      );

      final upToDate = await marketplaceRepo.importStateFor(
        sourceUrl: 'https://a.example/marketplace.json',
        packId: 'pack-1',
        setId: 'set-1',
        listingUpdatedAt: '2026-10-01',
      );
      expect(upToDate.status, MarketplaceSetStatus.upToDate);
      expect(upToDate.localSetId, localSetId);

      final updateAvailable = await marketplaceRepo.importStateFor(
        sourceUrl: 'https://a.example/marketplace.json',
        packId: 'pack-1',
        setId: 'set-1',
        listingUpdatedAt: '2026-11-01',
      );
      expect(updateAvailable.status, MarketplaceSetStatus.updateAvailable);
      expect(updateAvailable.localSetId, localSetId);
    });
  });

  group('importSet', () {
    test('creates a new local set via SetsRepository and records the '
        'mapping', () async {
      final localSetId = await marketplaceRepo.importSet(
        localPackId: 1,
        sourceUrl: 'https://a.example/marketplace.json',
        packId: 'pack-1',
        setId: 'set-1',
        listingUpdatedAt: '2026-10-01',
        setJson: _setJson(
          title: 'Animals',
          items: [_phoneItem(prompt: 'Mama', answer: '111')],
        ),
      );
      final set = await setsRepo.getSetById(localSetId);
      expect(set?.title, 'Animals');
      expect(await setsRepo.getItemsForSet(localSetId), hasLength(1));

      expect(await marketplaceRepo.isLocallyEdited(localSetId), isFalse);
    });
  });

  group('isLocallyEdited', () {
    test('becomes true once the local set is edited after import', () async {
      final localSetId = await marketplaceRepo.importSet(
        localPackId: 1,
        sourceUrl: 'https://a.example/marketplace.json',
        packId: 'pack-1',
        setId: 'set-1',
        listingUpdatedAt: '2026-10-01',
        setJson: _setJson(title: 'Animals'),
      );
      expect(await marketplaceRepo.isLocallyEdited(localSetId), isFalse);

      clock.setNow(kTestToday.add(const Duration(days: 1)));
      await setsRepo.updateSet(id: localSetId, title: 'Animals (edited)');
      expect(await marketplaceRepo.isLocallyEdited(localSetId), isTrue);
    });
  });

  group('updateSet', () {
    test('matched items (by marketplace id) are updated in place, keeping '
        'their attempt history; unmatched new items start fresh; dropped '
        'items are removed', () async {
      final localSetId = await marketplaceRepo.importSet(
        localPackId: 1,
        sourceUrl: 'https://a.example/marketplace.json',
        packId: 'pack-1',
        setId: 'set-1',
        listingUpdatedAt: '2026-10-01',
        setJson: _setJson(
          title: 'Animals',
          items: [
            _phoneItem(
              prompt: 'Mama',
              answer: '111',
              id: 'a1b2c3d4-0000-4000-8000-000000000001',
            ),
            _phoneItem(
              prompt: 'Papa',
              answer: '222',
              id: 'a1b2c3d4-0000-4000-8000-000000000002',
            ),
          ],
        ),
      );
      final originalItems = await setsRepo.getItemsForSet(localSetId);
      final keptItemDbId = originalItems[0].id;
      final droppedItemDbId = originalItems[1].id;

      // Record practice history on the item that will be kept.
      await db
          .into(db.attempts)
          .insert(
            AttemptsCompanion.insert(itemId: keptItemDbId, ok: true, at: 0),
          );

      await marketplaceRepo.updateSet(
        localSetId: localSetId,
        sourceUrl: 'https://a.example/marketplace.json',
        packId: 'pack-1',
        setId: 'set-1',
        listingUpdatedAt: '2026-11-01',
        setJson: _setJson(
          title: 'Animals',
          items: [
            // Same id, changed content: updated in place.
            _phoneItem(
              prompt: 'Mama (updated)',
              answer: '999',
              id: 'a1b2c3d4-0000-4000-8000-000000000001',
            ),
            // New id: inserted fresh.
            _phoneItem(
              prompt: 'Oma',
              answer: '333',
              id: 'a1b2c3d4-0000-4000-8000-000000000003',
            ),
            // No id at all: also a fresh item.
            _phoneItem(prompt: 'Opa', answer: '444'),
          ],
        ),
      );

      final updatedItems = await setsRepo.getItemsForSet(localSetId);
      expect(updatedItems, hasLength(3));

      // The matched item kept its DB id (so its attempt history survives).
      final matched = updatedItems.firstWhere((i) => i.id == keptItemDbId);
      expect(matched.prompt, 'Mama (updated)');
      expect(matched.answer, '999');
      final attempts = await (db.select(
        db.attempts,
      )..where((t) => t.itemId.equals(keptItemDbId))).get();
      expect(attempts, hasLength(1));

      // The dropped item (no match in the new version) is gone, cascading
      // away its own attempts.
      expect(updatedItems.any((i) => i.id == droppedItemDbId), isFalse);

      // New items (matched-by-new-id or no-id-at-all) are present with no
      // attempt history.
      expect(updatedItems.map((i) => i.prompt), containsAll(['Oma', 'Opa']));
      for (final item in updatedItems.where((i) => i.id != keptItemDbId)) {
        final itemAttempts = await (db.select(
          db.attempts,
        )..where((t) => t.itemId.equals(item.id))).get();
        expect(itemAttempts, isEmpty);
      }

      // Title/mapping are updated too.
      expect((await setsRepo.getSetById(localSetId))?.title, 'Animals');
      final state = await marketplaceRepo.importStateFor(
        sourceUrl: 'https://a.example/marketplace.json',
        packId: 'pack-1',
        setId: 'set-1',
        listingUpdatedAt: '2026-11-01',
      );
      expect(state.status, MarketplaceSetStatus.upToDate);
    });

    test('preserves item order from the new Set JSON', () async {
      final localSetId = await marketplaceRepo.importSet(
        localPackId: 1,
        sourceUrl: 'https://a.example/marketplace.json',
        packId: 'pack-1',
        setId: 'set-1',
        listingUpdatedAt: '2026-10-01',
        setJson: _setJson(
          title: 'Animals',
          items: [
            _phoneItem(
              prompt: 'A',
              answer: '111',
              id: 'a1b2c3d4-0000-4000-8000-000000000001',
            ),
            _phoneItem(
              prompt: 'B',
              answer: '222',
              id: 'a1b2c3d4-0000-4000-8000-000000000002',
            ),
          ],
        ),
      );

      await marketplaceRepo.updateSet(
        localSetId: localSetId,
        sourceUrl: 'https://a.example/marketplace.json',
        packId: 'pack-1',
        setId: 'set-1',
        listingUpdatedAt: '2026-11-01',
        setJson: _setJson(
          title: 'Animals',
          items: [
            // Reversed order vs. the original import.
            _phoneItem(
              prompt: 'B',
              answer: '222',
              id: 'a1b2c3d4-0000-4000-8000-000000000002',
            ),
            _phoneItem(
              prompt: 'A',
              answer: '111',
              id: 'a1b2c3d4-0000-4000-8000-000000000001',
            ),
          ],
        ),
      );

      final items = await setsRepo.getItemsForSet(localSetId);
      expect(items.map((i) => i.prompt), ['B', 'A']);
    });
  });

  group('packs (#121)', () {
    const source = 'https://a.example/marketplace.json';

    FetchedMarketplaceSet fetched(
      String setId,
      String title, {
      String updatedAt = '2026-10-01',
      List<Map<String, dynamic>> items = const [],
    }) => FetchedMarketplaceSet(
      setId: setId,
      listingUpdatedAt: updatedAt,
      json: _setJson(title: title, items: items),
    );

    Future<int> download({
      List<FetchedMarketplaceSet>? sets,
      String packId = 'pack-1',
    }) => marketplaceRepo.downloadPack(
      sourceUrl: source,
      packId: packId,
      title: 'Animals pack',
      description: 'All the animals',
      sets: sets ?? [fetched('s1', 'Dogs'), fetched('s2', 'Cats')],
    );

    Future<MarketplacePackState> stateFor(Map<String, String> listed) =>
        marketplaceRepo.packStateFor(
          sourceUrl: source,
          packId: 'pack-1',
          listedSets: listed,
        );

    test('downloadPack creates a downloaded pack with all its sets', () async {
      final packId = await download();

      final pack = (await db.select(db.packs).get()).singleWhere(
        (p) => p.id == packId,
      );
      expect(pack.title, 'Animals pack');
      expect(pack.description, 'All the animals');
      expect(pack.sourceUrl, source);
      expect(pack.sourcePackId, 'pack-1');
      final sets = (await setsRepo.getAllSets()).where(
        (s) => s.packId == packId,
      );
      expect(sets.map((s) => s.title), ['Dogs', 'Cats']);
      expect(
        (await stateFor({'s1': '2026-10-01', 's2': '2026-10-01'})).status,
        MarketplacePackStatus.upToDate,
      );
    });

    test('is never downloaded twice into two local packs', () async {
      await download();
      await expectLater(download(), throwsStateError);
      final downloaded = (await db.select(db.packs).get()).where(
        (p) => p.sourceUrl != null,
      );
      expect(downloaded, hasLength(1));
    });

    test('a failing set rolls the whole download back', () async {
      final packsBefore = await db.select(db.packs).get();
      final setsBefore = await setsRepo.getAllSets();

      await expectLater(
        download(
          sets: [
            fetched('s1', 'Dogs'),
            const FetchedMarketplaceSet(
              setId: 's2',
              listingUpdatedAt: '2026-10-01',
              json: {'format': 'nonsense'},
            ),
          ],
        ),
        throwsA(isA<SetImportException>()),
      );

      expect(await db.select(db.packs).get(), hasLength(packsBefore.length));
      expect(await setsRepo.getAllSets(), hasLength(setsBefore.length));
      expect(await db.select(db.importedMarketplaceSets).get(), isEmpty);
      expect(
        (await stateFor({'s1': 'x'})).status,
        MarketplacePackStatus.notDownloaded,
      );
      // Retry succeeds.
      await download();
    });

    group('packStateFor', () {
      test('notDownloaded before any download', () async {
        final state = await stateFor({'s1': '2026-10-01'});
        expect(state.status, MarketplacePackStatus.notDownloaded);
        expect(state.localPackId, isNull);
      });

      test('updateAvailable when a set changed or a new set appeared; '
          'sets removed upstream are ignored', () async {
        final packId = await download();
        final listed = {'s1': '2026-10-01', 's2': '2026-10-01'};

        expect(
          (await stateFor({...listed, 's2': '2026-11-01'})).status,
          MarketplacePackStatus.updateAvailable,
        );
        final withNew = await stateFor({...listed, 's3': '2026-10-01'});
        expect(withNew.status, MarketplacePackStatus.updateAvailable);
        expect(withNew.localPackId, packId);
        expect(
          (await stateFor({'s1': '2026-10-01'})).status,
          MarketplacePackStatus.upToDate,
        );
      });

      test('deleting the downloaded pack makes it new again', () async {
        final packId = await download();
        await PacksRepository(db, clock).deletePack(packId);
        expect(
          (await stateFor({'s1': '2026-10-01'})).status,
          MarketplacePackStatus.notDownloaded,
        );
        await download(); // allowed again
      });
    });

    test('syncPackMeta refreshes title and description', () async {
      final packId = await download();
      await marketplaceRepo.syncPackMeta(
        sourceUrl: source,
        packId: 'pack-1',
        title: 'Renamed upstream',
        description: 'New text',
      );
      final pack = (await db.select(db.packs).get()).singleWhere(
        (p) => p.id == packId,
      );
      expect(pack.title, 'Renamed upstream');
      expect(pack.description, 'New text');
    });

    group('updatePack', () {
      test('updates changed sets, adds new ones, keeps sets removed '
          'upstream and follows the pack title', () async {
        final packId = await download();

        await marketplaceRepo.updatePack(
          sourceUrl: source,
          packId: 'pack-1',
          title: 'Animals v2',
          description: 'More',
          sets: [
            fetched('s1', 'Dogs v2', updatedAt: '2026-11-01'),
            fetched('s3', 'Birds', updatedAt: '2026-11-01'),
          ],
        );

        final inPack = (await setsRepo.getAllSets()).where(
          (s) => s.packId == packId,
        );
        expect(inPack.map((s) => s.title), ['Dogs v2', 'Cats', 'Birds']);
        final pack = (await db.select(db.packs).get()).singleWhere(
          (p) => p.id == packId,
        );
        expect(pack.title, 'Animals v2');
        expect(pack.description, 'More');
        expect(
          (await stateFor({'s1': '2026-11-01', 's3': '2026-11-01'})).status,
          MarketplacePackStatus.upToDate,
        );
      });

      test('skipped (locally edited) sets stay untouched', () async {
        final packId = await download();
        final dogs = (await setsRepo.getAllSets()).firstWhere(
          (s) => s.title == 'Dogs',
        );
        clock.setNow(kTestToday.add(const Duration(hours: 1)));
        await setsRepo.updateSet(id: dogs.id, title: 'My dogs');

        final edited = await marketplaceRepo.locallyEditedSets(
          sourceUrl: source,
          packId: 'pack-1',
          setIds: ['s1', 's2'],
        );
        expect(edited.map((e) => e.setId), ['s1']);
        expect(edited.single.set.title, 'My dogs');

        await marketplaceRepo.updatePack(
          sourceUrl: source,
          packId: 'pack-1',
          title: 'Animals pack',
          description: '',
          skipSetIds: {'s1'},
          sets: [
            fetched('s1', 'Dogs v2', updatedAt: '2026-11-01'),
            fetched('s2', 'Cats v2', updatedAt: '2026-11-01'),
          ],
        );

        final titles = (await setsRepo.getAllSets())
            .where((s) => s.packId == packId)
            .map((s) => s.title);
        expect(titles, ['My dogs', 'Cats v2']);
        // The skipped set is still outdated, so the pack still offers it.
        expect(
          (await stateFor({'s1': '2026-11-01', 's2': '2026-11-01'})).status,
          MarketplacePackStatus.updateAvailable,
        );
      });

      test('a failing set leaves already-downloaded sets intact', () async {
        final packId = await download();
        await expectLater(
          marketplaceRepo.updatePack(
            sourceUrl: source,
            packId: 'pack-1',
            title: 'Changed title',
            description: '',
            sets: [
              fetched('s1', 'Dogs v2', updatedAt: '2026-11-01'),
              const FetchedMarketplaceSet(
                setId: 's2',
                listingUpdatedAt: '2026-11-01',
                json: {'format': 'nonsense'},
              ),
            ],
          ),
          throwsA(isA<SetImportException>()),
        );

        final titles = (await setsRepo.getAllSets())
            .where((s) => s.packId == packId)
            .map((s) => s.title);
        expect(titles, ['Dogs', 'Cats']);
        final pack = (await db.select(db.packs).get()).singleWhere(
          (p) => p.id == packId,
        );
        expect(pack.title, 'Animals pack');
      });
    });
  });
}
