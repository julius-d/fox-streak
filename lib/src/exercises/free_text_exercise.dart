// Free-text vocab exercise (issue #007).
//
// Learner types the full answer into a text field, graded tolerantly via
// `gradeText` (validation.dart): trim, case-insensitive, strip at most one
// trailing `. , ! ?`; umlauts and ß must match exactly.
//
// Not wired into the lesson shell's `item.type` dispatch — that requires the
// #002 `vocab` -> `choice`/`freeText` schema migration, which is explicitly
// out of scope for #007 (see issue). This widget implements the #005
// `ExerciseCard` contract standalone so it can be plugged in once that
// migration lands.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/validation.dart';
import '../lesson/exercise_card.dart';
import '../theme/fox_streak_theme.dart';

/// Builds the free-text exercise card.
///
/// Mirrors the [ExerciseCardBuilder] signature from the lesson shell
/// contract (`item` + `onStateChanged`), plus `l10n` like the other cards.
Widget buildFreeTextExercise({
  required Item item,
  required void Function(ExerciseDraft draft) onStateChanged,
  required AppLocalizations l10n,
}) {
  return FreeTextExercise(
    item: item,
    onStateChanged: onStateChanged,
    l10n: l10n,
  );
}

/// Internal stateful widget for the free-text exercise.
class FreeTextExercise extends StatefulWidget {
  final Item item;
  final void Function(ExerciseDraft draft) onStateChanged;
  final AppLocalizations l10n;

  const FreeTextExercise({
    super.key,
    required this.item,
    required this.onStateChanged,
    required this.l10n,
  });

  @override
  State<FreeTextExercise> createState() => _FreeTextExerciseState();
}

class _FreeTextExerciseState extends State<FreeTextExercise> {
  final TextEditingController _controller = TextEditingController();
  bool _hintUsed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_reportDraft);
    // Report the initial (empty) draft so the shell knows CHECK is disabled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportDraft();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_reportDraft);
    _controller.dispose();
    super.dispose();
  }

  void _onRevealHint() {
    if (_hintUsed) return;
    setState(() => _hintUsed = true);
    _reportDraft();
  }

  String? _firstLetterHint() {
    final answer = widget.item.answer.trim();
    if (answer.isEmpty) return null;
    // `runes.first` (a Unicode code point), not `answer[0]` (a UTF-16 code
    // unit) — the latter splits surrogate pairs for astral-plane characters.
    final firstChar = String.fromCharCode(answer.runes.first);
    return widget.l10n.exerciseFreeTextHintLabel(firstChar);
  }

  void _reportDraft() {
    final typed = _controller.text;
    widget.onStateChanged(
      ExerciseDraft(
        hasAnswer: typed.trim().isNotEmpty,
        grade: () => gradeText(widget.item.answer, typed),
        correctAnswerLabel: widget.item.answer,
        hintLabel: _hintUsed ? _firstLetterHint() : null,
        hintUsed: _hintUsed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String? directionLabel = switch (widget.item.direction) {
      'deEn' => widget.l10n.directionDeEn,
      'enDe' => widget.l10n.directionEnDe,
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
                  style: text.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: FoxSpacing.sm),
              ],
              Text(
                widget.item.prompt,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FoxSpacing.xl),
              TextField(
                key: const Key('freeTextAnswerField'),
                controller: _controller,
                autocorrect: false,
                enableSuggestions: false,
                textAlign: TextAlign.center,
                style: text.titleLarge,
                decoration: InputDecoration(
                  hintText: widget.l10n.exerciseFreeTextPlaceholder,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FoxRadius.md),
                  ),
                ),
              ),
              const SizedBox(height: FoxSpacing.lg),
              IconButton(
                key: const Key('freeTextRevealHintButton'),
                icon: const Icon(Icons.visibility_outlined),
                tooltip: widget.l10n.exerciseFreeTextRevealHintAria,
                onPressed: _hintUsed ? null : _onRevealHint,
                color: scheme.primary,
              ),
              if (_hintUsed)
                Padding(
                  padding: const EdgeInsets.only(top: FoxSpacing.sm),
                  child: Text(
                    _firstLetterHint() ?? '',
                    key: const Key('freeTextHintLabel'),
                    style: text.bodyMedium?.copyWith(color: scheme.primary),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
