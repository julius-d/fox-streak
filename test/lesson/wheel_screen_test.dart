// Widget tests for `WheelScreen` (issue #085; #087 adds the streak-on-ice
// segment).
//
// Covers what an integration test driving the whole `LessonScreen` can't
// easily isolate: that the spin — however it's stopped — always lands on
// the already-decided reward's segment, that a streak-on-ice win renders
// distinctly from a coin win, and that the screen blocks back nav from the
// start (unlike the lootbox/streak-saved/XP-up screens, #082).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/lesson/wheel_painter.dart';
import 'package:fox_streak_app/src/lesson/wheel_screen.dart';
import 'package:fox_streak_app/src/pet/lootbox_reward.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

final _l10n = AppLocalizationsEn();

Widget _harness(
  WheelReward reward, {
  bool hapticsEnabled = true,
  bool reduceMotion = false,
}) {
  return ProviderScope(
    overrides: [
      foxHapticsEnabledProvider.overrideWith(
        () => _FixedHaptics(value: hapticsEnabled),
      ),
    ],
    child: MaterialApp(
      theme: FoxStreakTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: WheelScreen(reward: reward, l10n: _l10n),
    ),
  );
}

class _FixedHaptics extends FoxHapticsEnabled {
  _FixedHaptics({required this.value});
  final bool value;

  @override
  bool build() => value;
}

/// The wheel's current rotation in turns, read back from the rotating
/// [Transform] (angle = atan2 of the rotation matrix; the idle wobble is 0
/// whenever the wheel is not idle).
double _currentRotationTurns(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.byKey(const Key('wheelRotation')),
  );
  final m = transform.transform.storage;
  return math.atan2(m[1], m[0]) / (2 * math.pi);
}

/// Slice index under the fixed top pointer for a rotation in turns.
int _sliceUnderPointer(double turns) {
  final position = (1 - (turns % 1)) % 1;
  return (position * kWheelSegments.length).floor() % kWheelSegments.length;
}

WheelPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(const Key('wheelDial')),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as WheelPainter;

/// Counts `HapticFeedback` platform calls.
List<MethodCall> _recordHaptics(WidgetTester tester) {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

Future<void> _pumpFrames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 16);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

