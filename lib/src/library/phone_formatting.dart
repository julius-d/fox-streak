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
/// so `isValidPhoneAnswer` still rejects it. The caret is parked at the end,
/// which keeps typing cursor-stable for a single appended-at-end field.
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
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}
