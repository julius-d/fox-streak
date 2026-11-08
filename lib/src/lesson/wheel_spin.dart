// Pure motion model for the wheel-of-fortune spin (issue #117).
//
// Kept free of widgets/tickers so the properties the issue promises — always
// lands on the pre-drawn slice, never speeds up while stopping, overshoot
// stays inside the winning slice, bounded duration — are unit-testable by
// sampling [WheelTrajectory.turnsAt].
import 'dart:math' as math;

/// Rotation (in full turns) of the wheel over time for one spin.
///
/// A spin is: a short wind-up (eases slightly backwards), an acceleration to
/// [peakSpeed], a constant-speed cruise, then one continuous deceleration
/// ([stopDuration]) to a point just past the winning slice (the overshoot),
/// and a short settle back onto it.
///
/// The deceleration always starts from whatever the wheel's speed is at that
/// moment (always [peakSpeed], because stopping only engages once the wheel
/// has finished accelerating) and falls monotonically to zero, so stopping
/// early with a second tap can never make the wheel speed up. Both the
/// automatic stop and a manual stop use the same deceleration; they differ
/// only in *when* it engages. Whole turns are added or dropped to make the
/// deceleration fit, which never changes the landing slice.
class WheelTrajectory {
  /// Wind-up: the wheel eases back by [windUpTurns].
  static const Duration windUpDuration = Duration(milliseconds: 350);

  /// Acceleration from standstill to [peakSpeed].
  static const Duration accelerationDuration = Duration(milliseconds: 450);

  /// Earliest moment the stop can engage; a tap before that engages then.
  static const Duration readyAt = Duration(milliseconds: 800);

  /// When the spin stops on its own if never tapped again.
  static const Duration autoStopAt = Duration(milliseconds: 1200);

  /// The decelerating stretch from [peakSpeed] to the overshoot apex.
  static const Duration stopDuration = Duration(milliseconds: 2400);

  /// The settle from the overshoot apex back onto the slice center.
  static const Duration settleDuration = Duration(milliseconds: 300);

  /// Plain spin used with reduce-motion.
  static const Duration reducedDuration = Duration(milliseconds: 1500);

  /// Full turns per second while cruising.
  static const double peakSpeed = 4.5;
  static const double windUpTurns = 0.03;

  /// How far (in turns) the wheel travels past the slice center. Must stay
  /// below half a slice (1 / segments / 2 = ~0.071 turns for 7 slices) so the
  /// pointer never leaves the winning slice.
  static const double overshootTurns = 0.025;

  static const double _minStopDistance = 2.4;
  static const int _reducedFullTurns = 2;

  /// Fractional part, in `[0, 1)`, the wheel must come to rest at.
  final double restFraction;

  /// Whether this is the plain reduce-motion spin.
  final bool reduceMotion;

  /// Total time from first tap to rest.
  late final Duration totalDuration;

  /// Absolute rest position in turns (`restFraction` plus whole turns).
  late final double restTurns;

  /// When the deceleration engages (not meaningful with [reduceMotion]).
  Duration get stopEngagesAt => _engageAt;

  late final Duration _engageAt;
  late final double _engagePosition;
  late final double _stopDistance;
  late final double _stopExponent;

  /// A spin that stops by itself after [autoStopAt], or at [stopAfter] if
  /// given (clamped to [readyAt]).
  WheelTrajectory({
    required this.restFraction,
    Duration? stopAfter,
    this.reduceMotion = false,
  }) : assert(
         !reduceMotion || stopAfter == null,
         'the plain reduce-motion spin has no early stop',
       ) {
    if (reduceMotion) {
      totalDuration = reducedDuration;
      restTurns = _reducedFullTurns + restFraction;
      return;
    }
    final Duration requested = stopAfter ?? autoStopAt;
    _engageAt = requested < readyAt ? readyAt : requested;
    final double readyPosition =
        -windUpTurns + peakSpeed * _seconds(accelerationDuration) / 3;
    _engagePosition =
        readyPosition + peakSpeed * (_seconds(_engageAt) - _seconds(readyAt));
    final double apexFraction = restFraction + overshootTurns;
    final double base = (apexFraction - _engagePosition) % 1;
    _stopDistance = base + (_minStopDistance - base).ceil();
    _stopExponent = peakSpeed * _seconds(stopDuration) / _stopDistance - 1;
    restTurns = _engagePosition + _stopDistance - overshootTurns;
    totalDuration = _engageAt + stopDuration + settleDuration;
  }

