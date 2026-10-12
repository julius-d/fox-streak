// Date exercise — calendar-styled 3-field entry (issue #009).
//
// Implements the ExerciseCardBuilder contract for 'date' type items.
// Reuses the #004 `DateFields` auto-advance + backspace-back focus pattern
// (day/month/year, locale-aware order) wrapped in a bordered calendar-styled
// card, plus the #008 reveal-hint affordance (eye icon, temporary reveal).
//
// No live calendar-validity check at input time — an impossible date like
// 30.02 simply fails to match the stored answer and grades wrong (full
// `isValidDateAnswer` validation stays editor-only, #004).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../library/date_display.dart';
import '../lesson/exercise_card.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import '../../l10n/app_localizations.dart';

/// Builds the date exercise card for date-type items.
///
/// This implements the [ExerciseCardBuilder] signature from the lesson shell.
/// The shell passes the [item] and [onStateChanged] callback.
Widget buildDateExercise({
  required Item item,
  required void Function(ExerciseDraft draft) onStateChanged,
  required AppLocalizations l10n,
  bool autoAnswer = false,
}) {
  return DateExercise(
    item: item,
    onStateChanged: onStateChanged,
    l10n: l10n,
    autoAnswer: autoAnswer,
  );
}

/// Internal stateful widget for the date exercise.
class DateExercise extends ConsumerStatefulWidget {
  final Item item;
  final void Function(ExerciseDraft draft) onStateChanged;
  final AppLocalizations l10n;
  final bool autoAnswer;

  const DateExercise({
    super.key,
    required this.item,
    required this.onStateChanged,
    required this.l10n,
    this.autoAnswer = false,
  });

  @override
  ConsumerState<DateExercise> createState() => _DateExerciseState();
}

class _DateExerciseState extends ConsumerState<DateExercise> {
  late final TextEditingController _day;
  late final TextEditingController _month;
  late final TextEditingController _year;
  late final FocusNode _dayFocus;
  late final FocusNode _monthFocus;
  late final FocusNode _yearFocus;

  bool _revealingHint = false;
  bool _hintWasUsed = false;
  Timer? _hintRevealTimer;

