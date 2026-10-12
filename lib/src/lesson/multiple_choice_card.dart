// Multiple choice vocab exercise card (issue #006).
//
// Implements the ExerciseCard contract from exercise_card.dart.
// Shows prompt word + 4 tappable option cards (1 correct + 3 distractors).
// Distractors: from same set (item.choices), else auto-generated placeholder;
// never duplicate correct answer. Tap selects, CHECK grades; wrong shows
// correct answer. Case/whitespace-insensitive grading, umlauts must match
// exactly (ä ≠ a). Accessibility: large text, TalkBack labels.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../theme/fox_streak_theme.dart';
import 'exercise_card.dart';

/// Multiple choice exercise card for vocab items (deEn / enDe).
///
/// Dispatches to this card when item.type == 'vocab'.
/// Uses item.direction to determine prompt/answer language.
/// Uses item.choices (JSON array of 3 distractors) if provided,
/// otherwise generates placeholder distractors.
class MultipleChoiceCard extends StatefulWidget {
  final Item item;
  final void Function(ExerciseDraft) onStateChanged;
  final AppLocalizations l10n;

  const MultipleChoiceCard({
    super.key,
    required this.item,
    required this.onStateChanged,
    required this.l10n,
  });

  @override
  State<MultipleChoiceCard> createState() => _MultipleChoiceCardState();
}

class _MultipleChoiceCardState extends State<MultipleChoiceCard> {
  String? _selectedOption;
  List<String> _options = [];
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _buildOptions();
  }

  /// Builds the 4 options (1 correct + 3 distractors).
  ///
  /// Distractors come from item.choices (JSON array). If missing or
  /// insufficient, generates placeholder distractors. Ensures no duplicate
  /// of the correct answer and exactly 4 unique options.
  void _buildOptions() {
    final answer = widget.item.answer.trim();
    final distractors = _parseDistractors(widget.item.choices);
    final filteredDistractors = <String>[];

    // Filter out any distractor that matches the answer (case/whitespace-insensitive
    // but umlaut-sensitive) and deduplicate.
    final seen = <String>{answer.toLowerCase()};
    for (final d in distractors) {
      final trimmed = d.trim();
      final lower = trimmed.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        filteredDistractors.add(trimmed);
      }
    }

    // Take up to 3 distractors, pad with placeholders if needed.
    final selectedDistractors = filteredDistractors.take(3).toList();
    while (selectedDistractors.length < 3) {
      selectedDistractors.add(
        _placeholderDistractor(selectedDistractors.length + 1),
      );
    }

    // Combine answer + 3 distractors and shuffle.
    final allOptions = <String>[answer, ...selectedDistractors]
      ..shuffle(Random());

    setState(() {
      _options = allOptions;
    });
  }

  /// Parses distractors from the JSON choices string.
  List<String> _parseDistractors(String? choicesJson) {
    if (choicesJson == null || choicesJson.isEmpty) {
      return <String>[];
    }
    try {
      final decoded = jsonDecode(choicesJson);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  /// Generates a placeholder distractor when not enough real ones.
  String _placeholderDistractor(int index) {
    return 'Option $index';
  }

  /// Normalizes a string for grading: trims whitespace, lowercases.
  /// Umlauts are preserved (ä ≠ a) because toLowerCase() preserves them.
  String _normalize(String s) => s.trim().toLowerCase();

  void _onOptionSelected(String option) {
    if (_answered) return;

    setState(() {
      _selectedOption = option;
      _answered = true;
    });

    // Report draft state with grade function.
    widget.onStateChanged(
      ExerciseDraft(
        hasAnswer: true,
        grade: () =>
            _normalize(_selectedOption!) == _normalize(widget.item.answer),
        correctAnswerLabel: widget.item.answer,
        hintLabel: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Prompt word
        Semantics(
          label: widget.l10n.itemPromptLabel,
          child: Text(
            item.prompt,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: FoxSpacing.xl),
        // 4 option cards
        ..._options.map((option) {
          final isSelected = _answered && _selectedOption == option;
          final isCorrect = _normalize(option) == _normalize(item.answer);
          final showFeedback = _answered;

          Color? backgroundColor;
          Color? borderColor;
          Color? textColor;

          if (showFeedback) {
            if (isCorrect) {
              backgroundColor = theme.colorScheme.primaryContainer;
              borderColor = theme.colorScheme.primary;
              textColor = theme.colorScheme.onPrimaryContainer;
            } else if (isSelected) {
              backgroundColor = theme.colorScheme.errorContainer;
              borderColor = theme.colorScheme.error;
              textColor = theme.colorScheme.onErrorContainer;
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: FoxSpacing.sm),
            child: Semantics(
              button: true,
              selected: isSelected,
              enabled: !_answered,
              label: '$option${isSelected ? ', selected' : ''}',
              child: InkWell(
                onTap: _answered ? null : () => _onOptionSelected(option),
                borderRadius: BorderRadius.circular(FoxRadius.lg),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.all(FoxSpacing.md),
                  decoration: BoxDecoration(
                    color:
                        backgroundColor ??
                        theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(FoxRadius.lg),
                    border: Border.all(
                      color: borderColor ?? theme.colorScheme.outlineVariant,
                      width: showFeedback ? 3 : 1.5,
                    ),
                  ),
                  child: Text(
                    option,
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
