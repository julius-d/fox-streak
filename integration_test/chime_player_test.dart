// Real-platform check for issue #122: the preloaded low-latency correct-answer
// chime can be triggered repeatedly (including back-to-back) without errors.
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/widgets/fox_sound.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('correct chime plays repeatedly on the real audio backend', (
    tester,
  ) async {
    final player = AudioPlayersSoundPlayer();

    await player.playCorrect();
    await player.playCorrect();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await player.playCorrect();
    // Let the last chime finish so audioplayers' frame-based position updater
    // is idle before the widget tree is torn down.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  });
}
