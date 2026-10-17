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
}
