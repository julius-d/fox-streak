// Distractor-selection logic for the multiple-choice exercise (issue #006).
//
// Pure function, no widget/BuildContext dependency, so the fallback chain
// can be unit-tested directly (see test/exercises/choice_options_test.dart).

import 'dart:convert';
import 'dart:math';

import '../data/database.dart';

/// One rendered option: its label and whether it is the correct answer,
/// assigned once when the options are built (never re-derived via string
/// comparison at grade time).
class ChoiceOption {
  final String label;
  final bool isCorrect;

  const ChoiceOption(this.label, {required this.isCorrect});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChoiceOption &&
          other.label == label &&
          other.isCorrect == isCorrect);

  @override
  int get hashCode => Object.hash(label, isCorrect);

  @override
  String toString() => 'ChoiceOption($label, isCorrect: $isCorrect)';
}

/// Builds the 4 options (1 correct + 3 distractors) for a `choice` item,
/// shuffled once. Callers must build this exactly once per item (e.g. in
/// `initState`) and never rebuild it on rebuild/rotation.
///
/// Distractor fallback, in priority order (never fewer than 3 distractors,
/// the correct answer is always excluded, duplicates of it are dropped):
/// 1. [item.choices] (blank-tolerant JSON array from the #004 editor).
/// 2. Other items in [otherSetItems] that share [item.direction] (expected
///    to be the rest of the current lesson's set — the current item is
///    excluded by id), picked in random order.
/// 3. [placeholderDistractor] for any still-empty slot, called with a
///    1-based index.
List<ChoiceOption> buildChoiceOptions({
  required Item item,
  required List<Item> otherSetItems,
  required String Function(int index) placeholderDistractor,
  Random? random,
}) {
  final rng = random ?? Random();
  final answer = item.answer.trim();
  final seen = <String>{answer.toLowerCase()};
  final distractors = <String>[];

  void addIfNew(String candidate) {
    final trimmed = candidate.trim();
    if (trimmed.isEmpty) return;
    final lower = trimmed.toLowerCase();
    if (seen.contains(lower)) return;
    seen.add(lower);
    distractors.add(trimmed);
  }

  for (final stored in _parseChoices(item.choices)) {
    if (distractors.length >= 3) break;
    addIfNew(stored);
  }

  if (distractors.length < 3 && item.direction != null) {
    final pool =
        otherSetItems
            .where(
              (other) =>
                  other.id != item.id && other.direction == item.direction,
            )
            .map((other) => other.answer)
            .toList()
          ..shuffle(rng);
    for (final candidate in pool) {
      if (distractors.length >= 3) break;
      addIfNew(candidate);
    }
  }

  // Defensive cap: placeholderDistractor is caller-supplied and expected to
  // produce a fresh string per index, but a misbehaving caller (e.g. always
  // returning the same colliding text) must not hang this loop forever.
  var placeholderIndex = 1;
  var attempts = 0;
  while (distractors.length < 3 && attempts < 1000) {
    addIfNew(placeholderDistractor(placeholderIndex));
    placeholderIndex++;
    attempts++;
  }

  final built = <ChoiceOption>[
    ChoiceOption(answer, isCorrect: true),
    for (final d in distractors) ChoiceOption(d, isCorrect: false),
  ]..shuffle(rng);

  return built;
}

List<String> _parseChoices(String? choicesJson) {
  if (choicesJson == null || choicesJson.isEmpty) return const [];
  try {
    final decoded = jsonDecode(choicesJson);
    if (decoded is List) {
      return decoded.map((e) => e.toString()).toList();
    }
    return const [];
  } catch (_) {
    return const [];
  }
}
