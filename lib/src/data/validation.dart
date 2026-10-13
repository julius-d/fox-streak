// Pure validation helpers for set items (issue #002).
//
// Kept free of Drift/Riverpod imports so the JSON codec, repositories and
// (later) exercise widgets in #008/#009 can share one implementation.
// All functions are pure and clock-independent except [isValidDateAnswer],
// which takes an explicit `today` for testability.

import 'clock.dart';

/// Allowed `items.type` values.
///
/// `vocab` (#002) was split by #026 into `choice` (#006 multiple-choice) and
/// `freeText` (#007 type-the-answer); existing `vocab` rows are migrated to
/// `choice` by `database.dart`'s schema v2 upgrade.
const Set<String> kItemTypes = {'choice', 'freeText', 'phone', 'date'};

/// Maximum length of a free-text creator name (`question_sets.created_by`).
///
/// Loosened from the old `parent|teacher|learner` enum in #003 (see #002
/// follow-up): any trimmed non-empty name up to this length is valid, e.g.
/// "Mama" or "Ms. Smith". Old enum values remain valid as plain names.
/// Share format stays v1 (loosened in place — no version bump needed).
const int kMaxCreatorNameLength = 50;

/// Validates a free-text creator name; returns an error message or `null`.
///
/// Trims before checking: empty-after-trim and over-long names are rejected.
String? validateCreatorName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'creator name must be non-empty';
  }
  if (value.trim().length > kMaxCreatorNameLength) {
    return 'creator name must be at most $kMaxCreatorNameLength characters';
  }
  return null;
}

/// True when [value] is a valid free-text creator name.
bool isValidCreatorName(String value) => validateCreatorName(value) == null;

/// Supported ISO 639-1 language codes for `items.promptLang`/`answerLang`
/// (#022). Adding a third language later is just adding a code here plus a
/// display-name string (see `language_display.dart`) — no schema/UI change.
const Set<String> kSupportedLanguages = {'de', 'en'};

/// Share-format marker + version (see `set_json_codec.dart`).
const String kShareFormat = 'foxstreak-set';
const int kShareVersion = 1;

/// Earliest storable date answer (inclusive, ISO day string).
const String kMinDateDay = '1900-01-01';

/// Phone answers must match this after normalisation.
final RegExp kPhonePattern = RegExp(r'^[0-9]{3,15}$');

/// Characters stripped by phone normalisation: spaces, `-`, `/`, `(`, `)`,
/// `.` and any `+` (per #002 / #008).
final RegExp kPhoneStripPattern = RegExp(r'[\s\-/().+]');

/// Strips separators so `0164 25/673(7871)` and `+49...` become digits-only.
///
/// Only removes the characters listed in [kPhoneStripPattern]; anything else
/// (e.g. letters) is preserved so validation still rejects it.
String normalizePhone(String raw) => raw.replaceAll(kPhoneStripPattern, '');

/// True when [answer] is 3–15 digits after [normalizePhone].
bool isValidPhoneAnswer(String answer) =>
    kPhonePattern.hasMatch(normalizePhone(answer.trim()));

/// True when [answer] is a strict ISO `YYYY-MM-DD` date in
/// `1900-01-01..today` (inclusive, local calendar days).
///
/// [today] defaults to local now; tests pass an explicit date.
bool isValidDateAnswer(String answer, {DateTime? today}) {
  final trimmed = answer.trim();
  final parsed = parseDayString(trimmed);
  if (parsed == null) return false;
  final min = parseDayString(kMinDateDay)!;
  if (parsed.isBefore(min)) return false;
  final now = today ?? DateTime.now();
  final todayMidnight = DateTime(now.year, now.month, now.day);
  if (parsed.isAfter(todayMidnight)) return false;
  return true;
}

/// True for non-empty (after trim) prompt/answer strings.
bool isNonEmptyContent(String s) => s.trim().isNotEmpty;

/// Sentence-ending marks stripped (at most one, trailing) before grading.
const String kFreeTextTrailingPunctuation = '.,!?';

/// Grades a free-text answer (#007): trims whitespace, strips at most one
/// trailing sentence-ending mark (`. , ! ?`), then compares
/// case-insensitively. Umlauts (ä/ö/ü) and ß are never normalized — they
/// must match exactly like any other character (`toLowerCase()` folds case
/// without merging distinct letters).
bool gradeText(String expected, String actual) =>
    _normalizeForGrading(expected) == _normalizeForGrading(actual);

String _normalizeForGrading(String s) {
  var trimmed = s.trim();
  if (trimmed.isNotEmpty &&
      kFreeTextTrailingPunctuation.contains(trimmed[trimmed.length - 1])) {
    trimmed = trimmed.substring(0, trimmed.length - 1).trimRight();
  }
  return trimmed.toLowerCase();
}

/// Validates an item's [promptLang]/[answerLang] pair; returns an error
/// message or `null` if ok.
///
/// `choice`/`freeText` items may omit the pair entirely (non-vocab-flavored
/// prompts) or set both to distinct codes from [kSupportedLanguages] — they
/// must be set/unset together. `phone`/`date` must leave both `null`.
String? validateLanguagePair(
  String type,
  String? promptLang,
  String? answerLang,
) {
  final hasPrompt = promptLang != null && promptLang.isNotEmpty;
  final hasAnswer = answerLang != null && answerLang.isNotEmpty;
  if (type == 'choice' || type == 'freeText') {
    if (!hasPrompt && !hasAnswer) return null;
    if (hasPrompt != hasAnswer) {
      return 'promptLang and answerLang must be set together';
    }
    if (!kSupportedLanguages.contains(promptLang)) {
      return 'unknown language "$promptLang"';
    }
    if (!kSupportedLanguages.contains(answerLang)) {
      return 'unknown language "$answerLang"';
    }
    if (promptLang == answerLang) {
      return 'promptLang and answerLang must differ';
    }
    return null;
  }
  if (hasPrompt || hasAnswer) {
    return 'language pair is not allowed for type "$type"';
  }
  return null;
}

/// Validates item [choices]; returns an error message or `null` if ok.
///
/// `null` (absent) is always fine. Only `choice` items may populate it;
/// `freeText`/`phone`/`date` must leave it `null`.
String? validateChoices(String type, List<dynamic>? choices) {
  if (type != 'choice') {
    if (choices != null) {
      return 'choices is choice-only (type "$type" must omit it)';
    }
    return null;
  }
  if (choices == null) return null;
  for (final c in choices) {
    if (c is! String || c.trim().isEmpty) {
      return 'choices must be non-empty strings';
    }
  }
  return null;
}
