// Mascot catalog (issue #059): discovers collectible mascots at *runtime*
// from `AssetManifest`, never a hardcoded Dart list — dropping one more
// `..._lottie.json` file into `assets/mascot/noto-emoji/` is the entire
// change needed to add a mascot later.
//
// Stable ID = filename stem (e.g. `emoji_u1f98a_lottie` for
// `emoji_u1f98a_lottie.json`), used as the primary/foreign key everywhere
// (owned-mascots table, equipped-mascot column) instead of an array index,
// so the catalog surviving new files being added later never shifts IDs
// already persisted in the database.
//
// No per-mascot l10n names: Noto Emoji filenames encode the Unicode
// codepoint(s) in hex (e.g. `u1f98a` -> 🦊); [decodeMascotEmoji] decodes
// that back into the literal emoji character, used as both the visible
// label and the a11y/semantic label via the generic `mascotSemanticLabel`
// arb template.
import 'package:flutter/services.dart';

/// Directory holding every collectible mascot's Lottie animation (and the
/// non-mascot `attribution.md`, filtered out by the `_lottie.json` suffix).
const String kMascotAssetDir = 'assets/mascot/noto-emoji/';

const String _kLottieSuffix = '_lottie.json';

/// Every profile starts owning and equipped with exactly this mascot (🦊),
/// matching the existing fox branding.
const String kDefaultMascotId = 'emoji_u1f98a_lottie';

/// One catalog entry: a stable [id] (filename stem), its [assetPath] for
/// [Lottie.asset], and its decoded [emoji] label.
class MascotEntry {
  final String id;
  final String assetPath;
  final String emoji;

  const MascotEntry({
    required this.id,
    required this.assetPath,
    required this.emoji,
  });

  @override
  bool operator ==(Object other) => other is MascotEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MascotEntry($id, $emoji)';
}

/// Decodes a mascot [id]'s embedded hex Unicode codepoint(s) back into the
/// literal emoji character, per Noto Emoji's `emoji_u<hex>[_<hex>...]`
/// filename convention (e.g. `emoji_u1f426_200d_1f525_lottie` -> 🐦‍🔥).
String decodeMascotEmoji(String id) {
  const String prefix = 'emoji_u';
  const String suffix = '_lottie';
  final String core = id.substring(prefix.length, id.length - suffix.length);
  return core
      .split('_')
      .map((String hex) => String.fromCharCode(int.parse(hex, radix: 16)))
      .join();
}

/// Builds a [MascotEntry] for a known mascot [id] without going through the
/// asset manifest — used for [MascotCatalog.defaultEntry] and anywhere a
/// fallback is needed before the real catalog has loaded.
MascotEntry mascotEntryForId(String id) => MascotEntry(
  id: id,
  assetPath: '$kMascotAssetDir$id.json',
  emoji: decodeMascotEmoji(id),
);

/// Discovers the collectible-mascot catalog at runtime.
abstract final class MascotCatalog {
  /// The default fox entry, available without loading the asset manifest.
  static final MascotEntry defaultEntry = mascotEntryForId(kDefaultMascotId);

  /// Loads every `assets/mascot/noto-emoji/*_lottie.json` asset from
  /// [bundle] (defaults to [rootBundle]) and returns one [MascotEntry] per
  /// file, sorted by [MascotEntry.id] for a stable iteration order.
  static Future<List<MascotEntry>> load({AssetBundle? bundle}) async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
      bundle ?? rootBundle,
    );
    final List<MascotEntry> entries = manifest
        .listAssets()
        .where(
          (String key) =>
              key.startsWith(kMascotAssetDir) && key.endsWith(_kLottieSuffix),
        )
        .map((String key) {
          final String fileName = key.substring(kMascotAssetDir.length);
          final String id = fileName.substring(
            0,
            fileName.length - '.json'.length,
          );
          return MascotEntry(
            id: id,
            assetPath: key,
            emoji: decodeMascotEmoji(id),
          );
        })
        .toList();
    entries.sort((MascotEntry a, MascotEntry b) => a.id.compareTo(b.id));
    return entries;
  }
}