  @override
  void initState() {
    super.initState();
    _day = TextEditingController();
    _month = TextEditingController();
    _year = TextEditingController();
    _dayFocus = FocusNode(debugLabel: 'dateExerciseDay');
    _monthFocus = FocusNode(debugLabel: 'dateExerciseMonth');
    _yearFocus = FocusNode(debugLabel: 'dateExerciseYear');

    if (widget.autoAnswer) {
      // For tests: immediately fill in the correct answer and report it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final parts = widget.item.answer.split('-');
          if (parts.length == 3) {
            _year.text = parts[0];
            _month.text = parts[1];
            _day.text = parts[2];
          }
          _reportDraft();
        }
      });
    }
  }

  @override
  void dispose() {
    _hintRevealTimer?.cancel();
    _day.dispose();
    _month.dispose();
    _year.dispose();
    _dayFocus.dispose();
    _monthFocus.dispose();
    _yearFocus.dispose();
    super.dispose();
  }

  bool get _isGerman => Localizations.localeOf(context).languageCode == 'de';

  FocusNode _nextDateNode(String current) {
    if (_isGerman) {
      return switch (current) {
        'day' => _monthFocus,
        _ => _yearFocus,
      };
    }
    return switch (current) {
      'month' => _dayFocus,
      _ => _yearFocus,
    };
  }

  FocusNode? _prevDateNode(String current) {
    if (_isGerman) {
      return switch (current) {
        'month' => _dayFocus,
        'year' => _monthFocus,
        _ => null,
      };
    }
    return switch (current) {
      'day' => _monthFocus,
      'year' => _dayFocus,
      _ => null,
    };
  }

  void _onDateChanged(String current, String value, int maxLength) {
    if (value.length >= maxLength) {
      if (current == 'year') {
        _yearFocus.unfocus();
      } else {
        _nextDateNode(current).requestFocus();
      }
    }
    _reportDraft();
  }

  KeyEventResult _onDateKey(
    TextEditingController controller,
    FocusNode? prev,
    KeyEvent event,
  ) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        controller.text.isEmpty &&
        prev != null) {
      prev.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _composedIso() {
    final y = _year.text.trim().padLeft(4, '0');
    final m = _month.text.trim().padLeft(2, '0');
    final d = _day.text.trim().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool get _hasAnswer =>
      _day.text.trim().isNotEmpty &&
      _month.text.trim().isNotEmpty &&
      _year.text.trim().isNotEmpty;

  void _onRevealHint() {
    if (_revealingHint) return;

    setState(() {
      _revealingHint = true;
      _hintWasUsed = true;
    });
    _reportDraft();

    // Auto-hide after 2 seconds, matching #008's phone reveal-hint.
    _hintRevealTimer?.cancel();
    _hintRevealTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _revealingHint = false;
        });
      }
    });

    FoxFeedback.success(context, ref);
  }

  void _reportDraft() {
    final locale = Localizations.localeOf(context);
    final composed = _composedIso();
    widget.onStateChanged(
      ExerciseDraft(
        hasAnswer: _hasAnswer,
        grade: () => composed == widget.item.answer,
        correctAnswerLabel: formatDateForDisplay(widget.item.answer, locale),
        hintLabel: null,
        hintUsed: _hintWasUsed,
      ),
    );
  }

  Widget _dateField({
    required String keyName,
    required TextEditingController controller,
    required FocusNode focusNode,
    required FocusNode? prevNode,
    required String fieldName,
    required String label,
    required int maxLength,
  }) {
    return Expanded(
      flex: fieldName == 'year' ? 3 : 2,
      child: Focus(
        onKeyEvent: (_, event) => _onDateKey(controller, prevNode, event),
        child: TextField(
          key: Key(keyName),
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          decoration: InputDecoration(labelText: label),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxLength),
          ],
          onChanged: (v) => _onDateChanged(fieldName, v, maxLength),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final FoxSemanticColors tokens = foxSemantics(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context);

    final dayWidget = _dateField(
      keyName: 'dateExerciseDayField',
      controller: _day,
      focusNode: _dayFocus,
      prevNode: _prevDateNode('day'),
      fieldName: 'day',
      label: l10n.itemDayLabel,
      maxLength: 2,
    );
    final monthWidget = _dateField(
      keyName: 'dateExerciseMonthField',
      controller: _month,
      focusNode: _monthFocus,
      prevNode: _prevDateNode('month'),
      fieldName: 'month',
      label: l10n.itemMonthLabel,
      maxLength: 2,
    );
    final yearWidget = _dateField(
      keyName: 'dateExerciseYearField',
      controller: _year,
      focusNode: _yearFocus,
      prevNode: _prevDateNode('year'),
      fieldName: 'year',
      label: l10n.itemYearLabel,
      maxLength: 4,
    );
    final ordered = _isGerman
        ? [dayWidget, monthWidget, yearWidget]
        : [monthWidget, dayWidget, yearWidget];
    final separator = Text(_isGerman ? '.' : '/');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: FoxSpacing.md),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: exerciseCardMinHeight(context)),
        child: IntrinsicHeight(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.item.prompt,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FoxSpacing.xl),
              Container(
                key: const Key('dateExerciseCard'),
                padding: const EdgeInsets.all(FoxSpacing.lg),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outline),
                  borderRadius: BorderRadius.circular(FoxRadius.lg),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month, color: scheme.primary),
                        const Spacer(),
                        if (_revealingHint)
                          Text(
                            formatDateForDisplay(widget.item.answer, locale),
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: tokens.success,
                            ),
                          )
                        else
                          IconButton(
                            key: const Key('dateExerciseHintButton'),
                            icon: const Icon(Icons.visibility_outlined),
                            tooltip: l10n.exerciseDateRevealHintAria,
                            onPressed: _onRevealHint,
                            color: scheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: FoxSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ordered[0],
                        const SizedBox(width: FoxSpacing.xs),
                        Padding(
                          padding: const EdgeInsets.only(top: FoxSpacing.lg),
                          child: separator,
                        ),
                        const SizedBox(width: FoxSpacing.xs),
                        ordered[1],
                        const SizedBox(width: FoxSpacing.xs),
                        Padding(
                          padding: const EdgeInsets.only(top: FoxSpacing.lg),
                          child: separator,
                        ),
                        const SizedBox(width: FoxSpacing.xs),
                        ordered[2],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
