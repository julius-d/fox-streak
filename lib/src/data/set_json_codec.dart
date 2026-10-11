// JSON share format v1 for question sets (issue #002).
//
// File extension `.foxstreak.json`, e.g.:
// ```json
// { "format": "foxstreak-set", "version": 1, "title": "...",
//   "description": "...", "createdBy": "Mama", "items": [
//     { "type": "vocab", "prompt": "Hund", "answer": "dog",
//       "direction": "deEn", "choices": ["cat","mouse"], "hint": "" },
//     { "type": "phone", "prompt": "Mama", "answer": "01711234567" },
//     { "type": "date", "prompt": "Mamas Geburtstag",
//       "answer": "1985-05-14" } ] }
// ```
//
// The codec is pure Dart (no Drift) so UI share/picker code in #003 and the
// repository import/export paths share validation. Import never overwrites:
// callers always create a new set with fresh ids.

import 'dart:convert';

import 'validation.dart';

/// Thrown by [decodeSetFromJson] when the payload is not a valid v1 set.
class SetImportException implements Exception {
  final String message;
  const SetImportException(this.message);

  @override
  String toString() => 'SetImportException: $message';
}

/// A single validated share item.
class ShareItem {
  final String type;
  final String prompt;
  final String answer;
  final String? direction;
  final List<String>? choices;
  final String hint;

  const ShareItem({
    required this.type,
    required this.prompt,
    required this.answer,
    this.direction,
    this.choices,
    this.hint = '',
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type,
      'prompt': prompt,
      'answer': answer,
    };
    if (direction != null) map['direction'] = direction;
    if (choices != null) map['choices'] = choices;
    if (hint.isNotEmpty) map['hint'] = hint;
    return map;
  }
}

/// A validated share set (no DB ids).
class ShareSet {
  final String title;
  final String description;
  final String createdBy;
  final List<ShareItem> items;

