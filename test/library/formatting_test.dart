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
  });
}
