// Multiple-choice vocab exercise (issue #006; type renamed from `vocab` to
// `choice` and dispatch wired by #026).
//
// Learner picks 1 of 4 tappable options (1 correct + up to 3 distractors,
// built once per item via buildChoiceOptions — see choice_options.dart).
// Grading reads the selected option's isCorrect flag, never a string
// re-comparison. No reveal-hint: the correct answer is already visible
// among the options, so hintUsed is always false.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../theme/fox_streak_theme.dart';
import '../lesson/exercise_card.dart';
import 'choice_options.dart';

/// Builds the multiple-choice exercise card for `choice`-type items.
///
/// Mirrors the other exercise cards' `buildXxxExercise` factory shape
/// (free text, dial pad, date). [otherSetItems] should be the full set of
/// items in the current lesson (the current item may be included; it is
/// excluded by id internally) — used as the fallback distractor pool.
/// [revealed] should be true once the shell has graded the answer (CHECK
/// pressed, feedback phase) — see [MultipleChoiceCard].
Widget buildMultipleChoiceExercise({
  Key? key,
  required Item item,
  required List<Item> otherSetItems,
  required void Function(ExerciseDraft draft) onStateChanged,
  required AppLocalizations l10n,
  bool revealed = false,
}) {
  return MultipleChoiceCard(
    key: key,
    item: item,
    otherSetItems: otherSetItems,
    onStateChanged: onStateChanged,
    l10n: l10n,
    revealed: revealed,
  );
}

/// Internal stateful widget for the multiple-choice exercise.
///
/// Tap selects/reselects freely before CHECK — [_selected] only tracks the
/// current pick, it does not lock input. [revealed] (driven by the shell's
/// feedback phase, true once CHECK has graded the answer) is what locks
/// taps and reveals the correct/wrong coloring; before that, tapping a
/// different option simply changes the selection (#006 Decisions: "Tap
/// selects/reselects pre-check").
class MultipleChoiceCard extends StatefulWidget {
  final Item item;
  final List<Item> otherSetItems;
  final void Function(ExerciseDraft) onStateChanged;
  final AppLocalizations l10n;
  final bool revealed;

  const MultipleChoiceCard({
    super.key,
    required this.item,
    this.otherSetItems = const [],
    required this.onStateChanged,
    required this.l10n,
    this.revealed = false,
  });

  @override
  State<MultipleChoiceCard> createState() => _MultipleChoiceCardState();
}

class _MultipleChoiceCardState extends State<MultipleChoiceCard> {
  late final List<ChoiceOption> _options;
  ChoiceOption? _selected;

  @override
  void initState() {
    super.initState();
    // Built exactly once per item — never reshuffled on rebuild/rotation
    // (#006 Decisions).
    _options = buildChoiceOptions(
      item: widget.item,
      otherSetItems: widget.otherSetItems,
      placeholderDistractor: (index) =>
          widget.l10n.exerciseChoicePlaceholderOption(index),
    );
  }

  void _onOptionSelected(ChoiceOption option) {
    if (widget.revealed) return;

    setState(() {
      _selected = option;
    });

    widget.onStateChanged(
      ExerciseDraft(
        hasAnswer: true,
        grade: () => _selected!.isCorrect,
        correctAnswerLabel: widget.item.answer,
        hintLabel: null,
        hintUsed: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final l10n = widget.l10n;
    final String? directionLabel = switch (widget.item.direction) {
      'deEn' => l10n.directionDeEn,
      'enDe' => l10n.directionEnDe,
      _ => null,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: FoxSpacing.md),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: exerciseCardMinHeight(context)),
        child: IntrinsicHeight(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (directionLabel != null) ...[
                Text(
                  directionLabel,
                  style: textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: FoxSpacing.sm),
              ],
              Semantics(
                label: l10n.itemPromptLabel,
                child: Text(
                  widget.item.prompt,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: FoxSpacing.xl),
              for (var i = 0; i < _options.length; i++)
                Padding(
                  key: Key('choiceOption$i'),
                  padding: const EdgeInsets.symmetric(vertical: FoxSpacing.sm),
                  child: _buildOptionCard(context, _options[i], i),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context,
    ChoiceOption option,
    int index,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isSelected = _selected == option;
    final showFeedback = widget.revealed;

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
    } else if (isSelected) {
      // Picked but not yet graded: outline only, no fill — reveal colors
      // (above) are reserved for after CHECK.
      borderColor = theme.colorScheme.primary;
    }

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: !widget.revealed,
      label: widget.l10n.exerciseChoiceOptionSemanticLabel(
        option.label,
        index + 1,
        _options.length,
      ),
      child: InkWell(
        onTap: widget.revealed ? null : () => _onOptionSelected(option),
        borderRadius: BorderRadius.circular(FoxRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: FoxButtonMetrics.minSize,
          ),
          padding: const EdgeInsets.all(FoxSpacing.md),
          decoration: BoxDecoration(
            color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(FoxRadius.lg),
            border: Border.all(
              color: borderColor ?? theme.colorScheme.outlineVariant,
              width: (showFeedback || isSelected) ? 3 : 1.5,
            ),
          ),
          alignment: Alignment.center,
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
    );
  }
}
