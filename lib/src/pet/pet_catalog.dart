// Pet catalog (issue #059; replaced by issue #069's static hardcoded list,
// which reverses the original runtime `AssetManifest` folder-scan design).
//
// Stable ID = filename stem (e.g. `emoji_u1f98a_lottie` for
// `emoji_u1f98a_lottie.json`), used as the primary/foreign key everywhere
// (owned-pets table, equipped-pet column) instead of an array index, so a
// future catalog edit never shifts IDs already persisted in the database.
//
// No per-pet l10n names: Noto Emoji filenames encode the Unicode
// codepoint(s) in hex (e.g. `u1f98a` -> 🦊); [decodePetEmoji] decodes
// that back into the literal emoji character, used as both the visible
// label and the a11y/semantic label via the generic `petSemanticLabel`
// arb template.
//
// v#069: every pet carries a fixed [PetRarity] draw-weight tier, an
// explicit [PetEntry.sortOrder], and (for the two seasonal pets) a
// [PetSeasonWindow] folded directly into its own entry — adding a pet from
// here on means adding an entry to [PetCatalog.entries], not just dropping
// a Lottie file into `assets/noto-emoji/pet/`.
import 'dart:math';

/// Directory holding every collectible pet's Lottie animation. Sibling to
/// `assets/noto-emoji/other/` (non-collectible effect animations) and
/// `assets/noto-emoji/attribution.md`, neither of which belongs in the
/// catalog.
const String kPetAssetDir = 'assets/noto-emoji/pet/';

/// Every profile starts owning and equipped with exactly this pet (🦊),
/// matching the existing fox branding.
const String kDefaultPetId = 'emoji_u1f98a_lottie';

/// A pet's draw-weight tier (issue #069), each with a fixed share of a
/// lootbox's pet draw (`PetService.recordLessonCompletion`'s pet branch),
/// split evenly among every *currently-eligible* pet in that tier (see
/// [drawPet]). Declaration order doubles as [drawPet]'s cumulative-weight
/// iteration order.
enum PetRarity {
  common,
  uncommon,
  epic,
  legendary,
  mythic;

  /// This tier's fixed share (summing to 100 across every value) of a
  /// weighted pet draw.
  int get weight => switch (this) {
    PetRarity.common => 55,
    PetRarity.uncommon => 30,
    PetRarity.epic => 10,
    PetRarity.legendary => 4,
    PetRarity.mythic => 1,
  };
}

/// A fixed, year-independent `(month, day)` date range during which a
/// seasonal pet is winnable from the lootbox, checked against the local
/// calendar date's month/day only (the year is ignored, so the window
/// recurs automatically every year). Both ends are inclusive.
///
/// Intentionally non-wrapping (see #063's "Out of scope") — a window
/// spanning Dec 31 -> Jan 1 needs different comparison logic this doesn't
/// implement; every window on today's catalog fits within a single
/// calendar month-pair.
class PetSeasonWindow {
  final int startMonth;
  final int startDay;
  final int endMonth;
  final int endDay;

  const PetSeasonWindow({
    required this.startMonth,
    required this.startDay,
    required this.endMonth,
    required this.endDay,
  });

  /// Whether [now]'s local calendar date falls within this window
  /// (inclusive), ignoring year.
  bool includes(DateTime now) {
    final (int, int) date = (now.month, now.day);
    return _compareMonthDay(date, (startMonth, startDay)) >= 0 &&
        _compareMonthDay(date, (endMonth, endDay)) <= 0;
  }

  static int _compareMonthDay((int, int) a, (int, int) b) {
    if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
    return a.$2.compareTo(b.$2);
  }
}

/// One catalog entry: a stable [id] (filename stem), its [assetPath] for
/// [Lottie.asset], its decoded [emoji] label, its [rarity] draw-weight
/// tier, its [sortOrder] (ascending, for both [PetCatalog.entries]'s own
/// order and the collection screen's grid order), and — for the two
/// seasonal pets — the [seasonWindow] during which it's winnable at all.
class PetEntry {
  final String id;
  final String assetPath;
  final String emoji;
  final PetRarity rarity;
  final int sortOrder;
  final PetSeasonWindow? seasonWindow;

  const PetEntry({
    required this.id,
    required this.assetPath,
    required this.emoji,
    required this.rarity,
    required this.sortOrder,
    this.seasonWindow,
  });

  /// A seasonal pet (spider, snowman) draws at [rarity]'s (Common) odds
  /// but always labels/announces as "Seasonal" instead — on owned *and*
  /// locked tiles — see [rarityKey].
  bool get isSeasonal => seasonWindow != null;

  /// The key passed to the `petRarityLabel`/`lootboxRevealedTitle` ICU
  /// `select` messages: always `"seasonal"` for a seasonal pet regardless
  /// of [rarity], otherwise [rarity]'s enum name.
  String get rarityKey => isSeasonal ? 'seasonal' : rarity.name;

  /// Whether this pet is currently winnable from the lootbox at [now] —
  /// always true for a non-seasonal pet, true for a seasonal one only
  /// inside its [seasonWindow].
  bool isInSeasonAt(DateTime now) =>
      seasonWindow == null || seasonWindow!.includes(now);

  @override
  bool operator ==(Object other) => other is PetEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PetEntry($id, $emoji)';
}

/// Decodes a pet [id]'s embedded hex Unicode codepoint(s) back into the
/// literal emoji character, per Noto Emoji's `emoji_u<hex>[_<hex>...]`
/// filename convention (e.g. `emoji_u1f426_200d_1f525_lottie` -> 🐦‍🔥).
String decodePetEmoji(String id) {
  const String prefix = 'emoji_u';
  const String suffix = '_lottie';
  final String core = id.substring(prefix.length, id.length - suffix.length);
  return core
      .split('_')
      .map((String hex) => String.fromCharCode(int.parse(hex, radix: 16)))
      .join();
}

