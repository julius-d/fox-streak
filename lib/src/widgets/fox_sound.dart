// Sound playback seam for short celebratory chimes (issue #053).
//
// Mirrors [foxHapticsEnabledProvider] in `feedback_effects.dart`: a single
// default-on, mutable toggle with no settings UI yet (#055 builds that).
// Playback itself goes through [foxSoundPlayerProvider] rather than calling
// `audioplayers` directly from widgets, so tests can override it with a
// no-op fake instead of hitting a real platform audio channel.
import 'package:audioplayers/audioplayers.dart';
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
}

/// Production implementation backed by `audioplayers`.
class AudioPlayersSoundPlayer implements FoxSoundPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playLevelUp() => _player.play(AssetSource('sfx/level_up.mp3'));
}

final Provider<FoxSoundPlayer> foxSoundPlayerProvider =
    Provider<FoxSoundPlayer>((ref) => AudioPlayersSoundPlayer());
