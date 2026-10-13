// Unit tests for the promptLang/answerLang display-name + direction-label
// helpers (#022). Pure functions, no widget pump needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/language_display.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('languageDisplayName', () {
    test('resolves known codes to their localized name', () {
      expect(languageDisplayName('de', l10n), 'German');
      expect(languageDisplayName('en', l10n), 'English');
    });

    test('falls back to the raw code for an unknown language', () {
      expect(languageDisplayName('fr', l10n), 'fr');
    });
  });

  group('languagePairLabel', () {
    test('builds the generic "X -> Y" framing label from both codes', () {
      expect(languagePairLabel('de', 'en', l10n), 'German → English');
      expect(languagePairLabel('en', 'de', l10n), 'English → German');
    });

    test('returns null when either language is unset', () {
      expect(languagePairLabel(null, 'en', l10n), isNull);
      expect(languagePairLabel('de', null, l10n), isNull);
      expect(languagePairLabel(null, null, l10n), isNull);
    });
  });
}
