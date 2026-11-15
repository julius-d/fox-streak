// Unit tests for the v18 one-time streak correction (issue #132): recorded
// freeze days inside the current streak are added to the old count.

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/streak_freeze_correction.dart';

void main() {
  int correct(int streakCount, String? lastActiveDay, Set<String> freezes) =>
      streakCountIncludingFreezeDays(
        streakCount: streakCount,
        lastActiveDay: lastActiveDay,
        freezeDays: freezes,
      );

  test('practiced Mon-Fri, Saturday saved by a freeze, practiced Sunday: '
      'the old 6 becomes 7', () {
    // Mon 2026-10-05 .. Sun 2026-10-11, the freeze on Sat 2026-10-10.
    expect(correct(6, '2026-10-11', {'2026-10-10'}), 7);
  });

  test('right after the launch bridge, lastActiveDay is the freeze day '
      'itself', () {
    expect(correct(5, '2026-10-10', {'2026-10-10'}), 6);
  });

  test('several freezes in the run, across a month boundary', () {
    expect(correct(3, '2026-10-02', {'2026-10-01', '2026-09-29'}), 5);
  });

  test('freeze days outside the current run are not counted', () {
    // Run: Oct 9..11 (3 practiced days); Oct 7 belongs to an older run.
    expect(correct(3, '2026-10-11', {'2026-10-07'}), 3);
  });

  test('no streak, no anchor or a malformed anchor: left as it is', () {
    expect(correct(0, '2026-10-11', {'2026-10-11'}), 0);
    expect(correct(4, null, {'2026-10-11'}), 4);
    expect(correct(4, 'x', {'2026-10-11'}), 4);
  });
}
