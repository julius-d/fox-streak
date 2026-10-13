// Display-name + direction-label helpers for promptLang/answerLang (#022).
//
// Pure aside from the generated AppLocalizations type (no BuildContext
// dependency) so the item editor and both vocab-flavored exercise cards
// share one lookup instead of three separate `switch` statements.

import '../../l10n/app_localizations.dart';

/// Localized display name for a supported language code (`de`/`en`).
String languageDisplayName(String code, AppLocalizations l10n) =>
    switch (code) {
      'de' => l10n.languageDe,
      'en' => l10n.languageEn,
      _ => code,
    };

/// Builds the generic "X → Y" direction-framing label, or `null` when either
/// language is unset (non-vocab-flavored item).
String? languagePairLabel(
  String? promptLang,
  String? answerLang,
  AppLocalizations l10n,
) {
  if (promptLang == null || answerLang == null) return null;
  return l10n.exerciseDirectionLabel(
    languageDisplayName(promptLang, l10n),
    languageDisplayName(answerLang, l10n),
  );
}
