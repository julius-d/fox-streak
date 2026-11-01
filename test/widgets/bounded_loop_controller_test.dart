// Unit coverage for `BoundedLoopController` (issue #079): the shared
// controller/timer/dispose/reduce-motion bookkeeping extracted from
// `FoxPet`'s loop (#071) and `LootboxScreen`'s closed-state pulse (#073).
// `FoxPet`'s own tests (test/widgets/fox_pet_test.dart) and `LootboxScreen`'s
// (test/pet/lootbox_screen_test.dart, test/pet/pet_screens_test.dart,
// integration_test/issue073_lootbox_closed_pulse_test.dart) already cover
// both call sites end to end; this file drives the shared class directly,
// including the race this extraction specifically fixes for `FoxPet`:
// reduce motion turning on *during* an already-scheduled pause.
//
// Two timing quirks of driving a plain `AnimationController` + `Timer` via
// `tester.pump` directly (rather than through a widget's build, as
// `FoxPet`/`LootboxScreen` do):
// - A freshly (re)started `Ticker` only records its own start timestamp on
//   the *next serviced* frame, so `start()`'s very first tick needs one
//   zero-duration `tester.pump()` first to establish that baseline. A
//   `reverse()`/replay triggered from inside an already-executing tick
//   (this class's own status listener/pause-timer callback) doesn't need
//   this — it's already mid-frame.
// - `Simulation.isDone` (and so the `completed`/`dismissed` status flip,
//   and a `Timer`'s own fire check) needs elapsed time strictly *past* its
//   target, not merely equal to it, so pumps meant to cross a
//   completion/pause boundary pad it by 1ms.
//
// Tests dispose the controller explicitly at the end of their body rather
// than via `addTearDown`, since `addTearDown` callbacks run outside the
// fake-async zone `testWidgets` drives `Timer`s through — too late for
// `TestWidgetsFlutterBinding`'s own "no pending timer" invariant check,
// which runs before them.
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/widgets/bounded_loop_controller.dart';

