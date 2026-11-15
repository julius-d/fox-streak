// No-audio-backend coverage for issue #129.
//
// Under `flutter test` no audioplayers plugin is registered, so every
// platform call fails with `MissingPluginException` — the same shape as a
// Linux desktop without a usable GStreamer setup. The app must keep running:
// creating and disposing the players raises no uncaught async error, and
// plays fail as ordinary futures that `FoxFeedback`'s chimes swallow
// (`correct_chime_test.dart`).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/widgets/fox_sound.dart';

/// Runs [body] in a guarded zone with `debugPrint` silenced (the failures are
/// logged by design) and returns the uncaught errors.
Future<List<Object>> _uncaughtErrors(Future<void> Function() body) async {
  final uncaught = <Object>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) {};
  try {
    await runZonedGuarded(body, (error, _) => uncaught.add(error));
  } finally {
    debugPrint = original;
  }
  return uncaught;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One test on purpose: audioplayers caches its global init future, and a
  // failed future from an earlier test's guarded zone never reaches a later
  // one (error futures don't cross error-zone boundaries), hanging it.
  test('create, play and dispose raise no uncaught error; plays fail as '
      'ordinary futures', () async {
    final playErrors = <Object>[];
    final uncaught = await _uncaughtErrors(() async {
      final player = AudioPlayersSoundPlayer();
      await pumpEventQueue();
      // try/catch, not `expectLater`, for the same zone-boundary reason.
      for (final play in [player.playLevelUp, player.playCorrect]) {
        try {
          await play();
        } on Object catch (error) {
          playErrors.add(error);
        }
      }
      player.dispose();
      await pumpEventQueue();
    });

    expect(uncaught, isEmpty);
    expect(playErrors, [
      isA<MissingPluginException>(),
      isA<MissingPluginException>(),
    ]);
  });
}
