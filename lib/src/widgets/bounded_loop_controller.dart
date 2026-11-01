// Shared "bounded play, pause, repeat" animation shape (issue #079),
// extracted from `FoxPet`'s loop (#071) and `LootboxScreen`'s closed-state
// tap-hint pulse (#073): both independently owned an `AnimationController`
// that plays a bounded animation once, then waits out a `Timer`-based
// pause before repeating. They stayed separate because `FoxPet` plays
// forward-only (0 -> 1, then re-`forward(from: 0)`) while the lootbox
// pulse breathes forward-then-reverse (a "ping-pong"), but the
// controller/timer/dispose/reduce-motion bookkeeping around that
// difference was identical — and a fix to one (#073's reduce-motion-mid-
// pause re-check) had no shared home, risking the same bug reappearing in
// the other.
import 'dart:async';

import 'package:flutter/material.dart';

/// How a [BoundedLoopController] plays each cycle.
enum BoundedLoopPlayback {
  /// Plays 0 -> 1, then re-`forward(from: 0)` for the next cycle —
  /// `FoxPet`'s shape.
  forwardOnly,

  /// Plays 0 -> 1, reverses 1 -> 0 with no pause in between, then pauses
  /// before the next cycle — `LootboxScreen`'s closed-state "breath"
  /// shape.
  pingPong,
}

/// Owns the `AnimationController` + pause `Timer` + dispose bookkeeping
/// shared by `FoxPet` (#071) and `LootboxScreen`'s closed-state pulse
/// (#073): play a bounded animation once (or once-and-back, for
/// [BoundedLoopPlayback.pingPong]), then wait [pauseDuration] before
/// playing again — skipping the next cycle instead whenever [reduceMotion]
/// reports true. [reduceMotion] is checked both when a cycle finishes
/// (so the pause is never scheduled at all) *and* again right before a
/// already-scheduled pause fires, closing the race where reduce motion
/// turns on *during* the pause.
///
/// Starting, stopping, and resetting stay the caller's job, since each
/// widget's own lifecycle decides when those should happen (`FoxPet`
/// always [start]s once its composition loads, regardless of
/// [reduceMotion]; `LootboxScreen` only loops while its box is closed,
/// reacting to [reduceMotion] itself via [startIfIdle]/[reset] from
/// `didChangeDependencies`) — this class only owns what was identical
/// between them.
class BoundedLoopController {
  BoundedLoopController({
    required TickerProvider vsync,
    required this.playback,
    required this.pauseDuration,
    required this.reduceMotion,
    Duration? duration,
  }) : controller = AnimationController(vsync: vsync, duration: duration) {
    controller.addStatusListener(_handleStatus);
  }

  final AnimationController controller;
  final BoundedLoopPlayback playback;

  /// Re-evaluated on every cycle/pause rather than captured once —
  /// mirrors `fox_pet.dart`'s `drawFoxPetPause` re-rolling its draw each
  /// cycle, while a caller with a fixed pause (the lootbox pulse) can
  /// just return the same [Duration] every time.
  final Duration Function() pauseDuration;

  /// Typically `() => MediaQuery.disableAnimationsOf(context)`.
  final bool Function() reduceMotion;

  Timer? _pauseTimer;
  bool _disposed = false;

  /// Cancels any pending pause, then plays from the start — the initial
  /// kick-off callers use once their animation is ready to play
  /// (`FoxPet`'s composition load; `LootboxScreen`'s unconditional first
  /// breath).
  void start() {
    cancelPendingPause();
    controller.forward(from: 0);
  }

  /// Like [start], but a no-op while already animating or mid-pause —
  /// for callers that re-enter on every `didChangeDependencies` rather
  /// than on a single one-shot event.
  void startIfIdle() {
    if (controller.isAnimating || _pauseTimer != null) return;
    start();
  }

  /// Cancels a pending pause without touching the controller itself —
  /// narrower than [stop], for callers (like `FoxPet` swapping its pet)
  /// that only need to disarm a stale pause before something else
  /// restarts the animation on its own.
  void cancelPendingPause() {
    _pauseTimer?.cancel();
    _pauseTimer = null;
  }

  /// Cancels a pending pause and halts the controller wherever it is.
  void stop() {
    cancelPendingPause();
    if (controller.isAnimating) controller.stop();
  }

  /// Like [stop], but also snaps back to the static start frame — for
  /// callers where holding mid-cycle would render a stuck-looking
  /// in-between frame instead of a plain static one.
  void reset() {
    stop();
    controller.value = 0;
  }

  void dispose() {
    _disposed = true;
    cancelPendingPause();
    controller.dispose();
  }

  void _handleStatus(AnimationStatus status) {
    switch (playback) {
      case BoundedLoopPlayback.forwardOnly:
        if (status == AnimationStatus.completed) _scheduleNextCycle();
      case BoundedLoopPlayback.pingPong:
        if (status == AnimationStatus.completed) {
          controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _scheduleNextCycle();
        }
    }
  }

  void _scheduleNextCycle() {
    if (reduceMotion()) return;
    _pauseTimer = Timer(pauseDuration(), () {
      _pauseTimer = null;
      if (_disposed || reduceMotion()) return;
      controller.forward(from: 0);
    });
  }
}
