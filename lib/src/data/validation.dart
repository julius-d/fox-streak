// Pure validation helpers for set items (issue #002).
//
// Kept free of Drift/Riverpod imports so the JSON codec, repositories and
// (later) exercise widgets in #008/#009 can share one implementation.
// All functions are pure and clock-independent except [isValidDateAnswer],
// which takes an explicit `today` for testability.

import 'dart:convert';

import 'clock.dart';

/// Allowed `items.type` values.
///
/// `vocab` (#002) was split by #026 into `choice` (#006 multiple-choice) and
/// `freeText` (#007 type-the-answer); existing `vocab` rows are migrated to
/// `choice` by `database.dart`'s schema v2 upgrade.
const Set<String> kItemTypes = {'choice', 'freeText', 'phone', 'date'};

/// Allowed `question_sets.category` values (#045). Drives the choice/
/// freeText icon/color (`item_type_icons.dart`); `general` is a catch-all
/// for future non-vocab/math/geography knowledge sets.
const Set<String> kSetCategories = {'vocab', 'general', 'math', 'geography'};

/// Default category for sets stored with `category == null` (pre-#045 rows,
/// or a share file predating the field).
const String kDefaultSetCategory = 'vocab';

/// Resolves a stored/share `category` to a concrete value in
/// [kSetCategories]: `null` resolves to [kDefaultSetCategory].
String effectiveSetCategory(String? category) =>
    category ?? kDefaultSetCategory;

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

/// Allowed `items.imageType` values (#014). Closed enum — a reserved
/// `lottie` value is deliberately *not* included; #032 adds its own value +
/// migration if/when animated images land.
const Set<String> kImageTypes = {'emoji', 'base64', 'url'};

/// True when [type] is one of [kImageTypes].
bool isValidImageType(String type) => kImageTypes.contains(type);

/// Normalizes [content] for storage/validation, given its image [type].
///
/// `base64` strips **all** whitespace, not just leading/trailing: the
/// common `base64 <file>` CLI command (GNU coreutils) wraps output at ~76
/// characters, and copy-pasted base64 data is routinely multi-line, so the
/// item editor's content field accepts that as input, not malformed data.
/// `emoji`/`url` have no internal-whitespace meaning, so a plain trim is
/// enough. Unknown types pass through trimmed.
String normalizeImageContent(String type, String content) {
  if (type == 'base64') return content.replaceAll(RegExp(r'\s'), '');
  return content.trim();
}

/// True when [content] is valid for the given image [type].
///
/// `emoji`: any non-empty (after trim) string — no strict single-grapheme
/// requirement, short symbol combos are fine. `base64`: decodable by
/// [base64Decode] once [normalizeImageContent] strips embedded whitespace.
/// `url`: a parseable [Uri] with an http/https scheme. Unknown [type]s are
/// always invalid.
bool isValidImageContent(String type, String content) {
  switch (type) {
    case 'emoji':
      return content.trim().isNotEmpty;
    case 'base64':
      final normalized = normalizeImageContent('base64', content);
      // `base64Decode('')` decodes to an empty byte list without throwing —
      // reject it explicitly so "empty" isn't accepted as valid image data.
      if (normalized.isEmpty) return false;
      try {
        base64Decode(normalized);
        return true;
      } on FormatException {
        return false;
      }
    case 'url':
      final uri = Uri.tryParse(normalizeImageContent('url', content));
      return uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    default:
      return false;
  }
}

/// Validates an item's [imageType]/[imageContent] pair; returns an error
/// message or `null` if ok.
///
/// Both-or-neither: either both are `null`/empty (no image) or both are
/// set to a valid, type-specific pairing.
String? validateImagePair(String? imageType, String? imageContent) {
  final hasType = imageType != null && imageType.isNotEmpty;
  final hasContent = imageContent != null && imageContent.isNotEmpty;
  if (!hasType && !hasContent) return null;
  if (hasType != hasContent) {
    return 'imageType and imageContent must be set together';
  }
  final type = imageType!;
  final content = imageContent!;
  if (!isValidImageType(type)) {
    return 'unknown imageType "$type" (expected ${kImageTypes.join("|")})';
  }
  if (!isValidImageContent(type, content)) {
    return 'invalid imageContent for imageType "$type"';
  }
  return null;
}

/// Maximum length (after trimming) of an item's optional image
/// copyright/credit line (#094).
const int kMaxImageCopyrightLength = 120;

/// True when [value] is a valid, non-empty image copyright/credit line:
/// single-line (no `\n`, checked before trimming so an embedded newline is
/// always rejected) and at most [kMaxImageCopyrightLength] characters after
/// trimming. Does not treat an empty-after-trim value as valid — callers
/// that want "blank clears the copyright" must check that separately (see
/// the item editor).
bool isValidImageCopyright(String value) {
  final trimmed = value.trim();
  return trimmed.isNotEmpty &&
      !value.contains('\n') &&
      trimmed.length <= kMaxImageCopyrightLength;
}

/// Validates an item's [imageType]/[imageCopyright] pairing (#094); returns
/// an error message or `null`.
///
/// One-sided (unlike [validateImagePair]'s both-or-neither): `null`/empty
/// [imageCopyright] is always valid (the copyright itself is optional), but
/// a non-null, non-empty one requires [imageType] to be `base64` or `url` —
/// a system `emoji` glyph has no meaningful copyright — and must satisfy
/// [isValidImageCopyright].
String? validateImageCopyright(String? imageType, String? imageCopyright) {
  if (imageCopyright == null || imageCopyright.isEmpty) return null;
  if (imageType != 'base64' && imageType != 'url') {
    return 'imageCopyright is only allowed when imageType is "base64" or '
        '"url"';
  }
  if (!isValidImageCopyright(imageCopyright)) {
    return 'invalid imageCopyright (must be a single line, non-empty, at '
        'most $kMaxImageCopyrightLength characters)';
  }
  return null;
}
