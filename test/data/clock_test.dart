import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/clock.dart';

import 'test_helpers.dart';

void main() {
  group('toLocalDayString', () {
    test('pads month and day', () {
      expect(toLocalDayString(DateTime(2026, 1, 2)), '2026-01-02');
      expect(toLocalDayString(DateTime(1985, 5, 14)), '1985-05-14');
      expect(toLocalDayString(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('parseDayString', () {
    test('parses valid dates to local midnight', () {
      expect(parseDayString('2026-10-11'), DateTime(2026, 10, 11));
      expect(parseDayString('1900-01-01'), DateTime(1900, 1, 1));
      expect(parseDayString('2020-02-29'), DateTime(2020, 2, 29));
    });

    test('rejects malformed strings', () {
      expect(parseDayString(''), isNull);
      expect(parseDayString('not-a-date'), isNull);
      expect(parseDayString('2026-1-1'), isNull);
      expect(parseDayString('2026/10/11'), isNull);
      expect(parseDayString('14.05.1985'), isNull);
      expect(parseDayString(' 2026-10-11'), isNull);
    });

    test('rejects impossible calendar dates', () {
      expect(parseDayString('2021-02-30'), isNull);
      expect(parseDayString('2021-02-29'), isNull);
      expect(parseDayString('2026-13-01'), isNull);
      expect(parseDayString('2026-00-10'), isNull);
      expect(parseDayString('2026-10-32'), isNull);
    });
  });

  group('Clock', () {
    test('SystemClock returns local now', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final now = SystemClock().now();
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(now.millisecondsSinceEpoch, inInclusiveRange(before, after));
    });

    test('FakeClock is controllable and formats today', () {
      final clock = FakeClock(DateTime(2026, 10, 11, 8, 30));
      expect(clock.todayDayString(), '2026-10-11');
      clock.setNow(DateTime(2026, 10, 12, 1, 5));
      expect(clock.todayDayString(), '2026-10-12');
    });
  });
}
