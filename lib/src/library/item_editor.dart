// Per-type item add/edit form (issue #004).
//
// Replaces the #003 minimal shell with tailored subforms switching on the
// picked type (vocab DE<->EN, phone numbers, birth dates). Validation mirrors
// #002 `validation.dart` exactly; storage formats never change (phone
// digits-only, date ISO `YYYY-MM-DD`).
//
// - Vocab: prompt + answer (trim-then-require), required direction toggle
//   (`SegmentedButton`, nullable initial for new items), 3 optional
//   distractor fields (blank allowed; non-blank validated by
//   `validateChoices` plus an editor-only duplicate-vs-answer check).
// - Phone: name label + digit-only field with live display-only grouping
//   (see `phone_formatting.dart`); the repository normalises on save.
// - Date: calendar-styled card with 3 numeric fields (see
//   `date_display.dart` for locale-aware display), auto-advance on fill,
//   backspace-on-empty goes back, locale-aware order (DE day-month-year,
//   EN month-day-year). `today` comes from `systemClockProvider`.
// - `hint` is never touched (left `Value.absent` / `''` default) so existing
//   hints are preserved.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/providers.dart';
import '../data/validation.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'date_display.dart';
import 'phone_formatting.dart';

/// Dialog form that creates or edits a single [Item].
///
/// When [existing] is null, [setId] is required and a new item is added with
/// the type picked in the form (sets are untyped containers).
class ItemEditorDialog extends ConsumerStatefulWidget {
  final int setId;
  final Item? existing;

  const ItemEditorDialog({super.key, required this.setId, this.existing});

