// The Streak Details screen's motion (issue #128, sequenced by #132): the
// hero count-up + flame flicker, the backwards streak-band draw-in, and the
// today pulse.
//
// [StreakDetailsMotion] owns every controller so the screen can play one
// opening sequence across the hero and the calendar: count-up -> band
// draw-in -> today pulse, skipping steps that don't apply. Afterwards the
// flame (live streak) and the today pulse (today not practiced) keep coming
// back in bursts with a rest in between. The screen decides when the
// sequence starts (after its page transition), when everything pauses (app
// hidden, another screen on top) and when reduce motion shows the final
// state instead.
import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// Count-up of the hero's streak number, whatever the streak.
const Duration kStreakCountUpDuration = Duration(milliseconds: 1500);

/// Backwards draw-in of the current-streak band, today -> first day,
/// whatever the streak.
const Duration kStreakBandDrawInDuration = Duration(seconds: 2);

/// One gentle pulse of the today cell, in and out.
const Duration kStreakPulseCycle = Duration(seconds: 1);

/// How many today pulses play in one burst.
const int kStreakPulseCycles = 3;

/// How long the hero flame flickers in one burst.
const Duration kStreakFlickerBurst = Duration(seconds: 2);

/// How many flickers fit into one [kStreakFlickerBurst].
const int kStreakFlickerCycles = 3;

/// The pause between two flame / today-pulse bursts.
const Duration kStreakLoopRest = Duration(seconds: 3);

/// The opening sequence's steps, in play order.
enum StreakOpeningStep { countUp, bandDrawIn, todayPulse }

/// The steps that apply: a live streak has a number to count up and a band
/// to draw in; the today pulse only plays while today isn't practiced yet.
List<StreakOpeningStep> streakOpeningSteps({
  required bool hasStreak,
  required bool todayPending,
}) => [
  if (hasStreak) ...[StreakOpeningStep.countUp, StreakOpeningStep.bandDrawIn],
  if (todayPending) StreakOpeningStep.todayPulse,
];

/// Plays the Streak Details opening sequence once, then loops the flame and
/// the today pulse. Every animation is exposed in its display form:
/// [countUp] and [bandDrawIn] as 0..1 progress, [flameFlicker] and
/// [todayPulse] as a 0..1 intensity that rests at 0.
class StreakDetailsMotion {
  StreakDetailsMotion({
    required TickerProvider vsync,
    required bool hasStreak,
    required bool todayPending,
  }) : _hasStreak = hasStreak,
       _todayPending = todayPending,
       _steps = streakOpeningSteps(
         hasStreak: hasStreak,
         todayPending: todayPending,
       ) {
    _countUp = AnimationController(
      vsync: vsync,
      duration: kStreakCountUpDuration,
      value: _steps.contains(StreakOpeningStep.countUp) ? 0 : 1,
    )..addStatusListener(_onStepStatus);
    _bandDrawIn = AnimationController(
      vsync: vsync,
      duration: kStreakBandDrawInDuration,
      value: _steps.contains(StreakOpeningStep.bandDrawIn) ? 0 : 1,
    )..addStatusListener(_onStepStatus);
    _flame = AnimationController(
      vsync: vsync,
      duration: kStreakFlickerBurst + kStreakLoopRest,
    );
    _today = AnimationController(
      vsync: vsync,
      duration: kStreakPulseCycle * kStreakPulseCycles + kStreakLoopRest,
    );
    countUp = CurvedAnimation(parent: _countUp, curve: Curves.easeOutCubic);
    flameFlicker = _flame.drive(
      StreakBurstWave(
        burstFraction: _fractionOf(kStreakFlickerBurst, _flame.duration!),
        cycles: kStreakFlickerCycles,
      ),
    );
    todayPulse = _today.drive(
      StreakBurstWave(
        burstFraction: _fractionOf(
          kStreakPulseCycle * kStreakPulseCycles,
          _today.duration!,
        ),
        cycles: kStreakPulseCycles,
      ),
    );
  }

  final bool _hasStreak;
  bool _todayPending;
  final List<StreakOpeningStep> _steps;
  late final AnimationController _countUp;
  late final AnimationController _bandDrawIn;
  late final AnimationController _flame;
  late final AnimationController _today;

