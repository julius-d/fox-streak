import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/validation.dart';

import 'test_helpers.dart';

void main() {
  group('kItemTypes', () {
    test('is the #026 split (vocab -> choice/freeText)', () {
      expect(kItemTypes, {'choice', 'freeText', 'phone', 'date'});
      expect(kItemTypes.contains('vocab'), isFalse);
    });
  });

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

  group('validateCreatorName', () {
    test('accepts free-text names incl. legacy enum values', () {
      for (final name in ['Mama', 'Ms. Smith', 'teacher', 'parent', 'x' * 50]) {
        expect(validateCreatorName(name), isNull);
        expect(isValidCreatorName(name), isTrue);
      }
    });

    test('rejects empty and over-long names', () {
      expect(validateCreatorName(null), isNotNull);
      expect(validateCreatorName(''), isNotNull);
      expect(validateCreatorName('   '), isNotNull);
      expect(validateCreatorName('x' * 51), isNotNull);
      expect(isValidCreatorName('  '), isFalse);
    });
  });

  group('kSupportedLanguages', () {
    test('is de/en for now (#022)', () {
      expect(kSupportedLanguages, {'de', 'en'});
    });
  });

  group('validateLanguagePair', () {
    test('choice accepts a valid pair, both-null, or neither being set', () {
      expect(validateLanguagePair('choice', 'de', 'en'), isNull);
      expect(validateLanguagePair('choice', 'en', 'de'), isNull);
      expect(validateLanguagePair('choice', null, null), isNull);
    });

    test('choice rejects only-one-set, same-language, and unknown codes', () {
      expect(validateLanguagePair('choice', 'de', null), isNotNull);
      expect(validateLanguagePair('choice', null, 'en'), isNotNull);
      expect(validateLanguagePair('choice', 'de', 'de'), isNotNull);
      expect(validateLanguagePair('choice', 'fr', 'en'), isNotNull);
    });

    test('freeText follows the exact same rules as choice (#022)', () {
      expect(validateLanguagePair('freeText', 'de', 'en'), isNull);
      expect(validateLanguagePair('freeText', null, null), isNull);
      expect(validateLanguagePair('freeText', 'de', null), isNotNull);
      expect(validateLanguagePair('freeText', 'fr', 'en'), isNotNull);
    });

    test('phone/date must omit the pair', () {
      expect(validateLanguagePair('phone', null, null), isNull);
      expect(validateLanguagePair('date', null, null), isNull);
      expect(validateLanguagePair('phone', 'de', 'en'), isNotNull);
      expect(validateLanguagePair('date', 'en', 'de'), isNotNull);
    });
  });

  group('gradeText', () {
    test('trims whitespace and ignores case', () {
      expect(gradeText('Hallo', '  hallo  '), isTrue);
      expect(gradeText('Hallo', 'HALLO'), isTrue);
    });

    test('strips at most one trailing sentence-ending mark', () {
      expect(gradeText('Hallo.', 'Hallo'), isTrue);
      expect(gradeText('Hallo', 'Hallo!'), isTrue);
      expect(gradeText('Hallo?', 'Hallo,'), isTrue);
      expect(gradeText('Hallo!!', 'Hallo!'), isFalse);
    });

    test('internal punctuation must match exactly', () {
      expect(gradeText("Rock'n'Roll", "Rock'n'Roll"), isTrue);
      expect(gradeText("Rock'n'Roll", 'Rocknroll'), isFalse);
      expect(gradeText('Auf-Wiedersehen', 'Auf Wiedersehen'), isFalse);
    });

    test('umlauts never normalize (strict)', () {
      expect(gradeText('Mädchen', 'Mädchen'), isTrue);
      expect(gradeText('Mädchen', 'Madchen'), isFalse);
      expect(gradeText('für', 'fuer'), isFalse);
      expect(gradeText('schön', 'schon'), isFalse);
    });

    test('ß never normalizes to ss (strict)', () {
      expect(gradeText('Straße', 'Straße'), isTrue);
      expect(gradeText('Straße', 'Strasse'), isFalse);
      expect(gradeText('groß', 'gross'), isFalse);
    });

    test('generic (direction-independent) comparisons work the same way', () {
      expect(gradeText('Paris', '  paris. '), isTrue);
      expect(gradeText('42', '42'), isTrue);
      expect(gradeText('42', '43'), isFalse);
    });
  });

  group('validateChoices', () {
    test('choice accepts absent list, rejects bad entries', () {
      expect(validateChoices('choice', null), isNull);
      expect(validateChoices('choice', ['a', 'b']), isNull);
      expect(validateChoices('choice', []), isNull);
      expect(validateChoices('choice', ['a', '']), isNotNull);
      expect(validateChoices('choice', ['a', 1]), isNotNull);
    });

    test('freeText/phone/date must omit choices', () {
      expect(validateChoices('freeText', null), isNull);
      expect(validateChoices('freeText', ['a']), isNotNull);
      expect(validateChoices('phone', null), isNull);
      expect(validateChoices('phone', ['a']), isNotNull);
      expect(validateChoices('date', ['a']), isNotNull);
    });
  });
}
