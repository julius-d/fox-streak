// Unit tests for StreakDetailsMotion (issue #132): the opening sequence
// plays count-up -> band draw-in -> today pulse one after the other with
// fixed durations, skips steps that don't apply, loops the flame and the
// today pulse with rests, pauses/resumes in rhythm, and shows the final
// state under reduce motion.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/stats/streak_motion.dart';

void main() {
  group('streakOpeningSteps', () {
    test('a live streak not practiced today plays all three steps', () {
      expect(streakOpeningSteps(hasStreak: true, todayPending: true), [
        StreakOpeningStep.countUp,
        StreakOpeningStep.bandDrawIn,
        StreakOpeningStep.todayPulse,
      ]);
    });

    test('practiced today: no today pulse', () {
      expect(streakOpeningSteps(hasStreak: true, todayPending: false), [
        StreakOpeningStep.countUp,
        StreakOpeningStep.bandDrawIn,
      ]);
    });

    test('a 0 streak has no count-up and no band', () {
      expect(streakOpeningSteps(hasStreak: false, todayPending: true), [
        StreakOpeningStep.todayPulse,
      ]);
    });
  });

  group('StreakBurstWave', () {
    const wave = StreakBurstWave(burstFraction: 0.5, cycles: 3);

    test('swells and settles during the burst, then rests at 0', () {
      expect(wave.transform(0), 0);
      expect(wave.transform(1 / 12), moreOrLessEquals(1)); // first peak
      expect(wave.transform(1 / 6), moreOrLessEquals(0)); // between pulses
      expect(wave.transform(0.5), 0);
      expect(wave.transform(0.75), 0);
      expect(wave.transform(1), 0);
    });
  });

  group('StreakDetailsMotion', () {
    late StreakDetailsMotion motion;

    StreakDetailsMotion create({
      bool hasStreak = true,
      bool todayPending = true,
    }) {
      return motion = StreakDetailsMotion(
        vsync: const TestVSync(),
        hasStreak: hasStreak,
        todayPending: todayPending,
      );
    }

    /// A widget test whose motion is disposed at the end of [body] — the
    /// loops never end on their own, and the binding checks for running
    /// tickers before any tear-down runs.
    void motionTest(String description, WidgetTesterCallback body) {
      testWidgets(description, (tester) async {
        await tester.pumpWidget(const SizedBox());
        await body(tester);
        motion.dispose();
      });
    }

    /// Advances the motion's (test) tickers by [ms] in small frames.
    Future<void> advance(WidgetTester tester, int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    motionTest('nothing plays before start: number at 0, band not drawn', (
      tester,
    ) async {
      create();
      await advance(tester, 1000);
      expect(motion.countUp.value, 0);
      expect(motion.bandDrawIn.value, 0);
      expect(motion.flameFlicker.value, 0);
      expect(motion.todayPulse.value, 0);
      expect(motion.currentStep, isNull);
    });

    motionTest('count-up (~1.5 s) -> band draw-in (~2 s) -> today pulse, '
        'one after the other, with the flame flickering from the start', (
      tester,
    ) async {
      create().start();
      await tester.pump();
      expect(motion.currentStep, StreakOpeningStep.countUp);

      await advance(tester, 500);
      expect(motion.countUp.value, inExclusiveRange(0, 1));
      expect(motion.flameFlicker.value, greaterThan(0));
      expect(motion.bandDrawIn.value, 0);

      await advance(tester, 1050); // 1.55 s
      expect(motion.countUp.value, 1);
      expect(motion.currentStep, StreakOpeningStep.bandDrawIn);
      expect(motion.todayPulse.value, 0);

      await advance(tester, 1000);
      expect(motion.bandDrawIn.value, inExclusiveRange(0, 1));
      expect(motion.todayPulse.value, 0);

      await advance(tester, 1050); // band done at ~3.5 s
      expect(motion.bandDrawIn.value, 1);
      expect(motion.currentStep, StreakOpeningStep.todayPulse);
      await advance(tester, 250);
      expect(motion.todayPulse.value, greaterThan(0));
    });

    motionTest('a 0 streak goes straight to the today pulse; the flame '
        'stays still', (tester) async {
      create(hasStreak: false).start();
      await tester.pump();
      expect(motion.currentStep, StreakOpeningStep.todayPulse);
      expect(motion.countUp.value, 1);
      expect(motion.bandDrawIn.value, 1);
      await advance(tester, 250);
      expect(motion.todayPulse.value, greaterThan(0));
      await advance(tester, 5000);
      expect(motion.flameFlicker.value, 0);
    });

    motionTest('after the sequence the flame flickers ~2 s, rests ~3 s, '
        'and flickers again', (tester) async {
      create(todayPending: false).start();
      await tester.pump();
      await advance(tester, 2500); // inside the first rest
      expect(motion.flameFlicker.value, 0);
      await advance(tester, 2750); // 5.25 s: second burst
      expect(motion.flameFlicker.value, greaterThan(0));
      await advance(tester, 2000); // 7.25 s: second rest
      expect(motion.flameFlicker.value, 0);
    });

    motionTest('the today pulse comes back after a rest: 3 pulses, then '
        'rest', (tester) async {
      create(hasStreak: false).start();
      await tester.pump();
      await advance(tester, 4500); // rest after the first 3 pulses
      expect(motion.todayPulse.value, 0);
      await advance(tester, 2000); // 6.5 s: next burst
      expect(motion.todayPulse.value, greaterThan(0));
    });

    motionTest('start plays the sequence only once', (tester) async {
      create().start();
      await tester.pump();
      await advance(tester, 1600);
      motion.start();
      await tester.pump();
      expect(motion.countUp.value, 1);
      expect(motion.currentStep, StreakOpeningStep.bandDrawIn);
    });

    motionTest('pause holds everything where it is; resume continues the '
        'same step instead of replaying', (tester) async {
      create().start();
      await tester.pump();
      await advance(tester, 700);
      motion.pause();
      final double heldCountUp = motion.countUp.value;
      final double heldFlame = motion.flameFlicker.value;
      await advance(tester, 5000);
      expect(motion.countUp.value, heldCountUp);
      expect(motion.flameFlicker.value, heldFlame);
      expect(tester.binding.hasScheduledFrame, isFalse);

      motion.resume();
      await tester.pump();
      expect(motion.countUp.value, closeTo(heldCountUp, 0.05));
      await advance(tester, 900);
      expect(motion.countUp.value, 1);
      expect(motion.currentStep, StreakOpeningStep.bandDrawIn);
    });

    motionTest('a pause before start delays the start until resumed', (
      tester,
    ) async {
      create()
        ..pause()
        ..start();
      await advance(tester, 1000);
      expect(motion.countUp.value, 0);
      motion.resume();
      await tester.pump();
      await advance(tester, 500);
      expect(motion.countUp.value, greaterThan(0));
    });

    motionTest('showFinalState: final frame at once, nothing plays or '
        'loops, not even after start/resume', (tester) async {
      create().showFinalState();
      motion
        ..start()
        ..resume();
      await tester.pump();
      expect(motion.countUp.value, 1);
      expect(motion.bandDrawIn.value, 1);
      expect(motion.flameFlicker.value, 0);
      expect(motion.todayPulse.value, 0);
      expect(motion.currentStep, isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    motionTest('showFinalState mid-run: jumps to the final frame and stops '
        'everything, without advancing the sequence', (tester) async {
      create().start();
      await tester.pump();
      await advance(tester, 700);
      motion.showFinalState();
      expect(motion.countUp.value, 1);
      expect(motion.bandDrawIn.value, 1);
      expect(motion.flameFlicker.value, 0);
      expect(motion.currentStep, isNull);
      motion.resume();
      await advance(tester, 6000);
      expect(motion.flameFlicker.value, 0);
      expect(motion.todayPulse.value, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    motionTest('stopTodayPulse stops the today pulse for good', (tester) async {
      create(hasStreak: false).start();
      await tester.pump();
      await advance(tester, 250);
      motion.stopTodayPulse();
      expect(motion.todayPulse.value, 0);
      motion
        ..pause()
        ..resume();
      await advance(tester, 7000);
      expect(motion.todayPulse.value, 0);
    });
  });
}
