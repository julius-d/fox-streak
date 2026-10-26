// Ducking AudioContext coverage for issue #070.
//
// Audio-focus behavior itself (does another app's music actually get
// ducked?) isn't unit-testable — see issue #070's manual QA note — so this
// only locks down the pure-Dart config values that get handed to
// `audioplayers`, via the `@visibleForTesting` seam `foxDuckingAudioContext`.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/widgets/fox_sound.dart';

void main() {
  test('ducking context requests Android gainTransientMayDuck focus', () {
    final AudioContext context = foxDuckingAudioContext();

    expect(context.android.audioFocus, AndroidAudioFocus.gainTransientMayDuck);
  });

  test('ducking context keeps other Android defaults untouched', () {
    final AudioContext context = foxDuckingAudioContext();
    const AudioContextAndroid defaults = AudioContextAndroid();

    expect(context.android.isSpeakerphoneOn, defaults.isSpeakerphoneOn);
    expect(context.android.audioMode, defaults.audioMode);
    expect(context.android.stayAwake, defaults.stayAwake);
    expect(context.android.contentType, defaults.contentType);
    expect(context.android.usageType, defaults.usageType);
  });

  test(
    'ducking context adds iOS duckOthers on the default playback category',
    () {
      final AudioContext context = foxDuckingAudioContext();

      expect(context.iOS.category, AVAudioSessionCategory.playback);
      expect(context.iOS.options, contains(AVAudioSessionOptions.duckOthers));
    },
  );
}
