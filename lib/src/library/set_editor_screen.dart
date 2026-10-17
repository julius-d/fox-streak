// Set create/rename form (issue #003).
//
// Edits set title/description/creator/category — never items. Validation
// mirrors #002 `validation.dart`: title + creator trim-then-require
// non-empty, creator max 50 chars (`validateCreatorName`). Category (#045)
// defaults to `vocab` for new sets, matching today's only behavior.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/providers.dart';
import '../data/validation.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'item_type_icons.dart';

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
  late String _category;
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
    _category = effectiveSetCategory(widget.existing?.category);
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
          category: _category,
        );
        if (!mounted) return;
        Navigator.of(context).pop(id);
      } else {
        await repo.updateSet(
          id: widget.existing!.id,
          title: _title.text,
          description: _description.text,
          createdBy: _creator.text,
          category: _category,
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
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.setCategoryLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 8),
            // #052: a bare SegmentedButton gets a tight width constraint
            // from the enclosing ListView, which makes Material stretch
            // every segment to share that width equally — on narrow phones
            // that's narrower than a segment's label, so it wraps mid-word.
            // Wrapping in a horizontal scroll view gives the button an
            // unbounded width instead, so it keeps its intrinsic
            // (unstretched, single-line) size and scrolls if it overflows.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                key: const Key('categoryField'),
                // Material's default segment height (40dp) is below the
                // kit's 48dp a11y floor (#015) — raise it explicitly, same
                // as every other interactive control in the kit.
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(
                    Size(FoxButtonMetrics.minSize, FoxButtonMetrics.minSize),
                  ),
                ),
                segments: [
                  for (final category in const [
                    'vocab',
                    'math',
                    'geography',
                    'general',
                  ])
                    ButtonSegment(
                      value: category,
                      icon: Icon(iconForSetCategory(category)),
                      label: Text(
                        _categoryLabel(l10n, category),
                        key: Key('categoryOption-$category'),
                      ),
                    ),
                ],
                selected: {_category},
                onSelectionChanged: (selection) =>
                    setState(() => _category = selection.first),
              ),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 12),
              FoxFeedbackBanner.error(message: _saveError!),
            ],
            const SizedBox(height: 20),
            FoxPrimaryButton(
              key: const Key('saveSetButton'),
              label: isEdit ? l10n.save : l10n.create,
              expanded: true,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(AppLocalizations l10n, String category) =>
      switch (category) {
        'math' => l10n.categoryMath,
        'geography' => l10n.categoryGeography,
        'general' => l10n.categoryGeneral,
        _ => l10n.categoryVocab,
      };
}