void main() {
  group('BoundedLoopPlayback.forwardOnly', () {
    testWidgets('plays once, pauses, then replays from the start', (
      tester,
    ) async {
      bool reduceMotion = false;
      final loop = BoundedLoopController(
        vsync: const TestVSync(),
        playback: BoundedLoopPlayback.forwardOnly,
        duration: const Duration(milliseconds: 100),
        pauseDuration: () => const Duration(milliseconds: 200),
        reduceMotion: () => reduceMotion,
      );

      loop.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 101));
      expect(loop.controller.status, AnimationStatus.completed);
      expect(loop.controller.isAnimating, isFalse);

      // Mid-pause: no replay yet.
      await tester.pump(const Duration(milliseconds: 100));
      expect(loop.controller.isAnimating, isFalse);

      // Pause elapses: replays from 0.
      await tester.pump(const Duration(milliseconds: 100));
      expect(loop.controller.isAnimating, isTrue);
      expect(loop.controller.value, 0);

      loop.dispose();
    });

    testWidgets('does not schedule a pause when reduce motion is already on at '
        'completion, holding the final frame instead', (tester) async {
      final loop = BoundedLoopController(
        vsync: const TestVSync(),
        playback: BoundedLoopPlayback.forwardOnly,
        duration: const Duration(milliseconds: 100),
        pauseDuration: () => const Duration(milliseconds: 200),
        reduceMotion: () => true,
      );

      loop.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 101));
      expect(loop.controller.status, AnimationStatus.completed);

      await tester.pump(const Duration(seconds: 5));
      expect(loop.controller.isAnimating, isFalse);
      expect(loop.controller.status, AnimationStatus.completed);

      loop.dispose();
    });

    testWidgets(
      'reduce motion turning on during an already-scheduled pause skips '
      'the replay instead of firing it anyway (the #079 race fix)',
      (tester) async {
        bool reduceMotion = false;
        final loop = BoundedLoopController(
          vsync: const TestVSync(),
          playback: BoundedLoopPlayback.forwardOnly,
          duration: const Duration(milliseconds: 100),
          pauseDuration: () => const Duration(milliseconds: 200),
          reduceMotion: () => reduceMotion,
        );

        loop.start();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 101));
        expect(loop.controller.status, AnimationStatus.completed);

        // Pause is now pending (reduce motion was off at completion).
        // Flip it on before the pause elapses.
        reduceMotion = true;
        await tester.pump(const Duration(milliseconds: 201));

        expect(loop.controller.isAnimating, isFalse);
        expect(loop.controller.status, AnimationStatus.completed);

        loop.dispose();
      },
    );

    testWidgets('dispose cancels a pending pause, leaving no pending timer', (
      tester,
    ) async {
      final loop = BoundedLoopController(
        vsync: const TestVSync(),
        playback: BoundedLoopPlayback.forwardOnly,
        duration: const Duration(milliseconds: 100),
        pauseDuration: () => const Duration(milliseconds: 200),
        reduceMotion: () => false,
      );

      loop.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 101));
      loop.dispose();
      // If the pause timer survived dispose, this would throw at tear-down
      // ("A Timer is still pending even after the widget tree was
      // disposed."); pumping well past it here proves it didn't.
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('cancelPendingPause disarms a stale pause without touching the '
        'controller itself', (tester) async {
      final loop = BoundedLoopController(
        vsync: const TestVSync(),
        playback: BoundedLoopPlayback.forwardOnly,
        duration: const Duration(milliseconds: 100),
        pauseDuration: () => const Duration(milliseconds: 200),
        reduceMotion: () => false,
      );

      loop.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 101));
      expect(loop.controller.status, AnimationStatus.completed);

      loop.cancelPendingPause();
      await tester.pump(const Duration(seconds: 1));
      expect(loop.controller.isAnimating, isFalse);
      expect(loop.controller.status, AnimationStatus.completed);

      loop.dispose();
    });
  });

  group('BoundedLoopPlayback.pingPong', () {
    testWidgets('plays forward then back with no pause, then pauses before '
        'the next breath', (tester) async {
      final loop = BoundedLoopController(
        vsync: const TestVSync(),
        playback: BoundedLoopPlayback.pingPong,
        duration: const Duration(milliseconds: 100),
        pauseDuration: () => const Duration(milliseconds: 200),
        reduceMotion: () => false,
      );

      loop.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 101));
      // Reverse leg starts immediately, no pause in between.
      expect(loop.controller.status, AnimationStatus.reverse);

      await tester.pump(const Duration(milliseconds: 101));
      expect(loop.controller.status, AnimationStatus.dismissed);
      expect(loop.controller.isAnimating, isFalse);

      // Pause, then the next breath starts.
      await tester.pump(const Duration(milliseconds: 200));
      expect(loop.controller.isAnimating, isTrue);
      expect(loop.controller.status, AnimationStatus.forward);

      loop.dispose();
    });

    testWidgets('startIfIdle is a no-op while already animating or paused', (
      tester,
    ) async {
      final loop = BoundedLoopController(
        vsync: const TestVSync(),
        playback: BoundedLoopPlayback.pingPong,
        duration: const Duration(milliseconds: 100),
        pauseDuration: () => const Duration(milliseconds: 200),
        reduceMotion: () => false,
      );

      loop.startIfIdle();
      await tester.pump();
      expect(loop.controller.isAnimating, isTrue);
      expect(loop.controller.value, 0);

      // Mid-breath: calling again must not restart from 0.
      await tester.pump(const Duration(milliseconds: 50));
      final double midBreath = loop.controller.value;
      expect(midBreath, isNot(0));

      loop.startIfIdle();
      expect(loop.controller.value, midBreath);

      loop.dispose();
    });

    testWidgets('stop halts mid-breath without resetting the value', (
      tester,
    ) async {
      final loop = BoundedLoopController(
        vsync: const TestVSync(),
        playback: BoundedLoopPlayback.pingPong,
        duration: const Duration(milliseconds: 100),
        pauseDuration: () => const Duration(milliseconds: 200),
        reduceMotion: () => false,
      );

      loop.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final double midBreath = loop.controller.value;
      expect(midBreath, isNot(0));

      loop.stop();
      expect(loop.controller.isAnimating, isFalse);
      expect(loop.controller.value, midBreath);

      // A pending pause would have fired by now; stop() must have
      // cancelled it too.
      await tester.pump(const Duration(seconds: 1));
      expect(loop.controller.isAnimating, isFalse);
      expect(loop.controller.value, midBreath);

      loop.dispose();
    });

    testWidgets('reset halts mid-breath and snaps back to the static frame', (
      tester,
    ) async {
      final loop = BoundedLoopController(
        vsync: const TestVSync(),
        playback: BoundedLoopPlayback.pingPong,
        duration: const Duration(milliseconds: 100),
        pauseDuration: () => const Duration(milliseconds: 200),
        reduceMotion: () => false,
      );

      loop.start();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(loop.controller.value, isNot(0));

      loop.reset();
      expect(loop.controller.isAnimating, isFalse);
      expect(loop.controller.value, 0);

      loop.dispose();
      // `reset`'s direct `value =` write re-triggers the `dismissed`
      // status (same as `LootboxScreen`'s pre-#079 `_resetPulse`),
      // scheduling a pause that would otherwise skip its replay via the
      // reduce-motion re-check instead — `dispose` must still cancel it
      // outright so nothing is left pending.
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