/// The static, hardcoded collectible-pet catalog (issue #069).
abstract final class PetCatalog {
  /// Every collectible pet, ordered by [PetEntry.sortOrder] ascending
  /// (the fox is always first). This is the entire catalog — a new pet is
  /// added here, not discovered from `assets/noto-emoji/pet/` at runtime.
  static const List<PetEntry> entries = [
    PetEntry(
      id: kDefaultPetId,
      assetPath: '${kPetAssetDir}emoji_u1f98a_lottie.json',
      emoji: '🦊',
      rarity: PetRarity.common,
      sortOrder: 0,
    ),
    PetEntry(
      id: 'emoji_u1f407_lottie',
      assetPath: '${kPetAssetDir}emoji_u1f407_lottie.json',
      emoji: '🐇',
      rarity: PetRarity.common,
      sortOrder: 1,
    ),
    PetEntry(
      id: 'emoji_u1f41d_lottie',
      assetPath: '${kPetAssetDir}emoji_u1f41d_lottie.json',
      emoji: '🐝',
      rarity: PetRarity.common,
      sortOrder: 2,
    ),
    PetEntry(
      id: 'emoji_u1f425_lottie',
      assetPath: '${kPetAssetDir}emoji_u1f425_lottie.json',
      emoji: '🐥',
      rarity: PetRarity.common,
      sortOrder: 3,
    ),
    PetEntry(
      id: 'emoji_u1f577_lottie',
      assetPath: '${kPetAssetDir}emoji_u1f577_lottie.json',
      emoji: '🕷',
      rarity: PetRarity.common,
      sortOrder: 4,
      seasonWindow: PetSeasonWindow(
        startMonth: 10,
        startDay: 25,
        endMonth: 11,
        endDay: 1,
      ),
    ),
    PetEntry(
      id: 'emoji_u2603_lottie',
      assetPath: '${kPetAssetDir}emoji_u2603_lottie.json',
      emoji: '☃',
      rarity: PetRarity.common,
      sortOrder: 5,
      seasonWindow: PetSeasonWindow(
        startMonth: 12,
        startDay: 6,
        endMonth: 12,
        endDay: 26,
      ),
    ),
    PetEntry(
      id: 'emoji_u1f980_lottie',
      assetPath: '${kPetAssetDir}emoji_u1f980_lottie.json',
      emoji: '🦀',
      rarity: PetRarity.uncommon,
      sortOrder: 6,
    ),
    PetEntry(
      id: 'emoji_u1f989_lottie',
      assetPath: '${kPetAssetDir}emoji_u1f989_lottie.json',
      emoji: '🦉',
      rarity: PetRarity.uncommon,
      sortOrder: 7,
    ),
    PetEntry(
      id: 'emoji_u1f416_lottie',
      assetPath: '${kPetAssetDir}emoji_u1f416_lottie.json',
      emoji: '🐖',
      rarity: PetRarity.uncommon,
      sortOrder: 8,
    ),
    PetEntry(
      id: 'emoji_u1f996_lottie',
      assetPath: '${kPetAssetDir}emoji_u1f996_lottie.json',
      emoji: '🦖',
      rarity: PetRarity.epic,
      sortOrder: 9,
    ),
    PetEntry(
      id: 'emoji_u1f426_200d_1f525_lottie',
      assetPath: '${kPetAssetDir}emoji_u1f426_200d_1f525_lottie.json',
      emoji: '🐦‍🔥',
      rarity: PetRarity.mythic,
      sortOrder: 10,
    ),
  ];

  /// The default fox entry.
  static final PetEntry defaultEntry = entries.firstWhere(
    (entry) => entry.id == kDefaultPetId,
  );

  /// Returns [entries] — async for API compatibility with existing
  /// `Future`-typed call sites (`petCatalogLoaderProvider`, `PetService`'s
  /// loader seam); no asset-bundle I/O happens anymore.
  static Future<List<PetEntry>> load() async => entries;
}

/// Looks up a real catalog entry by [id] — convenience for fixture
/// catalogs (tests) that need a handful of real pets without copy-pasting
/// their full [PetEntry] definitions.
PetEntry petEntryForId(String id) =>
    PetCatalog.entries.firstWhere((entry) => entry.id == id);

/// Draws a pet from [pool] (every currently-eligible catalog entry) via a
/// weighted draw by [PetRarity] tier (issue #069): each tier's fixed
/// [PetRarity.weight] share of a pet draw is split evenly among the
/// eligible pets in that tier. A tier with no eligible pet is skipped
/// entirely, so its share is redistributed proportionally across the
/// tiers that do have one — every call still returns a pet as long as
/// [pool] isn't empty.
PetEntry drawPet(List<PetEntry> pool, Random random) {
  final Map<PetRarity, List<PetEntry>> byRarity = {};
  for (final entry in pool) {
    byRarity.putIfAbsent(entry.rarity, () => []).add(entry);
  }
  final int totalWeight = byRarity.keys.fold(
    0,
    (sum, rarity) => sum + rarity.weight,
  );
  var draw = random.nextInt(totalWeight);
  for (final rarity in PetRarity.values) {
    final List<PetEntry>? tierPool = byRarity[rarity];
    if (tierPool == null) continue;
    if (draw < rarity.weight) {
      return tierPool[random.nextInt(tierPool.length)];
    }
    draw -= rarity.weight;
  }
  throw StateError('unreachable: draw exceeded total rarity weight');
}