  // Plain polynomials rather than `Curves`: their speed is exactly monotone
  // and they hit 0 / 1 exactly at the ends (the bezier-based `Curves` only
  // approximate both).
  static double _easeOutCubic(double u) => 1 - math.pow(1 - u, 3).toDouble();

  static double _smoothStep(double u) => u * u * (3 - 2 * u);

  static double _seconds(Duration d) =>
      d.inMicroseconds / Duration.microsecondsPerSecond;

  /// Rotation in turns [t] after the first tap.
  double turnsAt(Duration t) {
    final double s = math.max(0, _seconds(t));
    if (reduceMotion) {
      final double u = math.min(1, s / _seconds(reducedDuration));
      return restTurns * _easeOutCubic(u);
    }
    final double windUp = _seconds(windUpDuration);
    final double accel = _seconds(accelerationDuration);
    final double ready = _seconds(readyAt);
    final double engage = _seconds(_engageAt);
    final double stop = _seconds(stopDuration);
    if (s <= windUp) {
      return -windUpTurns * _smoothStep(s / windUp);
    }
    if (s <= ready) {
      final double u = (s - windUp) / accel;
      return -windUpTurns + peakSpeed * accel * u * u * u / 3;
    }
    if (s <= engage) {
      return -windUpTurns + peakSpeed * accel / 3 + peakSpeed * (s - ready);
    }
    if (s <= engage + stop) {
      final double u = (s - engage) / stop;
      return _engagePosition +
          _stopDistance * (1 - math.pow(math.max(0, 1 - u), _stopExponent + 1));
    }
    final double u = math.min(
      1,
      (s - engage - stop) / _seconds(settleDuration),
    );
    return restTurns + overshootTurns * (1 - _smoothStep(u));
  }

  /// Rotation speed in turns per second at [t] (numerical derivative).
  double speedAt(Duration t) {
    const Duration step = Duration(milliseconds: 4);
    final Duration before = t < step ? Duration.zero : t - step;
    return (turnsAt(t + step) - turnsAt(before)) / _seconds(t + step - before);
  }
}

/// Counts slice boundaries passing under the fixed pointer as the wheel
/// turns forward.
///
/// Slices are `1 / segments` turns wide and a boundary sits under the pointer
/// whenever `turns * segments` is a whole number. Moving backwards (the
/// wind-up, the settle) never counts, nor does re-crossing a boundary that
/// was already counted.
class WheelBoundaryTracker {
  WheelBoundaryTracker({required this.segments});

  final int segments;
  int _highestIndex = 0;

  /// Boundaries newly crossed since the last call, given the wheel is now at
  /// [turns].
  int advance(double turns) {
    final int index = (turns * segments).floor();
    if (index <= _highestIndex) return 0;
    final int crossed = index - _highestIndex;
    _highestIndex = index;
    return crossed;
  }
}

/// Rate limiter for the per-boundary haptic tick: at most one per
/// [minInterval] of animation time.
class WheelHapticThrottle {
  WheelHapticThrottle({this.minInterval = const Duration(milliseconds: 80)});

  final Duration minInterval;
  Duration? _last;

  /// Whether a tick at animation time [now] is allowed; records it if so.
  bool tryFire(Duration now) {
    final Duration? last = _last;
    if (last != null && now - last < minInterval) return false;
    _last = now;
    return true;
  }
}
