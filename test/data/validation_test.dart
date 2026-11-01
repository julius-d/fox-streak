import 'dart:convert';

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

  group('kImageTypes (#014)', () {
    test('is the closed emoji|base64|url enum (no reserved lottie value)', () {
      expect(kImageTypes, {'emoji', 'base64', 'url'});
      expect(kImageTypes.contains('lottie'), isFalse);
    });
  });

  group('isValidImageType (#014)', () {
    test('accepts emoji/base64/url, rejects everything else', () {
      expect(isValidImageType('emoji'), isTrue);
      expect(isValidImageType('base64'), isTrue);
      expect(isValidImageType('url'), isTrue);
      expect(isValidImageType('lottie'), isFalse);
      expect(isValidImageType(''), isFalse);
    });
  });

  group('isValidImageContent (#014)', () {
    test('emoji accepts any non-empty (after trim) string', () {
      expect(isValidImageContent('emoji', '🐶'), isTrue);
      expect(isValidImageContent('emoji', 'a'), isTrue);
      expect(isValidImageContent('emoji', '  '), isFalse);
      expect(isValidImageContent('emoji', ''), isFalse);
    });

    test('base64 accepts decodable data, rejects malformed data', () {
      expect(isValidImageContent('base64', base64Encode([1, 2, 3])), isTrue);
      expect(isValidImageContent('base64', 'not-base64!!'), isFalse);
      expect(isValidImageContent('base64', ''), isFalse);
    });

    test('base64 accepts a multi-line paste (e.g. the `base64` CLI wraps '
        'output at ~76 chars) by stripping embedded whitespace', () {
      final encoded = base64Encode(List.generate(60, (i) => i));
      final wrapped = '${encoded.substring(0, 40)}\n${encoded.substring(40)}';
      expect(isValidImageContent('base64', wrapped), isTrue);
      // All-whitespace (nothing left after stripping) is still rejected.
      expect(isValidImageContent('base64', '  \n  \n '), isFalse);
    });

    test('url accepts http/https with a host, rejects everything else', () {
      expect(isValidImageContent('url', 'https://example.com/fox.png'), isTrue);
      expect(isValidImageContent('url', 'http://example.com/fox.png'), isTrue);
      expect(isValidImageContent('url', 'ftp://example.com/fox.png'), isFalse);
      expect(isValidImageContent('url', 'not a url'), isFalse);
      expect(isValidImageContent('url', 'https://'), isFalse);
    });

    test('unknown type is always invalid', () {
      expect(isValidImageContent('lottie', 'anything'), isFalse);
    });
  });

  group('normalizeImageContent (#014)', () {
    test('base64 strips all whitespace, including embedded newlines', () {
      expect(normalizeImageContent('base64', 'AB\nCD\n EF '), 'ABCDEF');
    });

    test('emoji/url trim only (no internal-whitespace meaning)', () {
      expect(normalizeImageContent('emoji', '  🐶  '), '🐶');
      expect(
        normalizeImageContent('url', '  https://example.com/fox.png  '),
        'https://example.com/fox.png',
      );
    });
  });

  group('validateImagePair (#014)', () {
    test('both null/empty (no image) is valid', () {
      expect(validateImagePair(null, null), isNull);
    });

    test('valid emoji/base64/url pairings are valid', () {
      expect(validateImagePair('emoji', '🐶'), isNull);
      expect(validateImagePair('base64', base64Encode([1, 2, 3])), isNull);
      expect(validateImagePair('url', 'https://example.com/fox.png'), isNull);
    });

    test('only one of the pair set is rejected (both-or-neither)', () {
      expect(validateImagePair('emoji', null), isNotNull);
      expect(validateImagePair(null, '🐶'), isNotNull);
    });

    test('unknown imageType is rejected', () {
      expect(validateImagePair('lottie', 'anything'), isNotNull);
    });

    test('type-specific invalid content is rejected', () {
      expect(validateImagePair('base64', 'not-base64!!'), isNotNull);
      expect(validateImagePair('url', 'not a url'), isNotNull);
    });
  });

  group('isValidImageCopyright (#094)', () {
    test('accepts a non-empty, single-line value up to 120 chars', () {
      expect(isValidImageCopyright('© Jane Doe'), isTrue);
      expect(isValidImageCopyright('a' * kMaxImageCopyrightLength), isTrue);
    });

    test('rejects empty-after-trim, multi-line, and over-long values', () {
      expect(isValidImageCopyright(''), isFalse);
      expect(isValidImageCopyright('   '), isFalse);
      expect(isValidImageCopyright('line one\nline two'), isFalse);
      expect(
        isValidImageCopyright('a' * (kMaxImageCopyrightLength + 1)),
        isFalse,
      );
    });
  });

  group('validateImageCopyright (#094)', () {
    test('null/empty (no copyright) is always valid, regardless of '
        'imageType', () {
      expect(validateImageCopyright(null, null), isNull);
      expect(validateImageCopyright('emoji', null), isNull);
      expect(validateImageCopyright(null, ''), isNull);
    });

    test('a valid copyright is accepted for base64/url, one-sided (unlike '
        'validateImagePair\'s both-or-neither)', () {
      expect(validateImageCopyright('base64', '© Jane Doe'), isNull);
      expect(validateImageCopyright('url', '© Jane Doe'), isNull);
    });

    test('a copyright is rejected when imageType is emoji or null — a '
        'system glyph has no meaningful copyright', () {
      expect(validateImageCopyright('emoji', '© Jane Doe'), isNotNull);
      expect(validateImageCopyright(null, '© Jane Doe'), isNotNull);
    });

    test('an invalid copyright value is rejected even for base64/url', () {
      expect(validateImageCopyright('base64', 'line one\nline two'), isNotNull);
      expect(
        validateImageCopyright('url', 'a' * (kMaxImageCopyrightLength + 1)),
        isNotNull,
      );
    });
  });
}
