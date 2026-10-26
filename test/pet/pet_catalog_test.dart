// Unit tests for the pet catalog (issue #059; replaced by issue #069's
// static hardcoded list).
//
// Covers: the static catalog's shape (11 entries, `sortOrder`-ascending,
// fox first, folder <-> catalog sync), the Noto Emoji hex-codepoint decode
// (including a multi-codepoint ZWJ sequence) and its consistency with each
// entry's literal `emoji`, [PetRarity]'s fixed weights, [PetEntry]'s
// seasonal/rarity-key/equality behavior, and [drawPet]'s weighted draw
// (including the empty-tier redistribution fallback).

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';

/// A fully scripted "random": [intQueue] answers successive `nextInt(max)`
/// calls in order (looping once exhausted) regardless of [max] — lets a
/// test force [drawPet]'s tier-then-within-tier draw deterministically.
class _QueueRandom implements Random {
  _QueueRandom(this.intQueue);

  final List<int> intQueue;
  int _next = 0;

  @override
  int nextInt(int max) {
    final value = intQueue[_next % intQueue.length];
    _next++;
    return value;
  }

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

void main() {
  group('PetCatalog.entries', () {
    test('has exactly the 11 real collectible pets', () {
      expect(PetCatalog.entries, hasLength(11));
      expect(PetCatalog.entries.map((e) => e.id), contains(kDefaultPetId));
    });

    test('every entry has a unique id and a well-formed asset path', () {
      final ids = PetCatalog.entries.map((e) => e.id).toSet();
      expect(ids, hasLength(PetCatalog.entries.length));
      for (final entry in PetCatalog.entries) {
        expect(entry.assetPath, '$kPetAssetDir${entry.id}.json');
      }
    });

    test('every entry\'s emoji matches its id\'s decoded codepoint(s)', () {
      for (final entry in PetCatalog.entries) {
        expect(entry.emoji, decodePetEmoji(entry.id));
      }
    });

    test('is already ordered by sortOrder ascending, fox first', () {
      final sortOrders = PetCatalog.entries.map((e) => e.sortOrder).toList();
      expect(sortOrders, List<int>.generate(sortOrders.length, (i) => i));
      expect(PetCatalog.entries.first.id, kDefaultPetId);
    });

    test('exactly the spider and snowman are seasonal; everything else is '
        'winnable year-round', () {
      final seasonalIds = PetCatalog.entries
          .where((e) => e.isSeasonal)
          .map((e) => e.id)
          .toSet();
      expect(seasonalIds, {'emoji_u1f577_lottie', 'emoji_u2603_lottie'});
    });

    test('a seasonal entry draws at Common odds but labels as "seasonal", '
        'never its rarity enum name', () {
      final spider = petEntryForId('emoji_u1f577_lottie');
      expect(spider.rarity, PetRarity.common);
      expect(spider.rarityKey, 'seasonal');
    });

    test('a non-seasonal entry\'s rarityKey is its rarity enum name', () {
      final fox = PetCatalog.defaultEntry;
      expect(fox.rarity, PetRarity.common);
      expect(fox.rarityKey, 'common');
    });

    test('every assets/noto-emoji/pet/*_lottie.json file has a matching '
        'catalog entry, and vice versa', () {
      final fileIds = Directory(kPetAssetDir)
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.endsWith('_lottie.json'))
          .map((name) => name.substring(0, name.length - '.json'.length))
          .toSet();
      final catalogIds = PetCatalog.entries.map((e) => e.id).toSet();
      expect(fileIds, catalogIds);
    });
  });

  group('PetCatalog.load', () {
    test('returns the full static entries list', () async {
      expect(await PetCatalog.load(), PetCatalog.entries);
    });
  });

  group('decodePetEmoji', () {
    test('decodes a single-codepoint id (fox)', () {
      expect(decodePetEmoji('emoji_u1f98a_lottie'), '🦊');
    });

    test('decodes a multi-codepoint ZWJ sequence (fire bird)', () {
      expect(decodePetEmoji('emoji_u1f426_200d_1f525_lottie'), '🐦‍🔥');
    });
  });

