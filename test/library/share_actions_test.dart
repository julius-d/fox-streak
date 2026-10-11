// Unit tests for share filename building (review fix on #003).
//
// `shareFileNameForTitle` is pure so it is tested directly: `shareSet`
// itself opens the platform share sheet and is not widget-testable.

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/library/share_actions.dart';

void main() {
  group('shareFileNameForTitle', () {
    test('appends the .foxstreak.json suffix', () {
      expect(shareFileNameForTitle('Animals'), 'Animals.foxstreak.json');
    });

    test('keeps German umlauts and spaces', () {
      expect(
        shareFileNameForTitle('Geburtstage – Familie'),
        'Geburtstage  Familie.foxstreak.json',
      );
      expect(
        shareFileNameForTitle('Bär Süß Öl Übung 123'),
        'Bär Süß Öl Übung 123.foxstreak.json',
      );
    });

    test('strips punctuation but keeps dashes', () {
      expect(
        shareFileNameForTitle('Mama "Best" (copy)!'),
        'Mama Best copy.foxstreak.json',
      );
      expect(shareFileNameForTitle('a-b_c'), 'a-b_c.foxstreak.json');
    });

    test('blank or fully-stripped titles fall back to set', () {
      expect(shareFileNameForTitle(''), 'set.foxstreak.json');
      expect(shareFileNameForTitle('   '), 'set.foxstreak.json');
      expect(shareFileNameForTitle('!!!'), 'set.foxstreak.json');
    });

    test('trims surrounding whitespace', () {
      expect(shareFileNameForTitle('  Tiere  '), 'Tiere.foxstreak.json');
    });
  });
}
