// Sound playback seam for short celebratory chimes (issue #053).
//
// Mirrors [foxHapticsEnabledProvider] in `feedback_effects.dart`: a single
// default-on, mutable toggle with no settings UI yet (#055 builds that).
// Playback itself goes through [foxSoundPlayerProvider] rather than calling
// `audioplayers` directly from widgets, so tests can override it with a
// no-op fake instead of hitting a real platform audio channel.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sound toggle. Default on; mutable from settings (#055).
class FoxSoundEnabled extends Notifier<bool> {
  @override
  bool build() => true;

  void setEnabled({required bool value}) => state = value;
}

final NotifierProvider<FoxSoundEnabled, bool> foxSoundEnabledProvider =
    NotifierProvider<FoxSoundEnabled, bool>(FoxSoundEnabled.new);

/// Seam between the kit and `audioplayers` — override with a fake in tests
/// so `flutter test`/CI never touches a real platform audio channel.
abstract class FoxSoundPlayer {
  /// Plays the short level-up chime (`assets/sfx/level_up.mp3`).
  Future<void> playLevelUp();

  /// Plays the short correct-answer chime
  /// (`assets/sfx/koiroylers-correct-356013.mp3`, issue #054).
  Future<void> playCorrect();
}

/// Duck (not stop) other apps' audio while a chime plays (issue #070).
/// Android's `audioplayers` default is `AndroidAudioFocus.gain`, which tells
/// Android this is the sole audio source and pauses/stops anything else
/// playing; `gainTransientMayDuck` only lowers the other audio's volume for
/// the chime's brief duration. `AVAudioSessionOptions.duckOthers` is the same
/// behavior on iOS, layered onto the default `playback` category. macOS and
/// Windows have no `AudioContext` support in `audioplayers` — this is a
/// no-op there, same as before.
@visibleForTesting
AudioContext foxDuckingAudioContext() => AudioContext(
  android: const AudioContextAndroid(
    audioFocus: AndroidAudioFocus.gainTransientMayDuck,
  ),
  iOS: AudioContextIOS(options: const {AVAudioSessionOptions.duckOthers}),
);

/// Production implementation backed by `audioplayers`.
class AudioPlayersSoundPlayer implements FoxSoundPlayer {
  // Separate players per sound so a correct-answer chime mid-lesson can't
  // be cut off by (or cut off) the level-up chime on the result screen.
  final AudioPlayer _levelUpPlayer = AudioPlayer();
  final AudioPlayer _correctPlayer = AudioPlayer();

  // `play(ctx:)` awaits `setAudioContext` internally before resuming
  // playback (see audioplayers' `AudioPlayer.play`), so passing it here
  // guarantees the ducking context is applied before every play — unlike
  // setting it once via a fire-and-forget `setAudioContext()` call, which
  // would race the very first `play()`.
  @override
  Future<void> playLevelUp() => _levelUpPlayer.play(
    AssetSource('sfx/level_up.mp3'),
    ctx: foxDuckingAudioContext(),
  );

  @override
  Future<void> playCorrect() => _correctPlayer.play(
    AssetSource('sfx/koiroylers-correct-356013.mp3'),
    ctx: foxDuckingAudioContext(),
  );
}

final Provider<FoxSoundPlayer> foxSoundPlayerProvider =
    Provider<FoxSoundPlayer>((ref) => AudioPlayersSoundPlayer());