  group('PetCatalog.defaultEntry', () {
    test('is the fox, with sortOrder 0 and Common rarity', () {
      expect(PetCatalog.defaultEntry.id, kDefaultPetId);
      expect(PetCatalog.defaultEntry.emoji, '🦊');
      expect(PetCatalog.defaultEntry.sortOrder, 0);
      expect(PetCatalog.defaultEntry.rarity, PetRarity.common);
      expect(
        PetCatalog.defaultEntry.assetPath,
        '${kPetAssetDir}emoji_u1f98a_lottie.json',
      );
    });
  });

  group('petEntryForId', () {
    test('looks up a real catalog entry by id', () {
      expect(petEntryForId('emoji_u1f996_lottie').emoji, '🦖'); // T-Rex
    });
  });

  group('PetRarity.weight', () {
    test('the five tiers sum to 100', () {
      final total = PetRarity.values.fold(0, (sum, r) => sum + r.weight);
      expect(total, 100);
    });

    test('matches the fixed table: 55/30/10/4/1', () {
      expect(PetRarity.common.weight, 55);
      expect(PetRarity.uncommon.weight, 30);
      expect(PetRarity.epic.weight, 10);
      expect(PetRarity.legendary.weight, 4);
      expect(PetRarity.mythic.weight, 1);
    });
  });

