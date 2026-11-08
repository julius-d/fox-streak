// Pack picker for creating/importing a set (issue #121).
//
// Lists the learner's own packs only — downloaded packs are never valid
// targets for own sets — plus a "New pack…" entry that reveals an inline
// title field; the created pack is selected right away. The initial
// selection is the pack last used (see `PacksRepository.defaultOwnPackId`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/providers.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'library_providers.dart';

/// Sentinel dropdown value for the "New pack…" entry.
const int _kNewPackValue = -1;

class PackPicker extends ConsumerStatefulWidget {
  /// Preselected pack; falls back to the last-used own pack when null.
  final int? initialPackId;

  /// Called with the selected pack id, once on load and on every change.
  /// Null while "New pack…" is open and no pack is created yet.
  final ValueChanged<int?> onChanged;

  const PackPicker({super.key, this.initialPackId, required this.onChanged});

  @override
  ConsumerState<PackPicker> createState() => _PackPickerState();
}

class _PackPickerState extends ConsumerState<PackPicker> {
  final _newTitle = TextEditingController();
  int? _selected;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newTitle.addListener(() => setState(() {}));
    _loadInitial();
  }

  @override
  void dispose() {
    _newTitle.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    // Never notify the parent synchronously from initState (mid-build).
    await Future<void>.value();
    final id =
        widget.initialPackId ??
        await ref.read(packsRepositoryProvider).defaultOwnPackId();
    if (!mounted) return;
    _select(id);
  }

  void _select(int id) {
    setState(() {
      _selected = id;
      _creating = false;
      _error = null;
    });
    widget.onChanged(id);
  }

  Future<void> _createPack() async {
    try {
      final id = await ref
          .read(packsRepositoryProvider)
          .createPack(_newTitle.text);
      if (!mounted) return;
      _newTitle.clear();
      _select(id);
    } on ArgumentError catch (e) {
      setState(() => _error = e.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final packs = ref.watch(ownPacksProvider).value ?? const [];
    final hasSelection = packs.any((p) => p.id == _selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InputDecorator(
          decoration: InputDecoration(labelText: l10n.packPickerLabel),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              key: const Key('packPicker'),
              isExpanded: true,
              value: _creating
                  ? _kNewPackValue
                  : (hasSelection ? _selected : null),
              items: [
                for (final pack in packs)
                  DropdownMenuItem(
                    value: pack.id,
                    child: Text(
                      pack.title,
                      key: Key('packPickerOption-${pack.id}'),
                      softWrap: true,
                    ),
                  ),
                DropdownMenuItem(
                  value: _kNewPackValue,
                  child: Text(
                    l10n.packPickerNewPack,
                    key: const Key('packPickerNewPackOption'),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                if (value == _kNewPackValue) {
                  setState(() => _creating = true);
                  widget.onChanged(null);
                } else {
                  _select(value);
                }
              },
            ),
          ),
        ),
        if (_creating) ...[
          const SizedBox(height: FoxSpacing.sm),
          TextField(
            key: const Key('newPackTitleField'),
            controller: _newTitle,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.packNewTitleLabel,
              errorText: _error,
            ),
          ),
          const SizedBox(height: FoxSpacing.sm),
          FoxSecondaryButton(
            key: const Key('createPackButton'),
            label: l10n.packNewCreate,
            onPressed: _newTitle.text.trim().isEmpty ? null : _createPack,
          ),
        ],
      ],
    );
  }
}

/// Asks which own pack an imported set goes into. Resolves to the chosen
/// pack id, or null when cancelled.
Future<int?> showPackChoiceDialog(BuildContext context) {
  return showDialog<int>(
    context: context,
    builder: (_) => const _PackChoiceDialog(),
  );
}

class _PackChoiceDialog extends StatefulWidget {
  const _PackChoiceDialog();

  @override
  State<_PackChoiceDialog> createState() => _PackChoiceDialogState();
}

class _PackChoiceDialogState extends State<_PackChoiceDialog> {
  int? _packId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.packImportTitle),
      content: SingleChildScrollView(
        child: PackPicker(
          onChanged: (id) {
            if (_packId != id) setState(() => _packId = id);
          },
        ),
      ),
      actions: [
        FoxSecondaryButton(
          key: const Key('cancelPackChoiceButton'),
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        FoxPrimaryButton(
          key: const Key('confirmPackChoiceButton'),
          label: l10n.importSet,
          onPressed: _packId == null
              ? null
              : () => Navigator.of(context).pop(_packId),
        ),
      ],
    );
  }
}
