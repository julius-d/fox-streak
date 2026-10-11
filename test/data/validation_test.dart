import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/validation.dart';

import 'test_helpers.dart';

void main() {
  group('normalizePhone', () {
    test('strips separators and plus', () {
      expect(normalizePhone('0171 123-4567'), '01711234567');
      expect(normalizePhone('+49 (0) 171/123.4567'), '4901711234567');
      expect(normalizePhone('(0164) 25 673 78 71'), '0164256737871');
    });

    test('preserves letters so validation rejects them', () {
      expect(normalizePhone('abc123'), 'abc123');
    });
  });

  group('isValidPhoneAnswer', () {
    test('accepts 3-15 digits (German leading zero kept)', () {
      expect(isValidPhoneAnswer('01711234567'), isTrue);
      expect(isValidPhoneAnswer('0164256737871'), isTrue);
      expect(isValidPhoneAnswer('123'), isTrue);
      expect(isValidPhoneAnswer('0' * 15), isTrue);
    });

    test('normalises before validating', () {
      expect(isValidPhoneAnswer('0171 123 4567'), isTrue);
      expect(isValidPhoneAnswer('(0171)/123-4567'), isTrue);
    });

    test('rejects too short, too long, letters, empty', () {
      expect(isValidPhoneAnswer('12'), isFalse);
      expect(isValidPhoneAnswer('0' * 16), isFalse);
      expect(isValidPhoneAnswer('0171-abc-4567'), isFalse);
      expect(isValidPhoneAnswer(''), isFalse);
      expect(isValidPhoneAnswer('   '), isFalse);
    });
  });

  group('isValidDateAnswer', () {
    test('accepts range 1900-01-01..today inclusive', () {
      expect(isValidDateAnswer('1900-01-01', today: kTestToday), isTrue);
      expect(isValidDateAnswer('1985-05-14', today: kTestToday), isTrue);
      expect(isValidDateAnswer('2026-10-11', today: kTestToday), isTrue);
      expect(isValidDateAnswer('2020-02-29', today: kTestToday), isTrue);
    });

    test('rejects future dates and pre-1900 dates', () {
      expect(isValidDateAnswer('2026-10-12', today: kTestToday), isFalse);
      expect(isValidDateAnswer('2030-01-01', today: kTestToday), isFalse);
      expect(isValidDateAnswer('1899-12-31', today: kTestToday), isFalse);
    });

    test('rejects malformed and impossible dates', () {
      expect(isValidDateAnswer('', today: kTestToday), isFalse);
      expect(isValidDateAnswer('14.05.1985', today: kTestToday), isFalse);
      expect(isValidDateAnswer('1985-5-14', today: kTestToday), isFalse);
      expect(isValidDateAnswer('2021-02-30', today: kTestToday), isFalse);
      expect(isValidDateAnswer('not-a-date', today: kTestToday), isFalse);
    });
  });

  group('validateDirection', () {
    test('vocab requires deEn|enDe', () {
      expect(validateDirection('vocab', 'deEn'), isNull);
      expect(validateDirection('vocab', 'enDe'), isNull);
      expect(validateDirection('vocab', null), isNotNull);
      expect(validateDirection('vocab', ''), isNotNull);
      expect(validateDirection('vocab', 'enFr'), isNotNull);
    });

    test('non-vocab must omit direction', () {
      expect(validateDirection('phone', null), isNull);
      expect(validateDirection('date', null), isNull);
      expect(validateDirection('phone', 'deEn'), isNotNull);
      expect(validateDirection('date', 'enDe'), isNotNull);
    });
  });

  group('validateChoices', () {
    test('vocab accepts absent list, rejects bad entries', () {
      expect(validateChoices('vocab', null), isNull);
      expect(validateChoices('vocab', ['a', 'b']), isNull);
      expect(validateChoices('vocab', []), isNull);
      expect(validateChoices('vocab', ['a', '']), isNotNull);
      expect(validateChoices('vocab', ['a', 1]), isNotNull);
    });

    test('non-vocab must omit choices', () {
      expect(validateChoices('phone', null), isNull);
      expect(validateChoices('phone', ['a']), isNotNull);
      expect(validateChoices('date', ['a']), isNotNull);
    });
  });
}
