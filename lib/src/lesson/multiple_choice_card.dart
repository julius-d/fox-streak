// Multiple choice exercise card (issue #006, type renamed by #026).
//
// Implements the ExerciseCard contract from exercise_card.dart.
// Shows prompt word + 4 tappable option cards (1 correct + 3 distractors).
// Distractors: from same set (item.choices), else auto-generated placeholder;
// never duplicate correct answer. Tap selects, CHECK grades by reading the
// selected option's isCorrect flag (assigned once at build time) — never a
// string re-comparison. Accessibility: large text, TalkBack labels.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../theme/fox_streak_theme.dart';
import 'exercise_card.dart';

/// One rendered option: its label and whether it is the correct answer,
/// assigned once when the options are built (#026: replaces the old
/// per-render string comparison).
class _ChoiceOption {
  final String label;
  final bool isCorrect;
  const _ChoiceOption(this.label, {required this.isCorrect});
}

/// Multiple choice exercise card for `choice` items (deEn / enDe).
///
/// Dispatches to this card when item.type == 'choice'.
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
  _ChoiceOption? _selectedOption;
  List<_ChoiceOption> _options = [];
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _buildOptions();
  }

  /// Builds the 4 options (1 correct + 3 distractors) once, each tagged with
  /// its [_ChoiceOption.isCorrect] flag at build time.
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

    // Combine answer + 3 distractors (each tagged isCorrect) and shuffle.
    final built = <_ChoiceOption>[
      _ChoiceOption(answer, isCorrect: true),
      for (final d in selectedDistractors) _ChoiceOption(d, isCorrect: false),
    ]..shuffle(Random());

    setState(() {
      _options = built;
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

  void _onOptionSelected(_ChoiceOption option) {
    if (_answered) return;

    setState(() {
      _selectedOption = option;
      _answered = true;
    });

    // Report draft state; grade() just reads the selected option's flag —
    // no string re-comparison (#026).
    widget.onStateChanged(
      ExerciseDraft(
        hasAnswer: true,
        grade: () => _selectedOption!.isCorrect,
        correctAnswerLabel: widget.item.answer,
        hintLabel: null,
        hintUsed: false,
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
          final showFeedback = _answered;

          Color? backgroundColor;
          Color? borderColor;
          Color? textColor;

          if (showFeedback) {
            if (option.isCorrect) {
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
              label: '${option.label}${isSelected ? ', selected' : ''}',
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
                    option.label,
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
