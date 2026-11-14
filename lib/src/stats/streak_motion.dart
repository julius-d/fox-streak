// Shared timing for the Streak Details screen's opening animations
// (issue #128): the hero count-up + flame flicker, the backwards streak-band
// draw-in, and the today pulse. All are bounded (they play once per screen
// open, then rest) and skipped under the system "reduce motion" setting.
import 'dart:math' as math;

/// Count-up of the hero's streak number — at most ~1 s, whatever the streak.
const Duration kStreakCountUpDuration = Duration(milliseconds: 900);

/// Backwards draw-in of the current-streak band, today -> first day.
const Duration kStreakBandDrawInDuration = Duration(milliseconds: 900);

/// One gentle pulse (hero flame flicker / today cell), in and out.
const Duration kStreakPulseCycle = Duration(milliseconds: 700);

/// How many pulses play per screen open before the element rests.
const int kStreakPulseCycles = 3;

/// A 0 -> 1 -> 0 wave repeated [cycles] times over `t` in `[0, 1]`, ending
/// exactly at rest (0) — so a pulse driven by a single forward
/// `AnimationController` run never freezes mid-swell.
double streakPulseWave(double t, {int cycles = kStreakPulseCycles}) {
  final double s = math.sin(math.pi * cycles * t);
  return s * s;
}
