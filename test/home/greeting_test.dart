// Unit tests for Home's holiday + funny-rotation greeting layers
// (issue #061), on top of the existing time-of-day greeting (#012, #060).
//
// Pure-function tests: `greetingText` takes `AppLocalizations` + a
// `DateTime` directly (no widget tree, no injected `Clock` instance
// needed here — `home_screen_test.dart` already covers the `Clock`-backed
// wiring through the real widget).

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations_de.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/home/greeting.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final de = AppLocalizationsDe();

  group('holiday greetings', () {
    for (final (DateTime date, String expected) in <(DateTime, String)>[
      (DateTime(2026, 1, 1), 'Happy New Year!'),
      (DateTime(2026, 4, 1), 'Watch out for pranks today!'),
      (DateTime(2026, 10, 31), 'Happy Halloween!'),
      (DateTime(2026, 12, 24), 'Christmas Eve is here!'),
      (DateTime(2026, 12, 25), 'Merry Christmas!'),
    ]) {
      test('${date.month}/${date.day} shows "$expected" at any hour', () {
        for (final hour in [0, 9, 14, 23]) {
          final now = DateTime(date.year, date.month, date.day, hour);
          expect(greetingText(l10n, now, null), expected);
          expect(greetingText(l10n, now, 'Mia'), expected);
        }
      });
    }

    test('holiday copy is also translated (DE spot check: New Year)', () {
      expect(
        greetingText(de, DateTime(2026, 1, 1, 9), null),
        'Frohes neues Jahr!',
      );
    });

    test('a holiday always wins over the funny rotation on its date', () {
      // Precedence check, not a rotation-odds check: whatever the funny
      // rotation would have picked for this calendar day is irrelevant —
      // the holiday table is consulted first.
      expect(
        greetingText(l10n, DateTime(2026, 1, 1, 9), null),
        'Happy New Year!',
      );
    });
  });

  group('funny rotation', () {
    test('a selected day shows the same funny variant regardless of hour '
        'or rebuild (deterministic per calendar day, not per rebuild)', () {
      for (final hour in [0, 9, 23]) {
        final now = DateTime(2026, 1, 3, hour);
        expect(greetingText(l10n, now, null), 'Ready to level up today?');
        // Calling again (simulating a rebuild) reproduces the same pick.
        expect(greetingText(l10n, now, null), 'Ready to level up today?');
      }
    });

    test('funny copy is generic: a display name does not change it', () {
      expect(
        greetingText(l10n, DateTime(2026, 1, 3, 9), 'Mia'),
        'Ready to level up today?',
      );
    });

    test('a non-selected day falls back to the plain time-of-day greeting', () {
      // Computed from the same deterministic seed for 2026-01-02: not
      // selected that day.
      expect(
        greetingText(l10n, DateTime(2026, 1, 2, 9), null),
        'Good morning!',
      );
      expect(
        greetingText(l10n, DateTime(2026, 1, 2, 9), 'Mia'),
        'Good morning, Mia!',
      );
    });

    test('different selected days can pick different pool entries', () {
      // 2026-01-11: selected, pool index 1 — distinct from 2026-01-03's
      // index-0 pick above.
      expect(
        greetingText(l10n, DateTime(2026, 1, 11, 9), null),
        'Your foxy brain is warming up!',
      );
    });

    test('funny copy is also translated (DE spot checks: slots 2/4/6/8, '
        'reworded by issue #086)', () {
      // Each date is a day whose deterministic per-day pick lands on the
      // pool index backing that funny slot (indices are 0-based; slot N
      // is pool index N-1).
      expect(
        greetingText(de, DateTime(2026, 1, 11, 9), null),
        'Moin',
      ); // homeGreetingFunny2, pool index 1
      expect(
        greetingText(de, DateTime(2026, 2, 19, 9), null),
        'Hi',
      ); // homeGreetingFunny4, pool index 3
      expect(
        greetingText(de, DateTime(2026, 1, 24, 9), null),
        'Lass uns loslegen',
      ); // homeGreetingFunny6, pool index 5
      expect(
        greetingText(de, DateTime(2026, 5, 28, 9), null),
        'Wie geht es Dir?',
      ); // homeGreetingFunny8, pool index 7
    });
  });

  group('plain time-of-day fallback (unchanged by #061)', () {
    test('still used on an ordinary, non-selected, non-holiday day', () {
      final now = DateTime(2026, 1, 2, 2);
      expect(greetingText(l10n, now, null), 'Up late?');
      expect(greetingText(l10n, now, 'Mia'), 'Up late, Mia?');
    });
  });
}
