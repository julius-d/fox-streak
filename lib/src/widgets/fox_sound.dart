// Sound playback seam for short celebratory chimes (issue #053).
//
// Mirrors [foxHapticsEnabledProvider] in `feedback_effects.dart`: a single
// default-on, mutable toggle with no settings UI yet (#055 builds that).
// Playback itself goes through [foxSoundPlayerProvider] rather than calling
// `audioplayers` directly from widgets, so tests can override it with a
// no-op fake instead of hitting a real platform audio channel.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gstreamer_probe.dart';

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
  static const String _correctAsset = 'sfx/koiroylers-correct-356013.mp3';

  // Separate players per sound so a correct-answer chime mid-lesson can't
  // be cut off by (or cut off) the level-up chime on the result screen.
  final AudioPlayer _levelUpPlayer = AudioPlayer();
  final AudioPlayer _correctPlayer = AudioPlayer();

  // The correct-answer chime is latency-critical (issue #122): configure the
  // player and load the asset once, at construction, so even the first chime
  // after app start only has to resume an already-buffered source. A failed
  // preparation is dropped (see [_ensureCorrectReady]) so the next play retries.
  Future<void>? _correctReady;

  AudioPlayersSoundPlayer() {
    unawaited(_ensureCorrectReady().catchError(logChimeFailure));
    // Without a usable audio backend (e.g. Linux without GStreamer's
    // `playbin`, issue #129) creating a player fails. The correct-answer
    // player's failure is logged via [_ensureCorrectReady] above; preparing
    // the level-up player up front the same way logs its failure too —
    // otherwise it'd be an uncaught async error. Plays then fail and are
    // skipped quietly by their callers ([FoxFeedback]).
    unawaited(
      _levelUpPlayer
          .setAudioContext(foxDuckingAudioContext())
          .catchError(logChimeFailure),
    );
  }

  Future<void> _ensureCorrectReady() {
    return _correctReady ??= _prepareCorrect().catchError((Object e) {
      _correctReady = null;
      throw e;
    });
  }

  void dispose() {
    unawaited(_levelUpPlayer.dispose().catchError(logChimeFailure));
    unawaited(_correctPlayer.dispose().catchError(logChimeFailure));
  }

  Future<void> _prepareCorrect() async {
    // Deliberately the default media-player mode, not `PlayerMode.lowLatency`
    // (issue #123): on Android that mode is a `SoundPool`, which never
    // confirms the rewind in [playCorrect] (so it hung until audioplayers'
    // 30 s seek timeout and the chime stayed silent) and never reports
    // completion. A source prepared up front already starts within a few ms.
    await _correctPlayer.setReleaseMode(ReleaseMode.stop);
    await _correctPlayer.setAudioContext(foxDuckingAudioContext());
    await _correctPlayer.setSource(AssetSource(_correctAsset));
  }

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

  // Restarts the preloaded source from the top, so rapid consecutive correct
  // answers each play their chime from the start.
  @override
  Future<void> playCorrect() async {
    await _ensureCorrectReady();
    await _correctPlayer.seek(Duration.zero);
    await _correctPlayer.resume();
  }
}

/// Chime failures never reach the learner (a chime that can't load or play
/// must not disturb the lesson), but are logged (`debugPrint`) so a silent
/// chime can be diagnosed (issue #123). Usable as a `catchError` handler.
void logChimeFailure(Object error, StackTrace stackTrace) =>
    debugPrint('FoxSound: chime failed: $error\n$stackTrace');

/// Plays nothing: the device has no usable audio backend (issue #129).
class SilentSoundPlayer implements FoxSoundPlayer {
  const SilentSoundPlayer();

  @override
  Future<void> playLevelUp() async {}

  @override
  Future<void> playCorrect() async {}
}

/// Whether the device can create audio players at all. Only Linux can lack
/// a backend: without GStreamer's `playbin` (see `gstreamer_probe.dart`),
/// creating a player would abort the app (issue #129).
final Provider<bool> foxSoundBackendAvailableProvider = Provider<bool>(
  (ref) => defaultTargetPlatform != TargetPlatform.linux || gstreamerCanPlay(),
);

/// Chimes are skipped quietly without an audio backend; the Sound toggle
/// stays as it is.
final Provider<FoxSoundPlayer> foxSoundPlayerProvider =
    Provider<FoxSoundPlayer>((ref) {
      if (!ref.watch(foxSoundBackendAvailableProvider)) {
        debugPrint('FoxSound: no audio backend, chimes are skipped');
        return const SilentSoundPlayer();
      }
      final player = AudioPlayersSoundPlayer();
      ref.onDispose(player.dispose);
      return player;
    });
