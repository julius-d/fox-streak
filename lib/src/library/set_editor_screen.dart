// Set create/rename form (issue #003).
//
// Edits set title/description/creator only — never items. Validation mirrors
// #002 `validation.dart`: title + creator trim-then-require non-empty,
// creator max 50 chars (`validateCreatorName`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/providers.dart';
import '../data/validation.dart';

/// Form for creating a set (when [existing] is null) or renaming/editing it.
class SetEditorScreen extends ConsumerStatefulWidget {
  final QuestionSet? existing;

  const SetEditorScreen({super.key, this.existing});

  @override
  ConsumerState<SetEditorScreen> createState() => _SetEditorScreenState();
}

class _SetEditorScreenState extends ConsumerState<SetEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _creator;
  late final TextEditingController _description;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _creator = TextEditingController(text: widget.existing?.createdBy ?? '');
    _description = TextEditingController(
      text: widget.existing?.description ?? '',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _creator.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final repo = ref.read(setsRepositoryProvider);
      if (widget.existing == null) {
        final id = await repo.createSet(
          title: _title.text,
          description: _description.text,
          createdBy: _creator.text,
        );
        if (!mounted) return;
        Navigator.of(context).pop(id);
      } else {
        await repo.updateSet(
          id: widget.existing!.id,
          title: _title.text,
          description: _description.text,
          createdBy: _creator.text,
        );
        if (!mounted) return;
        Navigator.of(context).pop(widget.existing!.id);
      }
    } catch (e) {
      setState(() {
        _saveError = e.toString();
        _saving = false;
      });
      return;
    }
    // Popped on success; `_saving` state is discarded with the route.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? l10n.editSet : l10n.createSet)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('titleField'),
              controller: _title,
              decoration: InputDecoration(labelText: l10n.setTitleLabel),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.errorRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('creatorField'),
              controller: _creator,
              decoration: InputDecoration(labelText: l10n.setCreatorLabel),
              textInputAction: TextInputAction.next,
              maxLength: kMaxCreatorNameLength,
              validator: (v) {
                final err = validateCreatorName(v);
                if (err == null) return null;
                if ((v ?? '').trim().isEmpty) return l10n.errorRequired;
                return l10n.errorCreatorLength;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('descriptionField'),
              controller: _description,
              decoration: InputDecoration(labelText: l10n.setDescriptionLabel),
              maxLines: 3,
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 12),
              Text(
                _saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('saveSetButton'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? l10n.save : l10n.create),
            ),
          ],
        ),
      ),
    );
  }
}
