// Audio-backend gate for issue #129: without a backend (Linux lacking
// GStreamer's `playbin`) creating a player would abort the app, so
// `foxSoundPlayerProvider` hands out a silent player instead. The real
// probe against GStreamer can only run on Linux; here it's checked for a
// missing library.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/widgets/fox_sound.dart';
import 'package:fox_streak_app/src/widgets/gstreamer_probe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the probe reports no backend when GStreamer is missing', () {
    expect(gstreamerCanPlay(library: 'libfox-streak-no-such-lib.so'), isFalse);
  });

  test('without a backend the provider hands out a silent player', () async {
    final container = ProviderContainer(
      overrides: [foxSoundBackendAvailableProvider.overrideWithValue(false)],
    );
    addTearDown(container.dispose);

    final player = container.read(foxSoundPlayerProvider);

    expect(player, isA<SilentSoundPlayer>());
    await player.playCorrect();
    await player.playLevelUp();
    // The Sound toggle itself is untouched.
    expect(container.read(foxSoundEnabledProvider), isTrue);
  });

  test('platforms other than Linux never need the probe', () {
    for (final platform in TargetPlatform.values) {
      if (platform == TargetPlatform.linux) continue;
      debugDefaultTargetPlatformOverride = platform;
      final container = ProviderContainer();
      try {
        expect(
          container.read(foxSoundBackendAvailableProvider),
          isTrue,
          reason: '$platform',
        );
      } finally {
        container.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    }
  });
}
