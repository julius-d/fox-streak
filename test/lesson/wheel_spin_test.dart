// Unit tests for the wheel's pure motion model (issue #117): landing,
// monotone deceleration while stopping, overshoot bound, duration limits,
// boundary counting and haptic throttling.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/src/lesson/wheel_painter.dart';
import 'package:fox_streak_app/src/lesson/wheel_screen.dart';
import 'package:fox_streak_app/src/lesson/wheel_spin.dart';
import 'package:fox_streak_app/src/pet/lootbox_reward.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

const int _segments = 7;
const Duration _frame = Duration(milliseconds: 16);

double _fractionFor(WheelReward reward) =>
    wheelTargetRotationTurns(reward, extraFullTurns: 0) % 1;

/// Slice index under the pointer at [turns].
int _sliceUnderPointer(double turns) {
  // Slice i spans [i, i + 1) / segments of a turn, shifted forward by the
  // rotation; the pointer reads turn 0.
  final double position = (1 - (turns % 1)) % 1;
  return (position * _segments).floor() % _segments;
}

List<Duration> _timeline(WheelTrajectory t) => [
  for (var d = Duration.zero; d <= t.totalDuration; d += _frame) d,
  t.totalDuration,
];

void main() {
  group('WheelTrajectory', () {
    test('lands on every segment, whenever the stop engages', () {
      for (final reward in kWheelSegments) {
        final int index = kWheelSegments.indexOf(reward);
        for (final int stopMs in <int>[0, 300, 800, 950, 1200, 1999]) {
          final t = WheelTrajectory(
            restFraction: _fractionFor(reward),
            stopAfter: Duration(milliseconds: stopMs),
          );
          expect(
            _sliceUnderPointer(t.turnsAt(t.totalDuration)),
            index,
            reason: '$reward stopped at ${stopMs}ms',
          );
          expect(t.turnsAt(t.totalDuration), closeTo(t.restTurns, 1e-9));
        }
      }
    });

    test('an early stop lands on the same slice as the unhindered spin', () {
      for (final reward in kWheelSegments) {
        final fraction = _fractionFor(reward);
        final unhindered = WheelTrajectory(restFraction: fraction);
        final early = WheelTrajectory(
          restFraction: fraction,
          stopAfter: const Duration(milliseconds: 1000),
        );
        expect(early.restTurns % 1, closeTo(unhindered.restTurns % 1, 1e-9));
      }
    });

    test('the early-stop trajectory agrees with the unhindered one until '
        'the stop engages', () {
      final fraction = _fractionFor(kWheelSegments.first);
      final unhindered = WheelTrajectory(restFraction: fraction);
      final early = WheelTrajectory(
        restFraction: fraction,
        stopAfter: const Duration(milliseconds: 1000),
      );
      for (var ms = 0; ms <= 1000; ms += 10) {
        final d = Duration(milliseconds: ms);
        expect(early.turnsAt(d), closeTo(unhindered.turnsAt(d), 1e-9));
      }
    });

    test('the wheel is continuous: no jumps between frames', () {
      for (final stopMs in <int>[0, 900, 1200]) {
        final t = WheelTrajectory(
          restFraction: 0.3,
          stopAfter: Duration(milliseconds: stopMs),
        );
        final times = _timeline(t);
        for (var i = 1; i < times.length; i++) {
          expect(
            (t.turnsAt(times[i]) - t.turnsAt(times[i - 1])).abs(),
            lessThan(0.1),
          );
        }
      }
    });

    test('speed never increases while stopping (any stop moment)', () {
      for (final stopMs in <int>[0, 500, 800, 1000, 1200, 1700]) {
        final t = WheelTrajectory(
          restFraction: 0.57,
          stopAfter: Duration(milliseconds: stopMs),
        );
        final engage = stopMs < 800 ? 800 : stopMs;
        final apex = Duration(
          milliseconds: engage + WheelTrajectory.stopDuration.inMilliseconds,
        );
        var previous = double.infinity;
        for (
          var d = Duration(milliseconds: engage);
          d <= apex - _frame;
          d += _frame
        ) {
          final speed = t.speedAt(d);
          expect(
            speed,
            lessThanOrEqualTo(previous + 1e-3),
            reason: 'stop at ${stopMs}ms, t=$d',
          );
          expect(speed, greaterThanOrEqualTo(-1e-3));
          previous = speed;
        }
      }
    });

    test('overshoots past the center but never leaves the winning slice', () {
      for (final reward in kWheelSegments) {
        final index = kWheelSegments.indexOf(reward);
        final t = WheelTrajectory(restFraction: _fractionFor(reward));
        final apex = t.turnsAt(
          WheelTrajectory.autoStopAt + WheelTrajectory.stopDuration,
        );
        expect(
          apex - t.restTurns,
          closeTo(WheelTrajectory.overshootTurns, 1e-6),
        );
        expect(WheelTrajectory.overshootTurns, lessThan(1 / _segments / 2));

        // The wheel never travels beyond the apex, and from the apex on the
        // pointer stays inside the winning slice while settling back.
        for (final d in _timeline(t)) {
          expect(
            t.turnsAt(d),
            lessThanOrEqualTo(
              t.restTurns + WheelTrajectory.overshootTurns + 1e-9,
            ),
          );
        }
        final apexAt =
            WheelTrajectory.autoStopAt + WheelTrajectory.stopDuration;
        for (final d in _timeline(t).where((d) => d >= apexAt)) {
          expect(
            _sliceUnderPointer(t.turnsAt(d)),
            index,
            reason: '$reward at $d',
          );
        }
        // And the final settle moves backwards, i.e. towards the center.
        expect(t.restTurns, lessThan(apex));
      }
    });

    test('winds up backwards before accelerating', () {
      final t = WheelTrajectory(restFraction: 0.4);
      expect(
        t.turnsAt(WheelTrajectory.windUpDuration),
        closeTo(-WheelTrajectory.windUpTurns, 1e-9),
      );
      expect(t.turnsAt(Duration.zero), 0);
      expect(t.turnsAt(const Duration(seconds: 2)), greaterThan(0));
    });

    test('takes at most about 4 s, and an early stop is never slower', () {
      final unhindered = WheelTrajectory(restFraction: 0.1);
      expect(
        unhindered.totalDuration,
        lessThanOrEqualTo(const Duration(seconds: 4)),
      );
      for (var ms = 0; ms <= 1200; ms += 100) {
        final early = WheelTrajectory(
          restFraction: 0.1,
          stopAfter: Duration(milliseconds: ms),
        );
        expect(
          early.totalDuration,
          lessThanOrEqualTo(unhindered.totalDuration),
        );
      }
    });

    test('reduce motion: one plain 1.5 s decelerating spin, no flourishes', () {
      for (final reward in kWheelSegments) {
        final t = WheelTrajectory(
          restFraction: _fractionFor(reward),
          reduceMotion: true,
        );
        expect(t.totalDuration, const Duration(milliseconds: 1500));
        expect(
          _sliceUnderPointer(t.turnsAt(t.totalDuration)),
          kWheelSegments.indexOf(reward),
        );
        var previous = double.infinity;
        var position = 0.0;
        for (final d in _timeline(t).skip(1)) {
          final speed = t.speedAt(d);
          expect(speed, lessThanOrEqualTo(previous + 1e-3));
          previous = speed;
          // No wind-up (never backwards) and no overshoot (never past rest).
          expect(t.turnsAt(d), greaterThanOrEqualTo(position - 1e-9));
          expect(t.turnsAt(d), lessThanOrEqualTo(t.restTurns + 1e-9));
          position = t.turnsAt(d);
        }
      }
    });
  });

  group('WheelBoundaryTracker', () {
    test('flick count equals the boundaries crossed over a whole spin', () {
      for (final reward in kWheelSegments) {
        final t = WheelTrajectory(restFraction: _fractionFor(reward));
        final tracker = WheelBoundaryTracker(segments: _segments);
        var flicks = 0;
        for (final d in _timeline(t)) {
          flicks += tracker.advance(t.turnsAt(d));
        }
        final highest =
            (t.restTurns + WheelTrajectory.overshootTurns) * _segments;
        expect(flicks, highest.floor());
      }
    });

    test('is silent when still, backwards, or already counted', () {
      final tracker = WheelBoundaryTracker(segments: _segments);
      expect(tracker.advance(0), 0);
      expect(tracker.advance(-0.03), 0);
      expect(tracker.advance(0), 0);
      expect(tracker.advance(0.2), 1); // crossed 1/7
      expect(tracker.advance(0.2), 0);
      expect(tracker.advance(0.1), 0);
      expect(tracker.advance(0.2), 0); // re-crossing is not a new flick
      expect(tracker.advance(0.5), 2); // 2/7 and 3/7
    });

    test('counts every boundary when a frame skips several', () {
      final tracker = WheelBoundaryTracker(segments: _segments);
      expect(tracker.advance(1.0), _segments);
    });

    test('never flicks after landing', () {
      final t = WheelTrajectory(restFraction: 0.3);
      final tracker = WheelBoundaryTracker(segments: _segments);
      for (final d in _timeline(t)) {
        tracker.advance(t.turnsAt(d));
      }
      expect(tracker.advance(t.restTurns), 0);
    });
  });

  group('WheelHapticThrottle', () {
    test('allows at most one tick per 80 ms', () {
      final throttle = WheelHapticThrottle();
      expect(throttle.tryFire(Duration.zero), isTrue);
      expect(throttle.tryFire(const Duration(milliseconds: 79)), isFalse);
      expect(throttle.tryFire(const Duration(milliseconds: 80)), isTrue);
      expect(throttle.tryFire(const Duration(milliseconds: 100)), isFalse);
      expect(throttle.tryFire(const Duration(milliseconds: 400)), isTrue);
    });

    test('a full-speed spin buzzes at most every 80 ms', () {
      final t = WheelTrajectory(restFraction: 0.3);
      final tracker = WheelBoundaryTracker(segments: _segments);
      final throttle = WheelHapticThrottle();
      final fired = <Duration>[];
      for (final d in _timeline(t)) {
        if (tracker.advance(t.turnsAt(d)) > 0 && throttle.tryFire(d)) {
          fired.add(d);
        }
      }
      for (var i = 1; i < fired.length; i++) {
        expect(
          fired[i] - fired[i - 1],
          greaterThanOrEqualTo(const Duration(milliseconds: 80)),
        );
      }
      expect(fired, isNotEmpty);
    });
  });

  group('wheelDimmedColors', () {
    for (final (name, theme) in <(String, ThemeData)>[
      ('light', FoxStreakTheme.light()),
      ('dark', FoxStreakTheme.dark()),
    ]) {
      test('dimmed labels keep AA contrast in $name mode', () {
        final s = theme.extension<FoxSemanticColors>()!;
        final fills = [
          s.gold,
          s.coin,
          s.flame,
          s.success,
          s.info,
          s.math,
          s.ice,
        ];
        final ons = [
          s.onGold,
          s.onCoin,
          s.onFlame,
          s.onSuccess,
          s.onInfo,
          s.onMath,
          s.onIce,
        ];
        for (var i = 0; i < fills.length; i++) {
          final dim = wheelDimmedColors(
            fill: fills[i],
            onFill: ons[i],
            surface: theme.colorScheme.surface,
            onSurface: theme.colorScheme.onSurface,
          );
          final la = dim.label.computeLuminance();
          final lb = dim.fill.computeLuminance();
          final contrast =
              (la > lb ? la + 0.05 : lb + 0.05) /
              (la > lb ? lb + 0.05 : la + 0.05);
          expect(
            contrast,
            greaterThanOrEqualTo(kWheelMinLabelContrast),
            reason: 'slice $i',
          );
        }
      });
    }
  });
}
