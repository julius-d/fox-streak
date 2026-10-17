// Unit tests for the #004 pure display helpers.
//
// `formatDateForDisplay` (owned by #004, reused by #009) and
// `groupPhoneForDisplay` / `PhoneGroupingFormatter` (display-only phone
// grouping; storage stays digits-only).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/library/date_display.dart';
import 'package:fox_streak_app/src/library/phone_formatting.dart';

void main() {
  group('formatDateForDisplay', () {
    test('DE renders TT.MM.JJJJ', () {
      expect(
        formatDateForDisplay('1985-05-14', const Locale('de')),
        '14.05.1985',
      );
    });

    test('EN renders MM/DD/YYYY', () {
      expect(
        formatDateForDisplay('1985-05-14', const Locale('en')),
        '05/14/1985',
      );
    });

    test('DE with country code still renders German order', () {
      expect(
        formatDateForDisplay('1985-05-14', const Locale('de', 'DE')),
        '14.05.1985',
      );
    });

    test('invalid input passes through unchanged', () {
      expect(
        formatDateForDisplay('not-a-date', const Locale('en')),
        'not-a-date',
      );
      expect(
        formatDateForDisplay('2021-02-30', const Locale('de')),
        '2021-02-30',
      );
    });
  });

  group('groupPhoneForDisplay', () {
    test('groups digits in blocks of 3', () {
      expect(groupPhoneForDisplay('01711234567'), '017 112 345 67');
    });

    test('short input stays ungrouped', () {
      expect(groupPhoneForDisplay('01'), '01');
      expect(groupPhoneForDisplay(''), '');
    });

    test('non-digits pass through for validation to reject', () {
      expect(groupPhoneForDisplay('abc'), 'abc');
    });
  });

  group('PhoneGroupingFormatter', () {
    final formatter = PhoneGroupingFormatter();

    TextEditingValue edit(String text) => formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );

    test('paste with separators is stripped then grouped', () {
      expect(edit('0171 123-4567').text, '017 112 345 67');
      expect(edit('+49(171)/123.4567').text, '491 711 234 567');
    });

    test('letters pass through untouched', () {
      expect(edit('abc').text, 'abc');
    });

    test('clearing the field resets to an empty collapsed selection', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '017 123 456 7',
          selection: TextSelection.collapsed(offset: 13),
        ),
        const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
      expect(result.text, '');
      expect(result.selection, const TextSelection.collapsed(offset: 0));
    });

    // Cursor-preserving regroup (#046): formatEditUpdate places the new
    // caret after the same digit count that preceded the raw edit cursor,
    // instead of always collapsing to the end.
    group('cursor-preserving regroup (#046)', () {
      TextEditingValue editAt(
        TextEditingValue old,
        String rawText,
        int rawCursor,
      ) => formatter.formatEditUpdate(
        old,
        TextEditingValue(
          text: rawText,
          selection: TextSelection.collapsed(offset: rawCursor),
        ),
      );

      test('deleting a digit from the middle keeps the caret there', () {
        // "017 123 456 7" with the '1' right after "017" backspaced out.
        final result = editAt(
          const TextEditingValue(
            text: '017 123 456 7',
            selection: TextSelection.collapsed(offset: 5),
          ),
          '017 23 456 7',
          4,
        );
        expect(result.text, '017 234 567');
        expect(result.selection, const TextSelection.collapsed(offset: 3));
      });

      test('deleting a leading country-code-like prefix digit by digit', () {
        // Pasted "+49 171 234567" groups to "491 712 345 67"; backspacing
        // through the leading "49" should walk the caret back to the
        // start, not snap it to the end after every keystroke.
        final pasted = edit('+49 171 234567');
        expect(pasted.text, '491 712 345 67');

        final afterFirstBackspace = editAt(pasted, '41 712 345 67', 1);
        expect(afterFirstBackspace.text, '417 123 456 7');
        expect(
          afterFirstBackspace.selection,
          const TextSelection.collapsed(offset: 1),
        );

        final afterSecondBackspace = editAt(
          afterFirstBackspace,
          '17 123 456 7',
          0,
        );
        expect(afterSecondBackspace.text, '171 234 567');
        expect(
          afterSecondBackspace.selection,
          const TextSelection.collapsed(offset: 0),
        );
      });

      test('inserting a digit in the middle places caret after it', () {
        // "017 123 456 7" with a '9' typed between the '1' and the '7'.
        final result = editAt(
          const TextEditingValue(
            text: '017 123 456 7',
            selection: TextSelection.collapsed(offset: 2),
          ),
          '0197 123 456 7',
          3,
        );
        expect(result.text, '019 712 345 67');
        expect(result.selection, const TextSelection.collapsed(offset: 3));
      });

      test('appending at the end keeps the caret at the end', () {
        final result = editAt(
          const TextEditingValue(
            text: '017 123 456 7',
            selection: TextSelection.collapsed(offset: 13),
          ),
          '017 123 456 78',
          14,
        );
        expect(result.text, '017 123 456 78');
        expect(result.selection, const TextSelection.collapsed(offset: 14));
      });
    });
  });
}
