// Real-platform check for issues #122/#123: the preloaded correct-answer
// chime can be triggered repeatedly (including back-to-back) and every
// trigger actually reaches playback instead of hanging on the audio backend.
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/widgets/fox_sound.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('correct chime plays repeatedly on the real audio backend', (
    tester,
  ) async {
    final player = AudioPlayersSoundPlayer();
    // Android's SoundPool never confirms a rewind, so a stuck chime used to
    // hang for audioplayers' 30 s seek timeout (#123) — fail fast instead.
    const budget = Duration(seconds: 3);

    await player.playCorrect().timeout(budget);
    await player.playCorrect().timeout(budget);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await player.playCorrect().timeout(budget);
    // The level-up chime shares the backend and must not hang either.
    await player.playLevelUp().timeout(budget);
    // Let the last chime finish so audioplayers' frame-based position updater
    // is idle before the widget tree is torn down.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  });
}
