// Tests for MarketplaceRepository (issue #101): sources CRUD, import
// status, and the import/update orchestration on top of SetsRepository —
// in particular the item-matching logic that keeps attempt history for
// items that still match by their marketplace `id`.

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/marketplace_repository.dart';
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
}
