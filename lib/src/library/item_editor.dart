// Minimal item add/edit form (issue #003 navigation shell).
//
// Field widgets are owned by #004 `ItemEditor`; this minimal version exists
// so sets are usable now and satisfies the #003 widget tests. Validation
// mirrors #002 `validation.dart` exactly:
// - trim-then-require non-empty prompt/answer
// - phone via `isValidPhoneAnswer` (paste with separators auto-normalised on
//   save by the repository)
// - date via `isValidDateAnswer` (strict ISO YYYY-MM-DD, 1900-01-01..today)
// - vocab requires `direction` (deEn|enDe); non-vocab must omit it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/providers.dart';
import '../data/validation.dart';

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
  late final TextEditingController _answer;
  String? _direction;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ?? 'vocab';
    _prompt = TextEditingController(text: widget.existing?.prompt ?? '');
    _answer = TextEditingController(text: widget.existing?.answer ?? '');
    _direction = widget.existing?.direction ?? 'deEn';
  }

  @override
  void dispose() {
    _prompt.dispose();
    _answer.dispose();
    super.dispose();
  }

  String? _validateAnswer(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) return l10n.errorRequired;
    if (_type == 'phone' && !isValidPhoneAnswer(v)) {
      return l10n.errorInvalidPhone;
    }
    if (_type == 'date' && !isValidDateAnswer(v)) {
      return l10n.errorInvalidDate;
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == 'vocab' && _direction == null) {
      setState(() {
        _saveError = AppLocalizations.of(context)!.errorDirectionRequired;
      });
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final repo = ref.read(setsRepositoryProvider);
      if (widget.existing == null) {
        await repo.addItem(
          setId: widget.setId,
          type: _type,
          prompt: _prompt.text,
          answer: _answer.text,
          direction: _type == 'vocab' ? _direction : null,
        );
      } else {
        await repo.updateItem(
          id: widget.existing!.id,
          type: _type,
          prompt: _prompt.text,
          answer: _answer.text,
          directionUpdate: () => _type == 'vocab' ? _direction : null,
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
                onChanged: (v) => setState(() => _type = v ?? 'vocab'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('itemPromptField'),
                controller: _prompt,
                decoration: InputDecoration(labelText: l10n.itemPromptLabel),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.errorRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('itemAnswerField'),
                controller: _answer,
                decoration: InputDecoration(labelText: l10n.itemAnswerLabel),
                keyboardType: _type == 'phone'
                    ? TextInputType.number
                    : TextInputType.text,
                validator: _validateAnswer,
              ),
              if (_type == 'vocab') ...[
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  key: const Key('itemDirectionField'),
                  segments: [
                    ButtonSegment(
                      value: 'deEn',
                      label: Text(l10n.directionDeEn),
                    ),
                    ButtonSegment(
                      value: 'enDe',
                      label: Text(l10n.directionEnDe),
                    ),
                  ],
                  selected: {_direction ?? 'deEn'},
                  onSelectionChanged: (s) =>
                      setState(() => _direction = s.single),
                  style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all(const Size(48, 48)),
                  ),
                ),
              ],
              if (_saveError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('saveItemButton'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}
