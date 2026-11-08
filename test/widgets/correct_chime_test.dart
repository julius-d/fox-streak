// FoxFeedback.correctChime coverage for issue #122: gated by the sound
// toggle, independent of haptics, and never lets a failing player escape.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

class _FakeSoundPlayer implements FoxSoundPlayer {
  _FakeSoundPlayer({this.failure});

  final Object? failure;
  int playCorrectCallCount = 0;

  @override
  Future<void> playCorrect() {
    playCorrectCallCount++;
    if (failure != null) return Future<void>.error(failure!);
    return Future<void>.value();
  }

  @override
  Future<void> playLevelUp() async {}
}

class _SyncThrowingPlayer extends _FakeSoundPlayer {
  @override
  Future<void> playCorrect() {
    playCorrectCallCount++;
    throw StateError('sync');
  }
}

class _DisabledSound extends FoxSoundEnabled {
  @override
  bool build() => false;
}

class _DisabledHaptics extends FoxHapticsEnabled {
  @override
  bool build() => false;
}

Future<void> _pumpAndChime(
  WidgetTester tester,
  FoxSoundPlayer player, {
  List<Override> extra = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [foxSoundPlayerProvider.overrideWithValue(player), ...extra],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => FoxFeedback.correctChime(ref),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
}

void main() {
  testWidgets('plays the chime synchronously when sound is on', (tester) async {
    final player = _FakeSoundPlayer();
    await _pumpAndChime(tester, player);
    expect(player.playCorrectCallCount, 1);
  });

  testWidgets('plays the chime even when haptics are off', (tester) async {
    final player = _FakeSoundPlayer();
    await _pumpAndChime(
      tester,
      player,
      extra: [foxHapticsEnabledProvider.overrideWith(_DisabledHaptics.new)],
    );
    expect(player.playCorrectCallCount, 1);
  });

  testWidgets('is skipped when the sound toggle is off', (tester) async {
    final player = _FakeSoundPlayer();
    await _pumpAndChime(
      tester,
      player,
      extra: [foxSoundEnabledProvider.overrideWith(_DisabledSound.new)],
    );
    expect(player.playCorrectCallCount, 0);
  });

  testWidgets('swallows an asynchronous playback failure', (tester) async {
    final player = _FakeSoundPlayer(failure: StateError('async'));
    await _pumpAndChime(tester, player);
    expect(player.playCorrectCallCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swallows a synchronous playback failure', (tester) async {
    final player = _SyncThrowingPlayer();
    await _pumpAndChime(tester, player);
    expect(player.playCorrectCallCount, 1);
    expect(tester.takeException(), isNull);
  });
}