void main() {
  group('wheelTargetRotationTurns', () {
    test('every segment lands on a distinct fractional turn, invariant to '
        'extraFullTurns', () {
      final fractions = kWheelSegments
          .map(
            (segment) =>
                wheelTargetRotationTurns(segment, extraFullTurns: 0) % 1,
          )
          .toSet();
      expect(fractions, hasLength(kWheelSegments.length));

      for (final segment in kWheelSegments) {
        expect(
          wheelTargetRotationTurns(segment, extraFullTurns: 4) % 1,
          closeTo(
            wheelTargetRotationTurns(segment, extraFullTurns: 0) % 1,
            1e-9,
          ),
        );
      }
    });

    test('adds exactly extraFullTurns whole turns on top of the landing '
        'fraction', () {
      const reward = WheelCoinsReward(30);
      final withoutExtra = wheelTargetRotationTurns(reward, extraFullTurns: 0);
      final withExtra = wheelTargetRotationTurns(reward, extraFullTurns: 7);
      expect(withExtra - withoutExtra, closeTo(7, 1e-9));
    });
  });

  testWidgets('starts idle, tappable, with no Continue button yet', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const WheelCoinsReward(30)));
    await tester.pump();

    expect(find.text(_l10n.wheelHeading), findsOneWidget);
    expect(find.byKey(const Key('wheelSpinButton')), findsOneWidget);
    expect(find.byKey(const Key('wheelContinueButton')), findsNothing);
  });

  testWidgets('blocks back navigation from the start (PopScope canPop: '
      'false)', (tester) async {
    await tester.pumpWidget(_harness(const WheelCoinsReward(30)));
    await tester.pump();

    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
  });

  testWidgets('a manual second tap stops the spin early, landing on the '
      'already-decided segment', (tester) async {
    const reward = WheelCoinsReward(50);
    await tester.pumpWidget(_harness(reward));
    await tester.pump();

    await tester.tap(find.byKey(const Key('wheelSpinButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('wheelSpinButton'))); // early stop
    await tester.pumpAndSettle();

    expect(
      _sliceUnderPointer(_currentRotationTurns(tester)),
      kWheelSegments.indexOf(reward),
    );
    expect(find.text(_l10n.wheelWonText(50)), findsOneWidget);
    expect(find.byKey(const Key('wheelContinueButton')), findsOneWidget);
  });

  testWidgets('letting the automatic timeout stop the spin lands on the same '
      'segment a manual stop would', (tester) async {
    const reward = WheelCoinsReward(50);
    await tester.pumpWidget(_harness(reward));
    await tester.pump();

    await tester.tap(find.byKey(const Key('wheelSpinButton')));
    await tester.pump();
    await tester.pumpAndSettle(); // never tapped again — auto-stop fires

    expect(
      _sliceUnderPointer(_currentRotationTurns(tester)),
      kWheelSegments.indexOf(reward),
    );
    expect(find.text(_l10n.wheelWonText(50)), findsOneWidget);
    expect(find.byKey(const Key('wheelContinueButton')), findsOneWidget);
  });

  testWidgets(
    'a streak-on-ice win (issue #087) shows its own won-text/semantic '
    'label, distinct from a coin win, and lands on its own segment',
    (tester) async {
      const reward = WheelStreakOnIceReward();
      await tester.pumpWidget(_harness(reward));
      await tester.pump();

      await tester.tap(find.byKey(const Key('wheelSpinButton')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        _sliceUnderPointer(_currentRotationTurns(tester)),
        kWheelSegments.indexOf(reward),
      );
      expect(find.text(_l10n.wheelWonStreakOnIceText), findsOneWidget);
      expect(find.byKey(const Key('wheelContinueButton')), findsOneWidget);
    },
  );

  testWidgets('a second tap during the wind-down (the stopping phase) is '
      "ignored — it doesn't postpone the landing (regression guard)", (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const WheelCoinsReward(50)));
    await tester.pump();

    await tester.tap(find.byKey(const Key('wheelSpinButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.tap(find.byKey(const Key('wheelSpinButton'))); // 1st stop
    await tester.pump();

    // Stop engaged ~1000 ms into the spin: landing is due at ~3700 ms.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byKey(const Key('wheelContinueButton')), findsNothing);
    await tester.tap(
      find.byKey(const Key('wheelSpinButton')),
      warnIfMissed: false,
    ); // must be a no-op, not a postponement

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byKey(const Key('wheelContinueButton')), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('wheelContinueButton')), findsOneWidget);
  });

  testWidgets('a tap after the automatic stop engaged is a no-op: the wheel '
      'never speeds up again', (tester) async {
    await tester.pumpWidget(_harness(const WheelCoinsReward(50)));
    await tester.pump();
    await tester.tap(find.byKey(const Key('wheelSpinButton')));
    await tester.pump();
    await _pumpFrames(tester, const Duration(milliseconds: 2000));
    await tester.tap(
      find.byKey(const Key('wheelSpinButton')),
      warnIfMissed: false,
    );
    await _pumpFrames(tester, const Duration(milliseconds: 2000));
    // Auto-stop plan: 1200 + 2400 + 300 ms. A re-planned stop from 2.0 s
    // would still be running at ~4.7 s.
    expect(find.byKey(const Key('wheelContinueButton')), findsOneWidget);
  });

  testWidgets('a tap in the very first moments still lands on the segment, '
      'engaging the stop once the wheel is up to speed', (tester) async {
    const reward = WheelCoinsReward(75);
    await tester.pumpWidget(_harness(reward));
    await tester.pump();
    await tester.tap(find.byKey(const Key('wheelSpinButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('wheelSpinButton')));
    await tester.pumpAndSettle();

    expect(
      _sliceUnderPointer(_currentRotationTurns(tester)),
      kWheelSegments.indexOf(reward),
    );
    expect(find.byKey(const Key('wheelContinueButton')), findsOneWidget);
  });

  testWidgets('every segment is landed on, by auto stop and by early stop', (
    tester,
  ) async {
    for (final reward in kWheelSegments) {
      for (final earlyStop in <bool>[false, true]) {
        await tester.pumpWidget(_harness(reward));
        await tester.pump();
        await tester.tap(find.byKey(const Key('wheelSpinButton')));
        await tester.pump();
        if (earlyStop) {
          await tester.pump(const Duration(milliseconds: 900));
          await tester.tap(find.byKey(const Key('wheelSpinButton')));
        }
        await tester.pumpAndSettle();
        expect(
          _sliceUnderPointer(_currentRotationTurns(tester)),
          kWheelSegments.indexOf(reward),
          reason: '$reward earlyStop=$earlyStop',
        );
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  group('idle invitation', () {
    testWidgets('pulses before the first tap, is bounded, and stops on spin', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const WheelCoinsReward(30)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final scale = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byKey(const Key('wheelRotation')),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(scale.transform.storage[0], greaterThan(1.0));
      expect(find.text(_l10n.wheelHeading), findsOneWidget);

      // Bounded: a breath ends, the loop pauses, pumpAndSettle terminates.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('wheelSpinButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final spinning = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byKey(const Key('wheelRotation')),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(spinning.transform.storage[0], 1.0);
      await tester.pumpAndSettle();
    });

    testWidgets('does not animate with reduce-motion on', (tester) async {
      await tester.pumpWidget(
        _harness(const WheelCoinsReward(30), reduceMotion: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final scale = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byKey(const Key('wheelRotation')),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(scale.transform.storage[0], 1.0);
      expect(_currentRotationTurns(tester), 0);
      expect(find.text(_l10n.wheelHeading), findsOneWidget);
    });
  });

  group('win moment', () {
    testWidgets('highlights the winning slice only after landing; result and '
        'Continue stay', (tester) async {
      const reward = WheelCoinsReward(50);
      await tester.pumpWidget(_harness(reward));
      await tester.pump();
      expect(_painter(tester).winningIndex, isNull);

      await tester.tap(find.byKey(const Key('wheelSpinButton')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).winningIndex, isNull);

      await tester.pumpAndSettle();
      expect(_painter(tester).winningIndex, kWheelSegments.indexOf(reward));
      expect(find.text(_l10n.wheelWonText(50)), findsOneWidget);
      expect(find.byKey(const Key('wheelContinueButton')), findsOneWidget);
    });

    testWidgets('announces the won reward once, with no extra highlight '
        'semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(const WheelCoinsReward(50)));
      await tester.pump();
      await tester.tap(find.byKey(const Key('wheelSpinButton')));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(_l10n.coinsSemanticLabel(50)),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('haptics', () {
    testWidgets('are throttled to one per ~80 ms and fire while spinning', (
      tester,
    ) async {
      final calls = _recordHaptics(tester);
      await tester.pumpWidget(_harness(const WheelCoinsReward(30)));
      await tester.pump();
      await tester.tap(find.byKey(const Key('wheelSpinButton')));
      await tester.pump();
      await _pumpFrames(tester, const Duration(milliseconds: 4200));

      // Spin of ~3.9 s: well above one boundary per frame at full speed, but
      // never more than one tick per 80 ms.
      expect(calls, isNotEmpty);
      expect(calls.length, lessThanOrEqualTo(3900 ~/ 80 + 1));
    });

    testWidgets('are silent when the haptics toggle is off', (tester) async {
      final calls = _recordHaptics(tester);
      await tester.pumpWidget(
        _harness(const WheelCoinsReward(30), hapticsEnabled: false),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('wheelSpinButton')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('are silent before the first tap and after landing', (
      tester,
    ) async {
      final calls = _recordHaptics(tester);
      await tester.pumpWidget(_harness(const WheelCoinsReward(30)));
      await tester.pump(const Duration(seconds: 2));
      expect(calls, isEmpty);

      await tester.tap(find.byKey(const Key('wheelSpinButton')));
      await tester.pumpAndSettle();
      final afterLanding = calls.length;
      await tester.pump(const Duration(seconds: 2));
      expect(calls.length, afterLanding);
    });
  });

  group('reduce motion', () {
    testWidgets('does a plain ~1.5 s spin, no wind-up, still lands, '
        'highlights statically and ticks haptics', (tester) async {
      final calls = _recordHaptics(tester);
      const reward = WheelCoinsReward(100);
      await tester.pumpWidget(_harness(reward, reduceMotion: true));
      await tester.pump();
      await tester.tap(find.byKey(const Key('wheelSpinButton')));
      await tester.pump();

      await _pumpFrames(tester, const Duration(milliseconds: 1400));
      expect(find.byKey(const Key('wheelContinueButton')), findsNothing);

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('wheelContinueButton')), findsOneWidget);
      expect(
        _sliceUnderPointer(_currentRotationTurns(tester)),
        kWheelSegments.indexOf(reward),
      );
      expect(_painter(tester).winningIndex, kWheelSegments.indexOf(reward));
      expect(calls, isNotEmpty);
      // No pulsing winning slice: a static highlight settles immediately.
      expect(_painter(tester).pulse!.value, 0);
    });
  });

  testWidgets('Continue pops the screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: FoxStreakTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => WheelScreen(
                        reward: const WheelCoinsReward(20),
                        l10n: _l10n,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wheelSpinButton')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wheelContinueButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wheelScreen')), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