  /// The hero number's count-up progress, slowing down as it lands.
  late final Animation<double> countUp;

  /// The current-streak band's backwards draw-in progress.
  Animation<double> get bandDrawIn => _bandDrawIn;

  /// The hero flame's flicker intensity.
  late final Animation<double> flameFlicker;

  /// The today cell's pulse intensity.
  late final Animation<double> todayPulse;

  /// Index into [_steps] of the step playing now; `null` before [start],
  /// `_steps.length` once the sequence is through.
  int? _stepIndex;
  bool _paused = false;
  bool _finalState = false;

  /// The opening step reached last, if any — the today pulse stays the
  /// current step while it loops, as it's the sequence's final step.
  StreakOpeningStep? get currentStep {
    final int? index = _stepIndex;
    if (_finalState || index == null || index >= _steps.length) return null;
    return _steps[index];
  }

  /// Whether the opening sequence has started (or been replaced by the
  /// final state).
  bool get started => _stepIndex != null || _finalState;

  /// Starts the opening sequence. Plays once: later calls are no-ops.
  void start() {
    if (started) return;
    _stepIndex = 0;
    _sync();
  }

  /// Holds every animation where it is (screen not visible).
  void pause() {
    _paused = true;
    _sync();
  }

  /// Continues whatever [pause] held, in its normal rhythm.
  void resume() {
    _paused = false;
    _sync();
  }

  /// Reduce motion: jumps to the final frame, and nothing plays or loops
  /// from here on.
  void showFinalState() {
    _finalState = true;
    _countUp.value = 1;
    _bandDrawIn.value = 1;
    _flame.value = 0;
    _today.value = 0;
  }

  /// Today got practiced while the screen is open: the today pulse stops
  /// for good.
  void stopTodayPulse() {
    _todayPending = false;
    _today.value = 0;
  }

  void dispose() {
    _countUp.dispose();
    _bandDrawIn.dispose();
    _flame.dispose();
    _today.dispose();
  }

  void _onStepStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || currentStep == null) return;
    _stepIndex = _stepIndex! + 1;
    _sync();
  }

  bool _reached(StreakOpeningStep step) {
    final int? index = _stepIndex;
    final int position = _steps.indexOf(step);
    return index != null && position >= 0 && index >= position;
  }

  /// Runs exactly the controllers the current state calls for and holds
  /// all others — one-shot steps continue towards their end, loops repeat
  /// from where they were held.
  void _sync() {
    if (_finalState) return;
    final bool active = !_paused && _stepIndex != null;
    final StreakOpeningStep? step = currentStep;
    _run(_countUp, active && step == StreakOpeningStep.countUp);
    _run(_bandDrawIn, active && step == StreakOpeningStep.bandDrawIn);
    // The flame starts flickering with the count-up and keeps going.
    _run(_flame, active && _hasStreak, loop: true);
    _run(
      _today,
      active && _todayPending && _reached(StreakOpeningStep.todayPulse),
      loop: true,
    );
  }

  static void _run(
    AnimationController controller,
    bool shouldRun, {
    bool loop = false,
  }) {
    if (shouldRun == controller.isAnimating) return;
    if (!shouldRun) {
      controller.stop();
    } else if (loop) {
      controller.repeat();
    } else {
      controller.forward();
    }
  }

  static double _fractionOf(Duration part, Duration whole) =>
      part.inMicroseconds / whole.inMicroseconds;
}

/// One loop period of a burst animation: [cycles] smooth 0 -> 1 -> 0 waves
/// over the first [burstFraction] of `t`, then rest at 0 for the remainder
/// — so a looping controller alternates bursts and rests, and never holds
/// mid-swell at a burst's end.
class StreakBurstWave extends Animatable<double> {
  final double burstFraction;
  final int cycles;

  const StreakBurstWave({required this.burstFraction, required this.cycles});

  @override
  double transform(double t) {
    if (t >= burstFraction) return 0;
    return streakPulseWave(t / burstFraction, cycles: cycles);
  }
}

/// A 0 -> 1 -> 0 wave repeated [cycles] times over `t` in `[0, 1]`, ending
/// exactly at rest (0).
double streakPulseWave(double t, {int cycles = kStreakPulseCycles}) {
  final double s = math.sin(math.pi * cycles * t);
  return s * s;
}
