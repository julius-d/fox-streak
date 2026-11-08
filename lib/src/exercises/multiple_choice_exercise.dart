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
import '../data/language_display.dart';
import '../theme/fox_streak_theme.dart';
import '../lesson/exercise_card.dart';
import 'choice_options.dart';

/// Builds the multiple-choice exercise card for `choice`-type items.
///
/// Mirrors the other exercise cards' `buildXxxExercise` factory shape
/// (free text, dial pad, date). [otherSetItems] should be the full set of
/// items in the current lesson (the current item may be included; it is
/// excluded by id internally) — used as the fallback distractor pool.
/// [correctAnswers]/[missedAnswers] steer the fallback distractor order
/// (see [buildChoiceOptions], #120).
/// [revealed] should be true once the shell has graded the answer (CHECK
/// pressed, feedback phase) — see [MultipleChoiceCard].
Widget buildMultipleChoiceExercise({
  Key? key,
  required Item item,
  required List<Item> otherSetItems,
  required void Function(ExerciseDraft draft) onStateChanged,
  required AppLocalizations l10n,
  bool revealed = false,
  Set<String> correctAnswers = const {},
  Set<String> missedAnswers = const {},
}) {
  return MultipleChoiceCard(
    key: key,
    item: item,
    otherSetItems: otherSetItems,
    onStateChanged: onStateChanged,
    l10n: l10n,
    revealed: revealed,
    correctAnswers: correctAnswers,
    missedAnswers: missedAnswers,
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
  final Set<String> correctAnswers;
  final Set<String> missedAnswers;

  const MultipleChoiceCard({
    super.key,
    required this.item,
    this.otherSetItems = const [],
    required this.onStateChanged,
    required this.l10n,
    this.revealed = false,
    this.correctAnswers = const {},
    this.missedAnswers = const {},
  });

  @override
  State<MultipleChoiceCard> createState() => _MultipleChoiceCardState();
}

class _MultipleChoiceCardState extends State<MultipleChoiceCard> {
  late final List<ChoiceOption> _options;
  ChoiceOption? _selected;
  double? _stableViewportHeight;
  double? _stableViewportWidth;

  @override
  void initState() {
    super.initState();
    // Built exactly once per item — never reshuffled on rebuild/rotation
    // (#006 Decisions).
    _options = buildChoiceOptions(
      item: widget.item,
      otherSetItems: widget.otherSetItems,
      correctAnswers: widget.correctAnswers,
      missedAnswers: widget.missedAnswers,
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
    final String? directionLabel = languagePairLabel(
      widget.item.promptLang,
      widget.item.answerLang,
      l10n,
    );
    final photo = hasPhotoImage(widget.item);

    final promptBlock = <Widget>[
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
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: FoxSpacing.lg),
    ];
    final optionBlock = <Widget>[
      for (var i = 0; i < _options.length; i++)
        Padding(
          key: Key('choiceOption$i'),
          // Gaps between options only: no dead space above the first or
          // below the last, which would eat into the 360x800 budget.
          padding: EdgeInsets.only(
            top: i == 0 ? 0 : FoxSpacing.sm,
            bottom: i == _options.length - 1 ? 0 : FoxSpacing.sm,
          ),
          child: _buildOptionCard(context, _options[i], i),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Frozen once the answer is revealed: the feedback banner then eats
        // into the viewport, but the layout (image size, options position)
        // must not move — the overflow scrolls instead (#112).
        // A width change (rotation, window resize) is a new layout, not
        // the banner, so it re-bases the frozen height.
        if (!widget.revealed ||
            _stableViewportHeight == null ||
            _stableViewportWidth != constraints.maxWidth) {
          _stableViewportHeight = constraints.maxHeight;
          _stableViewportWidth = constraints.maxWidth;
        }
        final minHeight = _stableViewportHeight!;
        final wide = photo && constraints.maxWidth > minHeight;

        final Widget content;
        if (wide) {
          // Image beside the question + options.
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: buildItemImage(
                  widget.item,
                  l10n: l10n,
                  expandToFill: true,
                ),
              ),
              const SizedBox(width: FoxSpacing.lg),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [...promptBlock, ...optionBlock],
                ),
              ),
            ],
          );
        } else {
          // Top-anchored with a growing image when there is a photo;
          // otherwise (no image / emoji) centered while it fits.
          content = Column(
            mainAxisAlignment: photo
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (photo)
                Expanded(
                  child: buildItemImage(
                    widget.item,
                    l10n: l10n,
                    expandToFill: true,
                  ),
                )
              else
                buildItemImage(widget.item, l10n: l10n),
              ...promptBlock,
              ...optionBlock,
            ],
          );
        }

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: IntrinsicHeight(child: content),
          ),
        );
      },
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

    final borderWidth = (showFeedback || isSelected) ? 3.0 : 1.5;

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
          // Border + padding always add up to the same size, so selecting
          // or revealing never shifts the options block (#112).
          padding: EdgeInsets.all(FoxSpacing.md + (3 - borderWidth)),
          decoration: BoxDecoration(
            color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(FoxRadius.lg),
            border: Border.all(
              color: borderColor ?? theme.colorScheme.outlineVariant,
              width: borderWidth,
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
