// Integration test for the #132 Streak Details motion: drives the real
// `FoxStreakApp` from Home's streak badge to Streak Details and samples the
// screen while it opens. The opening sequence plays one step after the
// other — count-up, then the band drawing in backwards, then the today
// pulse — and afterwards the flame and the today pulse keep looping.
//
// Asserts ordering invariants over the samples instead of exact times, so a
// slow device frame can't make it flaky.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/stats/activity_calendar_view.dart';

import 'helpers.dart';

/// Wednesday 2026-10-14.
class _FixedClock extends Clock {
  @override
  DateTime now() => DateTime(2026, 10, 14, 9);
}

typedef _Sample = ({
  int count,
  double latestBand,
  double earliestBand,
  double flame,
  double today,
});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the real Streak Details plays count-up -> band -> today pulse '
      'in order, then keeps the flame and today pulse looping', (tester) async {
    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = _FixedClock();
    final statsRepo = StatsRepository(db, clock);
    await statsRepo.setOnboarded();
    // A 9-day streak Mon 2026-10-05 .. Tue 2026-10-13, today not practiced
    // yet: all three steps apply. Week columns: Oct 5..11 (earliest) and
    // Oct 12..13 (latest, drawn first).
    for (var d = 5; d <= 13; d++) {
      await statsRepo.recordDailyActivity(
        day: '2026-10-${d.toString().padLeft(2, '0')}',
        xpDelta: 20,
        source: DailyActivitySource.lessonCompleted,
      );
    }
    await statsRepo.setStreak(streakCount: 9, lastActiveDay: '2026-10-13');

    await pumpFoxStreakApp(tester, db: db, clock: clock);
    await tester.tap(find.byKey(const Key('streakBadgeButton')));

    double reveal(String firstDay) {
      final Finder band = find.byKey(Key('activityCalendarBand-$firstDay'));
      if (band.evaluate().isEmpty) return 0;
      return (tester.widget<CustomPaint>(band).painter! as StreakBandPainter)
          .reveal;
    }

    double scaleAbove(Key key) {
      final Finder child = find.byKey(key);
      if (child.evaluate().isEmpty) return 1;
      return tester
          .widget<Transform>(
            find.ancestor(of: child, matching: find.byType(Transform)).first,
          )
          .transform
          .getMaxScaleOnAxis();
    }

    final samples = <_Sample>[];
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final Finder count = find.byKey(const Key('streakHeroCount'));
      if (count.evaluate().isEmpty) continue;
      samples.add((
        count: int.parse(tester.widget<Text>(count).data!),
        latestBand: reveal('2026-10-12'),
        earliestBand: reveal('2026-10-05'),
        flame: scaleAbove(const Key('streakHeroFlame')),
        today: scaleAbove(const Key('activityCalendarTodayMarker')),
      ));
    }

    expect(samples, isNotEmpty);
    // 1. Count-up: visibly in between at some point, and done before the
    //    band starts.
    expect(samples.any((s) => s.count > 0 && s.count < 9), isTrue);
    for (final s in samples.where((s) => s.latestBand > 0)) {
      expect(s.count, 9);
    }
    // 2. Band: drawn backwards (latest column first), complete before the
    //    today pulse starts.
    for (final s in samples.where((s) => s.earliestBand > 0)) {
      expect(s.latestBand, 1);
    }
    for (final s in samples.where((s) => s.today > 1.001)) {
      expect(s.earliestBand, 1);
    }
    // 3. Today pulse and flame flicker both play — and still come back
    //    after the opening sequence (~3.5 s in, the last ~5 s of samples).
    expect(samples.any((s) => s.today > 1.001), isTrue);
    final later = samples.skip(samples.length - 50);
    expect(later.any((s) => s.flame > 1.001), isTrue);
    expect(later.any((s) => s.today > 1.001), isTrue);
    expect(samples.last.count, 9);
    expect(samples.last.earliestBand, 1);
  });
}
