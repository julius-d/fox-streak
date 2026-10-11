// Test-only placeholder exercise card implementing the ExerciseCard contract.
//
// Used for shell tests as a stand-in until #006–#009 provide real cards.
// This is intentionally minimal — real cards will have proper UIs.

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

/// Placeholder exercise card implementing the ExerciseCard contract.
///
/// Used for shell tests and as a stand-in until #006–#009 provide real cards.
/// This is intentionally minimal — real cards will have proper UIs.
class PlaceholderExerciseCard extends StatefulWidget {
  final Item item;
  final void Function(ExerciseDraft) onStateChanged;
  final AppLocalizations l10n;
  final bool autoAnswer; // For tests: immediately report a correct answer

  const PlaceholderExerciseCard({
    super.key,
    required this.item,
    required this.onStateChanged,
    required this.l10n,
    this.autoAnswer = false,
  });

  @override
  State<PlaceholderExerciseCard> createState() => _PlaceholderExerciseCardState();
}

class _PlaceholderExerciseCardState extends State<PlaceholderExerciseCard> {
  String? _answer;
  bool _answered = false;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // For tests: report draft state synchronously during first build if autoAnswer.
    // This triggers a Riverpod debug warning but works correctly.
    // In production, autoAnswer is always false so this branch is never taken.
    if (widget.autoAnswer && !_reported) {
      _reported = true;
      _answer = widget.item.answer;
      _answered = true;
      // Defer the provider update to after build using a microtask.
      Future.microtask(() {
        if (mounted) {
          widget.onStateChanged(
            ExerciseDraft(
              hasAnswer: true,
              grade: () => _answer == widget.item.answer,
              correctAnswerLabel: widget.item.answer,
              hintLabel: null,
            ),
          );
        }
      });
    }

    final item = widget.item;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Prompt
        Text(
          item.prompt,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FoxSpacing.xl),
        // Answer input (simplified per type)
        if (item.type == 'vocab' &&
            item.choices != null &&
            item.choices!.isNotEmpty)
          _buildChoices(item)
        else if (item.type == 'phone')
          _buildPhoneInput()
        else if (item.type == 'date')
          _buildDateInput()
        else
          _buildTextInput(),
      ],
    );
  }

  Widget _buildChoices(Item item) {
    final choices = _parseChoices(item.choices!);
    final allOptions = [...choices, item.answer]..shuffle();
    return Column(
      children: allOptions.map((option) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: FoxSpacing.sm),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: Key('choice-$option'),
              onPressed: _answered
                  ? null
                  : () {
                      setState(() {
                        _answer = option;
                        _answered = true;
                        widget.onStateChanged(
                          ExerciseDraft(
                            hasAnswer: true,
                            grade: () => _answer == item.answer,
                            correctAnswerLabel: item.answer,
                            hintLabel: null,
                          ),
                        );
                      });
                    },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(FoxSpacing.md),
                backgroundColor: _answered
                    ? (_answer == item.answer
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.errorContainer)
                    : null,
              ),
              child: Text(option, textAlign: TextAlign.center),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhoneInput() {
    return TextField(
      key: const Key('phoneInput'),
      decoration: InputDecoration(
        labelText: widget.l10n.itemPromptLabel,
        hintText: widget.l10n.itemDateHint,
      ),
      keyboardType: TextInputType.phone,
      onChanged: (value) {
        setState(() {
          _answer = value;
          if (value.isNotEmpty && !_answered) {
            _answered = true;
            widget.onStateChanged(
              ExerciseDraft(
                hasAnswer: true,
                grade: () => _answer == widget.item.answer,
                correctAnswerLabel: widget.item.answer,
                hintLabel: null,
              ),
            );
          }
        });
      },
    );
  }

  Widget _buildDateInput() {
    return TextField(
      key: const Key('dateInput'),
      decoration: InputDecoration(
        labelText: widget.l10n.itemPromptLabel,
        hintText: widget.l10n.itemDateHint,
      ),
      keyboardType: TextInputType.datetime,
      onChanged: (value) {
        setState(() {
          _answer = value;
          if (value.isNotEmpty && !_answered) {
            _answered = true;
            widget.onStateChanged(
              ExerciseDraft(
                hasAnswer: true,
                grade: () => _answer == widget.item.answer,
                correctAnswerLabel: widget.item.answer,
                hintLabel: null,
              ),
            );
          }
        });
      },
    );
  }

  Widget _buildTextInput() {
    return TextField(
      key: const Key('textInput'),
      decoration: InputDecoration(labelText: widget.l10n.itemPromptLabel),
      onChanged: (value) {
        setState(() {
          _answer = value;
          if (value.isNotEmpty && !_answered) {
            _answered = true;
            widget.onStateChanged(
              ExerciseDraft(
                hasAnswer: true,
                grade: () => _answer == widget.item.answer,
                correctAnswerLabel: widget.item.answer,
                hintLabel: null,
              ),
            );
          }
        });
      },
    );
  }

  List<String> _parseChoices(String choicesJson) {
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
}