  group('PetEntry equality', () {
    test('two entries with the same id are equal regardless of other '
        'fields', () {
      const a = PetEntry(
        id: 'x',
        assetPath: 'a.json',
        emoji: '🦊',
        rarity: PetRarity.common,
        sortOrder: 0,
      );
      const b = PetEntry(
        id: 'x',
        assetPath: 'b.json',
        emoji: '🦖',
        rarity: PetRarity.mythic,
        sortOrder: 1,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('entries with different ids are not equal', () {
      const a = PetEntry(
        id: 'x',
        assetPath: 'a.json',
        emoji: '🦊',
        rarity: PetRarity.common,
        sortOrder: 0,
      );
      const b = PetEntry(
        id: 'y',
        assetPath: 'a.json',
        emoji: '🦊',
        rarity: PetRarity.common,
        sortOrder: 1,
      );
      expect(a, isNot(b));
    });
  });

  group('PetEntry.isInSeasonAt', () {
    test('a pet with no seasonal window is always in season', () {
      expect(
        PetCatalog.defaultEntry.isInSeasonAt(DateTime(2026, 1, 1)),
        isTrue,
      );
      expect(
        petEntryForId('emoji_u1f416_lottie') // pig
            .isInSeasonAt(DateTime(2026, 7, 4)),
        isTrue,
      );
      expect(
        petEntryForId('emoji_u1f425_lottie') // chick
            .isInSeasonAt(DateTime(2026, 7, 4)),
        isTrue,
      );
    });

    test('snowman (Dec 6-26) excludes Dec 5 and Dec 27', () {
      final snowman = petEntryForId('emoji_u2603_lottie');
      expect(snowman.isInSeasonAt(DateTime(2026, 12, 5)), isFalse);
      expect(snowman.isInSeasonAt(DateTime(2026, 12, 27)), isFalse);
    });

    test('snowman (Dec 6-26) includes Dec 6 and Dec 26', () {
      final snowman = petEntryForId('emoji_u2603_lottie');
      expect(snowman.isInSeasonAt(DateTime(2026, 12, 6)), isTrue);
      expect(snowman.isInSeasonAt(DateTime(2026, 12, 26)), isTrue);
    });

    test('spider (Oct 25 - Nov 1) excludes Oct 24 and Nov 2', () {
      final spider = petEntryForId('emoji_u1f577_lottie');
      expect(spider.isInSeasonAt(DateTime(2026, 10, 24)), isFalse);
      expect(spider.isInSeasonAt(DateTime(2026, 11, 2)), isFalse);
    });

    test('spider (Oct 25 - Nov 1) includes Oct 25 and Nov 1', () {
      final spider = petEntryForId('emoji_u1f577_lottie');
      expect(spider.isInSeasonAt(DateTime(2026, 10, 25)), isTrue);
      expect(spider.isInSeasonAt(DateTime(2026, 11, 1)), isTrue);
    });

    test('the year is ignored (window recurs every year)', () {
      final snowman = petEntryForId('emoji_u2603_lottie');
      expect(snowman.isInSeasonAt(DateTime(1999, 12, 15)), isTrue);
      expect(snowman.isInSeasonAt(DateTime(2099, 12, 15)), isTrue);
    });
  });

  group('drawPet', () {
    const common1 = PetEntry(
      id: 'c1',
      assetPath: 'c1.json',
      emoji: '🐇',
      rarity: PetRarity.common,
      sortOrder: 0,
    );
    const common2 = PetEntry(
      id: 'c2',
      assetPath: 'c2.json',
      emoji: '🐝',
      rarity: PetRarity.common,
      sortOrder: 1,
    );
    const uncommon = PetEntry(
      id: 'u1',
      assetPath: 'u1.json',
      emoji: '🦀',
      rarity: PetRarity.uncommon,
      sortOrder: 2,
    );
    const epic = PetEntry(
      id: 'e1',
      assetPath: 'e1.json',
      emoji: '🦖',
      rarity: PetRarity.epic,
      sortOrder: 3,
    );
    const legendary = PetEntry(
      id: 'l1',
      assetPath: 'l1.json',
      emoji: '🐉',
      rarity: PetRarity.legendary,
      sortOrder: 4,
    );
    const mythic = PetEntry(
      id: 'm1',
      assetPath: 'm1.json',
      emoji: '🐦‍🔥',
      rarity: PetRarity.mythic,
      sortOrder: 5,
    );
    final fullPool = [common1, common2, uncommon, epic, legendary, mythic];

    test('a draw landing in the common tier\'s weight range (0..54) '
        'returns a common pet, split evenly by within-tier index', () {
      // Tier-select draw 0 lands in common (weight 55); within-tier draw 1
      // picks the 2nd of the 2 common pets.
      final won = drawPet(fullPool, _QueueRandom([0, 1]));
      expect(won, common2);
    });

    test('a draw landing just past the common tier\'s weight lands on '
        'uncommon', () {
      // Tier-select draw 55 is the first uncommon-tier value (common ends
      // at 54); within-tier draw 0 picks the (only) uncommon pet.
      final won = drawPet(fullPool, _QueueRandom([55, 0]));
      expect(won, uncommon);
    });

    test('a draw landing on the epic/legendary/mythic tiers returns the '
        'matching tier\'s pet', () {
      // Cumulative bounds: common 0-54, uncommon 55-84, epic 85-94,
      // legendary 95-98, mythic 99.
      expect(drawPet(fullPool, _QueueRandom([85, 0])), epic);
      expect(drawPet(fullPool, _QueueRandom([95, 0])), legendary);
      expect(drawPet(fullPool, _QueueRandom([99, 0])), mythic);
    });

    test('empty-tier redistribution: a pool with no legendary pet never '
        'draws into that gap — a tier-select draw that would have landed '
        'on legendary instead resolves within the tiers that do have a '
        'pet', () {
      final poolWithoutLegendary = [common1, common2, uncommon, epic, mythic];
      // Present tiers sum to 55 + 30 + 10 + 1 = 96 (legendary's 4 dropped
      // entirely), so every draw in 0..95 resolves to one of them.
      for (var draw = 0; draw < 96; draw++) {
        final won = drawPet(poolWithoutLegendary, _QueueRandom([draw, 0]));
        expect(won.rarity, isNot(PetRarity.legendary));
      }
    });

    test('a single-tier pool always returns from that tier, regardless of '
        'the tier-select draw', () {
      final onlyCommon = [common1, common2];
      for (var draw = 0; draw < 55; draw++) {
        final won = drawPet(onlyCommon, _QueueRandom([draw, 0]));
        expect(won, common1);
      }
    });

    test('distribution sanity: over many seeded trials, common pets are '
        'drawn far more often than mythic, matching the 55:1 weight '
        'ratio', () {
      final random = Random(42);
      var commonCount = 0;
      var mythicCount = 0;
      for (var i = 0; i < 5000; i++) {
        final won = drawPet(fullPool, random);
        if (won.rarity == PetRarity.common) commonCount++;
        if (won.rarity == PetRarity.mythic) mythicCount++;
      }
      expect(commonCount, greaterThan(mythicCount * 10));
    });
  });
}
