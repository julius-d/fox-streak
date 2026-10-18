// Unit tests for the mascot catalog (issue #059).
//
// Covers: real bundled assets decode via the real asset manifest, the
// extensibility contract (a fake extra manifest entry surfaces with no
// catalog code change), filtering out non-`_lottie.json` files (e.g.
// `attribution.md`), and the Noto Emoji hex-codepoint decode (including a
// multi-codepoint ZWJ sequence).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/mascot/mascot_catalog.dart';

/// A minimal [AssetBundle] backed by a hand-crafted asset-manifest [Map],
/// encoded the same way the real build tool encodes `AssetManifest.bin` —
/// so [MascotCatalog.load] exercises its real [AssetManifest.loadFromAssetBundle]
/// parsing path without touching any real files on disk.
class _FakeAssetBundle extends CachingAssetBundle {
  final Map<String, List<Map<Object?, Object?>>> manifest;

  _FakeAssetBundle(this.manifest);

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      final ByteData? encoded = const StandardMessageCodec().encodeMessage(
        manifest,
      );
      return encoded!;
    }
    throw UnimplementedError('Unexpected asset load: $key');
  }
}

Map<String, List<Map<Object?, Object?>>> _manifestFor(List<String> keys) {
  return {
    for (final key in keys)
      key: [
        {'asset': key},
      ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MascotCatalog.load', () {
    test('discovers every real bundled *_lottie.json asset, excluding '
        'attribution.md', () async {
      final entries = await MascotCatalog.load();
      expect(entries, isNotEmpty);
      expect(
        entries.map((e) => e.id),
        everyElement(isNot(contains('attribution'))),
      );
      expect(entries.map((e) => e.id), contains(kDefaultMascotId));
      for (final entry in entries) {
        expect(entry.assetPath, '$kMascotAssetDir${entry.id}.json');
      }
    });

    test('discovers exactly the 11 collectible mascots, excluding the '
        "lootbox-opening effect animation bundled in the sibling 'other/' "
        'directory (#062)', () async {
      final entries = await MascotCatalog.load();
      expect(entries, hasLength(11));
      expect(entries.map((e) => e.id), isNot(contains('emoji_u1fa8e_lottie')));
    });

    test('adding a fake extra asset to the manifest surfaces it with no '
        'catalog code change', () async {
      final bundle = _FakeAssetBundle(
        _manifestFor([
          '${kMascotAssetDir}emoji_u1f98a_lottie.json',
          '${kMascotAssetDir}attribution.md',
          '${kMascotAssetDir}emoji_ufafa_lottie.json', // the "fake extra" asset
        ]),
      );

      final entries = await MascotCatalog.load(bundle: bundle);

      expect(entries.map((e) => e.id), [
        'emoji_u1f98a_lottie',
        'emoji_ufafa_lottie',
      ]);
      expect(entries.map((e) => e.id), isNot(contains('attribution')));
    });

    test('ignores assets outside the mascot directory', () async {
      final bundle = _FakeAssetBundle(
        _manifestFor([
          '${kMascotAssetDir}emoji_u1f98a_lottie.json',
          'assets/sfx/level_up.mp3',
          'assets/seed/demo_set.json',
        ]),
      );

      final entries = await MascotCatalog.load(bundle: bundle);

      expect(entries.map((e) => e.id), ['emoji_u1f98a_lottie']);
    });

    test('sorts entries by id for a stable iteration order', () async {
      final bundle = _FakeAssetBundle(
        _manifestFor([
          '${kMascotAssetDir}emoji_u1f996_lottie.json',
          '${kMascotAssetDir}emoji_u1f407_lottie.json',
          '${kMascotAssetDir}emoji_u1f98a_lottie.json',
        ]),
      );

      final entries = await MascotCatalog.load(bundle: bundle);

      expect(entries.map((e) => e.id), [
        'emoji_u1f407_lottie',
        'emoji_u1f98a_lottie',
        'emoji_u1f996_lottie',
      ]);
    });
  });

  group('decodeMascotEmoji', () {
    test('decodes a single-codepoint id (fox)', () {
      expect(decodeMascotEmoji('emoji_u1f98a_lottie'), '🦊');
    });

    test('decodes a multi-codepoint ZWJ sequence (fire bird)', () {
      expect(decodeMascotEmoji('emoji_u1f426_200d_1f525_lottie'), '🐦‍🔥');
    });
  });

  group('MascotCatalog.defaultEntry', () {
    test('is the fox, resolvable without loading the asset manifest', () {
      expect(MascotCatalog.defaultEntry.id, kDefaultMascotId);
      expect(MascotCatalog.defaultEntry.emoji, '🦊');
      expect(
        MascotCatalog.defaultEntry.assetPath,
        '${kMascotAssetDir}emoji_u1f98a_lottie.json',
      );
    });
  });

  group('MascotEntry equality', () {
    test('two entries with the same id are equal regardless of other '
        'fields', () {
      const a = MascotEntry(id: 'x', assetPath: 'a.json', emoji: '🦊');
      const b = MascotEntry(id: 'x', assetPath: 'b.json', emoji: '🦖');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('entries with different ids are not equal', () {
      const a = MascotEntry(id: 'x', assetPath: 'a.json', emoji: '🦊');
      const b = MascotEntry(id: 'y', assetPath: 'a.json', emoji: '🦊');
      expect(a, isNot(b));
    });
  });

  group('isMascotInSeason', () {
    test('a mascot with no seasonal-window entry is always in season', () {
      expect(isMascotInSeason(kDefaultMascotId, DateTime(2026, 1, 1)), isTrue);
      expect(
        isMascotInSeason('emoji_u1f416_lottie', DateTime(2026, 7, 4)), // pig
        isTrue,
      );
      expect(
        isMascotInSeason('emoji_u1f425_lottie', DateTime(2026, 7, 4)), // chick
        isTrue,
      );
    });

    test('snowman (Dec 6-26) excludes Dec 5 and Dec 27', () {
      expect(
        isMascotInSeason('emoji_u2603_lottie', DateTime(2026, 12, 5)),
        isFalse,
      );
      expect(
        isMascotInSeason('emoji_u2603_lottie', DateTime(2026, 12, 27)),
        isFalse,
      );
    });

    test('snowman (Dec 6-26) includes Dec 6 and Dec 26', () {
      expect(
        isMascotInSeason('emoji_u2603_lottie', DateTime(2026, 12, 6)),
        isTrue,
      );
      expect(
        isMascotInSeason('emoji_u2603_lottie', DateTime(2026, 12, 26)),
        isTrue,
      );
    });

    test('spider (Oct 25 - Nov 1) excludes Oct 24 and Nov 2', () {
      expect(
        isMascotInSeason('emoji_u1f577_lottie', DateTime(2026, 10, 24)),
        isFalse,
      );
      expect(
        isMascotInSeason('emoji_u1f577_lottie', DateTime(2026, 11, 2)),
        isFalse,
      );
    });

    test('spider (Oct 25 - Nov 1) includes Oct 25 and Nov 1', () {
      expect(
        isMascotInSeason('emoji_u1f577_lottie', DateTime(2026, 10, 25)),
        isTrue,
      );
      expect(
        isMascotInSeason('emoji_u1f577_lottie', DateTime(2026, 11, 1)),
        isTrue,
      );
    });

    test('the year is ignored (window recurs every year)', () {
      expect(
        isMascotInSeason('emoji_u2603_lottie', DateTime(1999, 12, 15)),
        isTrue,
      );
      expect(
        isMascotInSeason('emoji_u2603_lottie', DateTime(2099, 12, 15)),
        isTrue,
      );
    });
  });
}
