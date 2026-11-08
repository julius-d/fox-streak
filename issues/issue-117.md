# Issue 117: Make the wheel of fortune spin feel richer

Status: open | Priority: P3 | Type: enhancement | Refined-at: 2026-11-08

## Goal
The wheel-of-fortune reveal (#085, #087) should feel like a physical,
exciting spin instead of a flat disc that rotates and stops dead.

## Problem
- The wheel is plain colored slices with a label and a static pointer icon.
- It decelerates smoothly when left alone, but a second tap (or the
  automatic stop) makes it visibly speed up again for the final stretch
  before landing.
- There is no wind-up, no overshoot, and no feedback while slices pass the
  pointer.
- Before the first tap the screen is static and does not invite a tap.
- The landing moment only shows the won text and the shared celebration.
- The wheel ignores the system reduce-motion setting.

Related: #085, #087 (wheel), #095 (reveal tap target), #015 (design kit),
#109 (pet Hero flight, untouched here).

## Desired behavior

**Spin feel**
- A short wind-up (the wheel eases slightly backwards) before the spin
  accelerates.
- The wheel decelerates continuously towards the result, with a small
  overshoot past the winning slice and a settle back onto it. The overshoot
  stays inside the winning slice, so the pointer never visibly crosses into
  a neighboring slice.
- Stopping early with a second tap never makes the wheel speed up: it keeps
  slowing down from its current speed and lands on the same slice as an
  unhindered spin.
- The whole spin, from first tap to landing, takes at most about 4 s. An
  early stop is never slower than letting the spin run out.

**Pointer and haptics**
- The pointer flicks every time a slice boundary passes under it, so the
  flicks slow down along with the wheel.
- Each boundary gives light haptic feedback, throttled to at most one per
  about 80 ms. At full speed this is a soft buzz that turns into distinct
  ticks as the wheel slows. Haptics respect the existing haptics toggle.

**Wheel look**
- A rim with small lights, slice dividers, a hub in the center and a soft
  shadow.
- Slice labels follow the slice direction (radial) and stay legible.
- All colors come from the theme; light and dark mode both look good.

**Win moment**
- The winning slice pulses while the other slices dim. Dimmed labels keep
  at least the AA contrast the kit guarantees; the winning slice's label
  stays at full contrast.
- The existing result text and celebration stay.
- The screen-reader announcement stays the won reward, announced once; the
  highlight adds no extra announcements.

**Idle state**
- Before the first tap the wheel gently pulses and wobbles to invite a tap.
  The tap prompt stays visible.
- The invitation is a bounded loop (same pattern as the lootbox pulse), not
  an endless animation, and stops as soon as the spin starts.

**Reduce motion**
- With reduce-motion on, the wheel does a short plain spin of about 1.5 s
  with one smooth decelerating curve: no wind-up, overshoot, idle
  pulse/wobble or winning-slice pulse. The winning slice is still
  highlighted statically. The pointer still flicks per boundary and the
  throttled haptics still fire. The final result is unchanged.

## Acceptance Criteria

- The wheel always lands on the pre-drawn reward's slice, whether the spin
  runs out on its own, is stopped by a second tap at any moment, or runs
  with reduce-motion on.
- Rotation speed never increases during the stopping phase.
- Overshoot never carries the pointer outside the winning slice.
- Total spin time is at most about 4 s (about 1.5 s with reduce-motion).
- One pointer flick per slice boundary passed; none while the wheel is still
  and none after landing. Haptics are throttled as described and silent when
  the haptics toggle is off.
- A second tap during the wind-down remains a no-op and the screen never
  gets stuck (no back navigation, per the existing `PopScope`).
- Idle animation is visible before the first tap, is bounded, and is gone
  once spinning (and under reduce-motion).
- Winning slice is highlighted after landing; the result text and Continue
  button still appear.
- Dimmed slice labels meet AA contrast in light and dark mode.
- Screen-reader label, 48dp tap target and large-font layout are unchanged
  or better.
- Follows #015.
- Tests: landing slice for every segment and for early stop; speed
  monotonically non-increasing while stopping; overshoot bound; flick count
  equals the number of boundaries crossed; haptic throttling and toggle;
  reduce-motion path (duration, no flourishes); bounded idle loop with
  `pumpAndSettle` terminating; widget test for the win-moment state.
- Manual check in light and dark mode. No wheel golden.

## Out of scope
- Pet on the wheel screen or a pet reaction (revisit with #109 if wanted).
- Reward-specific celebrations (coin rain, snowflakes).
- Changing reward odds, segments, or when the wheel is shown.
- Sound.
- Wheel golden tests.