  const ShareSet({
    required this.title,
    required this.description,
    required this.createdBy,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'format': kShareFormat,
    'version': kShareVersion,
    'title': title,
    'description': description,
    'createdBy': createdBy,
    'items': [for (final i in items) i.toJson()],
  };

  String encode() => jsonEncode(toJson());
}

/// Encodes a set into the v1 share map (validates before encoding).
///
/// Throws [SetImportException] when any field is invalid so export of a
/// corrupt DB row fails loudly instead of producing an unreadable file.
Map<String, dynamic> encodeSetToJson({
  required String title,
  String description = '',
  required String createdBy,
  required List<ShareItem> items,
  DateTime? today,
}) {
  final set = ShareSet(
    title: title,
    description: description,
    createdBy: createdBy,
    items: items,
  );
  validateShareSet(set, today: today);
  return set.toJson();
}

/// Decodes + validates a v1 share map (e.g. from `jsonDecode`).
///
/// Throws [SetImportException] on bad schema / unknown version / failed
/// item validation. Accepts `Map<dynamic, dynamic>` from `jsonDecode` by
/// copying keys to strings when possible.
ShareSet decodeSetFromJson(Map<dynamic, dynamic> json, {DateTime? today}) {
  Map<String, dynamic> map;
  try {
    map = {for (final e in json.entries) e.key.toString(): e.value};
  } on StateError catch (e) {
    throw SetImportException('invalid JSON object: $e');
  }

  final format = map['format'];
  if (format != kShareFormat) {
    throw SetImportException(
      'unknown format "$format" (expected "$kShareFormat")',
    );
  }
  final version = map['version'];
  if (version != kShareVersion) {
    throw SetImportException(
      'unsupported version "$version" (expected $kShareVersion)',
    );
  }

  final title = map['title'];
  final createdBy = map['createdBy'];
  final rawItems = map['items'];
  if (title is! String || title.trim().isEmpty) {
    throw const SetImportException('title must be a non-empty string');
  }
  if (createdBy is! String || validateCreatorName(createdBy) != null) {
    throw const SetImportException(
      'createdBy must be a non-empty name (max $kMaxCreatorNameLength chars)',
    );
  }
  if (rawItems is! List) {
    throw const SetImportException('items must be a list');
  }

  final description = map['description'];
  if (description != null && description is! String) {
    throw const SetImportException('description must be a string');
  }

  final items = <ShareItem>[];
  for (var i = 0; i < rawItems.length; i++) {
    final raw = rawItems[i];
    if (raw is! Map) {
      throw SetImportException('items[$i] must be an object');
    }
    items.add(_decodeItem(i, raw, today: today));
  }

  final set = ShareSet(
    title: title.trim(),
    description: (description as String?) ?? '',
    createdBy: createdBy.trim(),
    items: items,
  );
  validateShareSet(set, today: today);
  return set;
}

ShareItem _decodeItem(int index, Map<dynamic, dynamic> raw, {DateTime? today}) {
  Map<String, dynamic> m;
  try {
    m = {for (final e in raw.entries) e.key.toString(): e.value};
  } on StateError catch (e) {
    throw SetImportException('items[$index]: invalid object: $e');
  }
  final prefix = 'items[$index]';

  final type = m['type'];
  if (type is! String || !kItemTypes.contains(type)) {
    throw SetImportException(
      '$prefix: unknown type "$type" (expected ${kItemTypes.join("|")})',
    );
  }
  final prompt = m['prompt'];
  final answer = m['answer'];
  if (prompt is! String || prompt.trim().isEmpty) {
    throw SetImportException('$prefix: prompt must be non-empty');
  }
  if (answer is! String || answer.trim().isEmpty) {
    throw SetImportException('$prefix: answer must be non-empty');
  }

  final direction = m['direction'];
  if (direction != null && direction is! String) {
    throw SetImportException('$prefix: direction must be a string');
  }
  final directionError = validateDirection(type, direction as String?);
  if (directionError != null) {
    throw SetImportException('$prefix: $directionError');
  }

  List<String>? choices;
  if (m.containsKey('choices') && m['choices'] != null) {
    final rawChoices = m['choices'];
    if (rawChoices is! List) {
      throw SetImportException('$prefix: choices must be a list of strings');
    }
    final choicesError = validateChoices(type, rawChoices);
    if (choicesError != null) {
      throw SetImportException('$prefix: $choicesError');
    }
    choices = [for (final c in rawChoices) (c as String).trim()];
  } else {
    final choicesError = validateChoices(type, null);
    if (choicesError != null) {
      throw SetImportException('$prefix: $choicesError');
    }
  }

  final hint = m['hint'];
  if (hint != null && hint is! String) {
    throw SetImportException('$prefix: hint must be a string');
  }

  // Type-specific answer validation.
  if (type == 'phone' && !isValidPhoneAnswer(answer)) {
    throw SetImportException(
      '$prefix: phone answer must be 3-15 digits after normalisation',
    );
  }
  if (type == 'date' && !isValidDateAnswer(answer, today: today)) {
    throw SetImportException(
      '$prefix: date answer must be ISO YYYY-MM-DD in $kMinDateDay..today',
    );
  }

  return ShareItem(
    type: type,
    prompt: prompt.trim(),
    // Phones are stored normalised (digits-only, German style keeps
    // leading 0, e.g. 0171...). Other types keep the trimmed literal.
    answer: type == 'phone' ? normalizePhone(answer.trim()) : answer.trim(),
    direction: direction,
    choices: choices,
    hint: (hint as String?) ?? '',
  );
}

/// Validates an already-built [ShareSet]; throws [SetImportException].
void validateShareSet(ShareSet set, {DateTime? today}) {
  if (set.title.trim().isEmpty) {
    throw const SetImportException('title must be non-empty');
  }
  final creatorError = validateCreatorName(set.createdBy);
  if (creatorError != null) {
    throw SetImportException(creatorError);
  }
  for (var i = 0; i < set.items.length; i++) {
    final item = set.items[i];
    final prefix = 'items[$i]';
    if (!kItemTypes.contains(item.type)) {
      throw SetImportException('$prefix: unknown type "${item.type}"');
    }
    if (!isNonEmptyContent(item.prompt)) {
      throw SetImportException('$prefix: prompt must be non-empty');
    }
    if (!isNonEmptyContent(item.answer)) {
      throw SetImportException('$prefix: answer must be non-empty');
    }
    final directionError = validateDirection(item.type, item.direction);
    if (directionError != null) {
      throw SetImportException('$prefix: $directionError');
    }
    final choicesError = validateChoices(item.type, item.choices);
    if (choicesError != null) {
      throw SetImportException('$prefix: $choicesError');
    }
    if (item.type == 'phone' && !isValidPhoneAnswer(item.answer)) {
      throw SetImportException('$prefix: invalid phone answer');
    }
    if (item.type == 'date' && !isValidDateAnswer(item.answer, today: today)) {
      throw SetImportException('$prefix: invalid date answer');
    }
  }
}
