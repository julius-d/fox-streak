// Display-only phone grouping for the item editor (issue #004).
//
// Stored phone values stay digits-only (`^[0-9]{3,15}$`, see
// `validation.dart` `normalizePhone`); this file only formats digits with
// spaces for readability (e.g. `0171 123 4567`). The grouping is
// display-only: the repository normalises on save, and tests assert
// digits-stored + spaces-display-only (exact spacing is an implementer
// choice, so keep [groupPhoneForDisplay] pure and unit-tested).

import 'package:flutter/services.dart';

import '../data/validation.dart';

/// Groups a digits-only phone string into space-separated blocks of 3.
///
/// Pure display helper: `01711234567` becomes `017 112 345 67`. Returns the
/// input unchanged when it contains anything but digits (so validation can
/// still reject it) and never touches stored values.
String groupPhoneForDisplay(String digits) {
  if (digits.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(digits)) return digits;
  final parts = <String>[];
  for (var i = 0; i < digits.length; i += 3) {
    final end = (i + 3 < digits.length) ? i + 3 : digits.length;
    parts.add(digits.substring(i, end));
  }
  return parts.join(' ');
}

/// Live grouping formatter for the phone editor field (display-only).
///
/// Strips separators via [normalizePhone] (spaces, `-`, `/`, `(`, `)`, `.`,
/// `+`) so pasted numbers are accepted, then re-applies [groupPhoneForDisplay].
/// Input containing other characters (e.g. letters) passes through untouched
/// so `isValidPhoneAnswer` still rejects it.
///
/// Caret placement is cursor-preserving (issue #046): [newValue]'s selection
/// already reflects where the user's raw edit landed in [newValue.text], so
/// the formatter counts how many digits sit at-or-before that raw cursor
/// position, then places the new caret right after the same digit count in
/// the re-grouped string. This keeps the caret stable for edits anywhere in
/// the field (not just appends at the end), since the digit count on either
/// side of an insertion/deletion point doesn't shift when separators are
/// re-flowed around it.
class PhoneGroupingFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (RegExp(r'[^0-9\s\-/().+]').hasMatch(text)) return newValue;
    final digits = normalizePhone(text);
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final grouped = groupPhoneForDisplay(digits);
    final rawCursor = newValue.selection.baseOffset.clamp(0, text.length);
    final digitsBeforeCursor = normalizePhone(text.substring(0, rawCursor))
        .length;
    final newOffset = _offsetAfterDigits(grouped, digitsBeforeCursor);
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  /// Finds the offset right after the [digitCount]-th digit in [text],
  /// or the end of [text] if it has fewer digits than that.
  static int _offsetAfterDigits(String text, int digitCount) {
    if (digitCount <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < text.length; i++) {
      if (_isDigit(text, i)) {
        seen++;
        if (seen == digitCount) return i + 1;
      }
    }
    return text.length;
  }

  static bool _isDigit(String text, int index) {
    final code = text.codeUnitAt(index);
    return code >= 0x30 && code <= 0x39;
  }
}
