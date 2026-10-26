// Pet catalog (issue #059): discovers collectible pets at *runtime*
// from `AssetManifest`, never a hardcoded Dart list — dropping one more
// `..._lottie.json` file into `assets/noto-emoji/pet/` is the entire
// change needed to add a pet later. One-off, non-collectible effect
// animations (e.g. the lootbox-opening Lottie, issue #062) live in the
// sibling `assets/noto-emoji/other/` instead, which this catalog never
// scans.
//
// Stable ID = filename stem (e.g. `emoji_u1f98a_lottie` for
// `emoji_u1f98a_lottie.json`), used as the primary/foreign key everywhere
// (owned-pets table, equipped-pet column) instead of an array index,
// so the catalog surviving new files being added later never shifts IDs
// already persisted in the database.
//
// No per-pet l10n names: Noto Emoji filenames encode the Unicode
// codepoint(s) in hex (e.g. `u1f98a` -> 🦊); [decodePetEmoji] decodes
// that back into the literal emoji character, used as both the visible
// label and the a11y/semantic label via the generic `petSemanticLabel`
// arb template.
import 'package:flutter/services.dart';

/// Directory holding every collectible pet's Lottie animation. Sibling to
/// `assets/noto-emoji/other/` (non-collectible effect animations) and
/// `assets/noto-emoji/attribution.md`, neither of which this scans.
const String kPetAssetDir = 'assets/noto-emoji/pet/';

const String _kLottieSuffix = '_lottie.json';

/// Every profile starts owning and equipped with exactly this pet (🦊),
/// matching the existing fox branding.
const String kDefaultPetId = 'emoji_u1f98a_lottie';

/// One catalog entry: a stable [id] (filename stem), its [assetPath] for
/// [Lottie.asset], and its decoded [emoji] label.
class PetEntry {
  final String id;
  final String assetPath;
  final String emoji;

  const PetEntry({
    required this.id,
    required this.assetPath,
    required this.emoji,
  });

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

/// Builds a [PetEntry] for a known pet [id] without going through the
/// asset manifest — used for [PetCatalog.defaultEntry] and anywhere a
/// fallback is needed before the real catalog has loaded.
PetEntry petEntryForId(String id) => PetEntry(
  id: id,
  assetPath: '$kPetAssetDir$id.json',
  emoji: decodePetEmoji(id),
);

/// Discovers the collectible-pet catalog at runtime.
abstract final class PetCatalog {
  /// The default fox entry, available without loading the asset manifest.
  static final PetEntry defaultEntry = petEntryForId(kDefaultPetId);

  /// Loads every `assets/noto-emoji/pet/*_lottie.json` asset from
  /// [bundle] (defaults to [rootBundle]) and returns one [PetEntry] per
  /// file, sorted by [PetEntry.id] for a stable iteration order.
  static Future<List<PetEntry>> load({AssetBundle? bundle}) async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
      bundle ?? rootBundle,
    );
    final List<PetEntry> entries = manifest
        .listAssets()
        .where(
          (String key) =>
              key.startsWith(kPetAssetDir) && key.endsWith(_kLottieSuffix),
        )
        .map((String key) {
          final String fileName = key.substring(kPetAssetDir.length);
          final String id = fileName.substring(
            0,
            fileName.length - '.json'.length,
          );
          return PetEntry(id: id, assetPath: key, emoji: decodePetEmoji(id));
        })
        .toList();
    entries.sort((PetEntry a, PetEntry b) => a.id.compareTo(b.id));
    return entries;
  }
}

/// A fixed, year-independent `(month, day)` date range during which a
/// seasonal pet is winnable from the lootbox, checked against the local
/// calendar date's month/day only (the year is ignored, so the window
/// recurs automatically every year). Both ends are inclusive.
///
/// Intentionally non-wrapping (see #063's "Out of scope") — a window
/// spanning Dec 31 -> Jan 1 needs different comparison logic this doesn't
/// implement; every window in [kPetSeasonWindows] today fits within a
/// single calendar month-pair.
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

/// Seasonal-eligibility table, keyed by pet ID (#063). A pet ID with
/// no entry here is winnable from the lootbox year-round — today's
/// behavior for every pre-#063 pet, plus the pig/chick this issue also
/// adds as ordinary (non-seasonal) pets.
const Map<String, PetSeasonWindow> kPetSeasonWindows = {
  // Snowman: Christmas season, Dec 6-26.
  'emoji_u2603_lottie': PetSeasonWindow(
    startMonth: 12,
    startDay: 6,
    endMonth: 12,
    endDay: 26,
  ),
  // Spider: an 8-day Halloween window, Oct 25 - Nov 1.
  'emoji_u1f577_lottie': PetSeasonWindow(
    startMonth: 10,
    startDay: 25,
    endMonth: 11,
    endDay: 1,
  ),
};

/// Whether pet [id] is currently winnable from the lootbox at [now] —
/// always true for a non-seasonal pet, and true for a seasonal one only
/// inside its [PetSeasonWindow] (see [kPetSeasonWindows]).
bool isPetInSeason(String id, DateTime now) {
  final PetSeasonWindow? window = kPetSeasonWindows[id];
  return window == null || window.includes(now);
}