  @override
  ConsumerState<ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends ConsumerState<ItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  late final TextEditingController _prompt;
  late final TextEditingController _vocabAnswer;
  late final TextEditingController _phone;
  late final TextEditingController _day;
  late final TextEditingController _month;
  late final TextEditingController _year;
  late final List<TextEditingController> _choices;
  late final FocusNode _dayFocus;
  late final FocusNode _monthFocus;
  late final FocusNode _yearFocus;
  String? _direction;
  bool _saving = false;
  String? _saveError;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? 'vocab';
    _prompt = TextEditingController(text: existing?.prompt ?? '');
    _vocabAnswer = TextEditingController(
      text: _type == 'vocab' ? existing?.answer ?? '' : '',
    );
    _phone = TextEditingController(
      text: _type == 'phone' && existing != null
          ? groupPhoneForDisplay(normalizePhone(existing.answer.trim()))
          : '',
    );
    _day = TextEditingController();
    _month = TextEditingController();
    _year = TextEditingController();
    if (_type == 'date' && existing != null) {
      final parts = existing.answer.split('-');
      if (parts.length == 3) {
        _year.text = parts[0];
        _month.text = parts[1];
        _day.text = parts[2];
      }
    }
    _choices = List.generate(3, (_) => TextEditingController());
    if (_type == 'vocab' && existing?.choices != null) {
      try {
        final decoded = (jsonDecode(existing!.choices!) as List).cast<String>();
        for (var i = 0; i < decoded.length && i < 3; i++) {
          _choices[i].text = decoded[i];
        }
      } catch (_) {
        // Corrupt choices JSON stays untouched: fields start blank and the
        // save path below only writes what the fields contain.
      }
    }
    // New items start with no pre-selected direction (inline error until
    // picked); existing items keep their stored value.
    _direction = existing?.direction;
    _dayFocus = FocusNode(debugLabel: 'itemDay');
    _monthFocus = FocusNode(debugLabel: 'itemMonth');
    _yearFocus = FocusNode(debugLabel: 'itemYear');
  }

  @override
  void dispose() {
    _prompt.dispose();
    _vocabAnswer.dispose();
    _phone.dispose();
    _day.dispose();
    _month.dispose();
    _year.dispose();
    for (final c in _choices) {
      c.dispose();
    }
    _dayFocus.dispose();
    _monthFocus.dispose();
    _yearFocus.dispose();
    super.dispose();
  }

  bool get _isGerman => Localizations.localeOf(context).languageCode == 'de';

  String? _validateRequired(String? v) {
    if (v == null || v.trim().isEmpty) {
      return AppLocalizations.of(context)!.errorRequired;
    }
    return null;
  }

  String? _validatePhone(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) return l10n.errorRequired;
    if (!isValidPhoneAnswer(v)) return l10n.errorInvalidPhone;
    return null;
  }

  /// Editor-only duplicate-vs-answer check (trim/case-insensitive).
  ///
  /// `validation.dart` / the repository intentionally stay unchanged:
  /// duplicates stay importable and #006 tolerates them at lesson time.
  String? _validateChoice(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final l10n = AppLocalizations.of(context)!;
    if (v.trim().toLowerCase() == _vocabAnswer.text.trim().toLowerCase()) {
      return l10n.errorDuplicateChoice;
    }
    return null;
  }

  String? _validateDay(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) return l10n.errorRequired;
    final day = int.tryParse(v.trim());
    if (day == null || day < 1 || day > 31) return l10n.errorInvalidDay;
    return null;
  }

  String? _validateMonth(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) return l10n.errorRequired;
    final month = int.tryParse(v.trim());
    if (month == null || month < 1 || month > 12) {
      return l10n.errorInvalidMonth;
    }
    return null;
  }

  String? _validateYear(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) return l10n.errorRequired;
    final year = int.tryParse(v.trim());
    final todayYear = ref.read(systemClockProvider).now().year;
    if (year == null || year < 1900 || year > todayYear) {
      return l10n.errorInvalidYear;
    }
    return null;
  }

  /// Non-blank trimmed distractors (blank fields are omitted, #006
  /// lesson-time fallback tolerates missing ones).
  List<String> get _nonBlankChoices => [
    for (final c in _choices)
      if (c.text.trim().isNotEmpty) c.text.trim(),
  ];

  String _composedIso() {
    final y = _year.text.trim().padLeft(4, '0');
    final m = _month.text.trim().padLeft(2, '0');
    final d = _day.text.trim().padLeft(2, '0');
    return '$y-$m-$d';
  }

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
    if (_dateError != null) {
      setState(() => _dateError = null);
    }
    if (value.length >= maxLength) {
      if (current == 'year') {
        _yearFocus.unfocus();
      } else {
        _nextDateNode(current).requestFocus();
      }
    }
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

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final formValid = _formKey.currentState!.validate();
    // Composed date check runs even when a part field already fails, so every
    // invalid date (future, pre-1900, impossible like 30.02) surfaces
    // `errorInvalidDate` alongside the part-level errors.
    var dateOk = true;
    if (_type == 'date') {
      final today = ref.read(systemClockProvider).now();
      dateOk = isValidDateAnswer(_composedIso(), today: today);
    }
    final directionOk =
        _type != 'vocab' || validateDirection(_type, _direction) == null;
    if (!formValid || !dateOk || !directionOk) {
      // Inline direction error is always visible while null; just block.
      setState(() {
        if (!dateOk) _dateError = l10n.errorInvalidDate;
      });
      return;
    }
    List<String>? choicesForSave;
    if (_type == 'vocab') {
      final picks = _nonBlankChoices;
      final choicesError = validateChoices(_type, picks);
      if (choicesError != null) {
        setState(() => _saveError = choicesError);
        return;
      }
      choicesForSave = picks.isEmpty ? null : picks;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final repo = ref.read(setsRepositoryProvider);
      final prompt = _prompt.text;
      final answer = switch (_type) {
        'phone' => _phone.text,
        'date' => _composedIso(),
        _ => _vocabAnswer.text,
      };
      if (widget.existing == null) {
        await repo.addItem(
          setId: widget.setId,
          type: _type,
          prompt: prompt,
          answer: answer,
          direction: _type == 'vocab' ? _direction : null,
          choices: choicesForSave,
        );
      } else {
        await repo.updateItem(
          id: widget.existing!.id,
          type: _type,
          prompt: prompt,
          answer: answer,
          directionUpdate: () => _type == 'vocab' ? _direction : null,
          choicesUpdate: () => choicesForSave,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saveError = e.toString();
        _saving = false;
      });
    }
  }

  Widget _vocabFields(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          key: const Key('itemAnswerField'),
          controller: _vocabAnswer,
          decoration: InputDecoration(labelText: l10n.itemAnswerLabel),
          validator: _validateRequired,
        ),
        const SizedBox(height: FoxSpacing.md),
        SegmentedButton<String>(
          key: const Key('itemDirectionField'),
          segments: [
            ButtonSegment(value: 'deEn', label: Text(l10n.directionDeEn)),
            ButtonSegment(value: 'enDe', label: Text(l10n.directionEnDe)),
          ],
          selected: _direction == null ? const <String>{} : {_direction!},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) => setState(() => _direction = s.single),
          style: ButtonStyle(
            minimumSize: WidgetStateProperty.all(const Size(48, 48)),
          ),
        ),
        if (_direction == null) ...[
          const SizedBox(height: FoxSpacing.xs),
          Text(
            l10n.errorDirectionRequired,
            softWrap: true,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: FoxSpacing.md),
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: FoxSpacing.md),
          TextFormField(
            key: Key('itemChoice${i}Field'),
            controller: _choices[i],
            decoration: InputDecoration(
              labelText: l10n.itemDistractorLabel(i + 1),
              hintText: l10n.itemDistractorHint,
            ),
            validator: _validateChoice,
          ),
        ],
      ],
    );
  }

  Widget _phoneField(AppLocalizations l10n) {
    return TextFormField(
      key: const Key('itemAnswerField'),
      controller: _phone,
      decoration: InputDecoration(labelText: l10n.itemAnswerLabel),
      keyboardType: TextInputType.number,
      // No digitsOnly here: PhoneGroupingFormatter already strips exactly
      // the normalizePhone separator set and lets letters through so the
      // validator can reject them with errorInvalidPhone.
      inputFormatters: [PhoneGroupingFormatter()],
      validator: _validatePhone,
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
    required String? Function(String?) validator,
  }) {
    return Expanded(
      flex: fieldName == 'year' ? 3 : 2,
      child: Focus(
        onKeyEvent: (_, event) => _onDateKey(controller, prevNode, event),
        child: TextFormField(
          key: Key(keyName),
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: label),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxLength),
          ],
          validator: validator,
          onChanged: (v) => _onDateChanged(fieldName, v, maxLength),
        ),
      ),
    );
  }

  Widget _dateFields(AppLocalizations l10n) {
    final dayWidget = _dateField(
      keyName: 'itemDayField',
      controller: _day,
      focusNode: _dayFocus,
      prevNode: _prevDateNode('day'),
      fieldName: 'day',
      label: l10n.itemDayLabel,
      maxLength: 2,
      validator: _validateDay,
    );
    final monthWidget = _dateField(
      keyName: 'itemMonthField',
      controller: _month,
      focusNode: _monthFocus,
      prevNode: _prevDateNode('month'),
      fieldName: 'month',
      label: l10n.itemMonthLabel,
      maxLength: 2,
      validator: _validateMonth,
    );
    final yearWidget = _dateField(
      keyName: 'itemYearField',
      controller: _year,
      focusNode: _yearFocus,
      prevNode: _prevDateNode('year'),
      fieldName: 'year',
      label: l10n.itemYearLabel,
      maxLength: 4,
      validator: _validateYear,
    );
    final ordered = _isGerman
        ? [dayWidget, monthWidget, yearWidget]
        : [monthWidget, dayWidget, yearWidget];
    final separator = Text(_isGerman ? '.' : '/');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FoxSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month),
                const SizedBox(width: FoxSpacing.sm),
                Expanded(child: Text(l10n.itemDateHint, softWrap: true)),
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
            const SizedBox(height: FoxSpacing.sm),
            ListenableBuilder(
              listenable: Listenable.merge([_day, _month, _year]),
              builder: (context, _) {
                if (_day.text.trim().isEmpty ||
                    _month.text.trim().isEmpty ||
                    _year.text.trim().isEmpty) {
                  return const SizedBox.shrink();
                }
                return Text(
                  formatDateForDisplay(
                    _composedIso(),
                    Localizations.localeOf(context),
                  ),
                  softWrap: true,
                );
              },
            ),
            if (_dateError != null) ...[
              const SizedBox(height: FoxSpacing.xs),
              Text(
                _dateError!,
                softWrap: true,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.existing == null ? l10n.setDetailAddItem : l10n.save),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('itemTypeField'),
                initialValue: _type,
                decoration: InputDecoration(labelText: l10n.itemTypeLabel),
                items: [
                  DropdownMenuItem(value: 'vocab', child: Text(l10n.typeVocab)),
                  DropdownMenuItem(value: 'phone', child: Text(l10n.typePhone)),
                  DropdownMenuItem(value: 'date', child: Text(l10n.typeDate)),
                ],
                onChanged: (v) => setState(() {
                  _type = v ?? 'vocab';
                  _dateError = null;
                }),
              ),
              const SizedBox(height: FoxSpacing.md),
              TextFormField(
                key: const Key('itemPromptField'),
                controller: _prompt,
                decoration: InputDecoration(labelText: l10n.itemPromptLabel),
                validator: _validateRequired,
              ),
              const SizedBox(height: FoxSpacing.md),
              switch (_type) {
                'phone' => _phoneField(l10n),
                'date' => _dateFields(l10n),
                _ => _vocabFields(l10n),
              },
              if (_saveError != null) ...[
                const SizedBox(height: FoxSpacing.md),
                FoxFeedbackBanner.error(message: _saveError!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FoxSecondaryButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          label: l10n.cancel,
        ),
        FoxPrimaryButton(
          key: const Key('saveItemButton'),
          label: l10n.save,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
