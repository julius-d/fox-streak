// Pack management (issue #121): rename (own packs only) and delete packs.
//
// Reached from the library app bar so it also works while the library shows
// a single pack without a section header.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/packs_repository.dart';
import '../data/providers.dart';
import '../widgets/widgets.dart';
import 'library_providers.dart';

class PackManagementScreen extends ConsumerWidget {
  const PackManagementScreen({super.key});

  Future<void> _rename(BuildContext context, WidgetRef ref, Pack pack) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenamePackDialog(initialTitle: pack.title),
    );
    if (title == null) return;
    await ref.read(packsRepositoryProvider).renamePack(pack.id, title);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Pack pack) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(packsRepositoryProvider);
    final count = await repo.countSets(pack.id);
    if (!context.mounted) return;
    final confirmed = await FoxConfirmDialog.show(
      context: context,
      title: l10n.packDeleteTitle,
      message: l10n.packDeleteMessage(pack.title, count),
      confirmLabel: l10n.confirmDelete,
      cancelLabel: l10n.cancel,
      confirmKey: const Key('confirmDeletePackButton'),
      cancelKey: const Key('cancelDeletePackButton'),
    );
    if (confirmed == true) await repo.deletePack(pack.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final packs = ref.watch(allPacksProvider).value ?? const <Pack>[];
    final sets = ref.watch(allSetsProvider).value ?? const <QuestionSet>[];
    return Scaffold(
      key: const Key('packManagementScreen'),
      appBar: AppBar(title: Text(l10n.packManageTitle)),
      body: ListView(
        children: [
          for (final pack in packs)
            ListTile(
              key: Key('packTile-${pack.id}'),
              title: Text(pack.title),
              subtitle: Text(
                [
                  if (pack.isDownloaded) l10n.packDownloadedLabel,
                  l10n.packSetCount(
                    sets.where((s) => s.packId == pack.id).length,
                  ),
                ].join(' · '),
              ),
              trailing: PopupMenuButton<String>(
                key: Key('packMenu-${pack.id}'),
                tooltip: l10n.packActions,
                onSelected: (value) => switch (value) {
                  'rename' => _rename(context, ref, pack),
                  _ => _delete(context, ref, pack),
                },
                itemBuilder: (context) => [
                  if (pack.isOwn)
                    PopupMenuItem(
                      value: 'rename',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.drive_file_rename_outline),
                        title: Text(l10n.packRename),
                      ),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_outline),
                      title: Text(l10n.packDelete),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RenamePackDialog extends StatefulWidget {
  final String initialTitle;

  const _RenamePackDialog({required this.initialTitle});

  @override
  State<_RenamePackDialog> createState() => _RenamePackDialogState();
}

class _RenamePackDialogState extends State<_RenamePackDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialTitle,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.packRename),
      content: TextField(
        key: const Key('renamePackField'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.setTitleLabel),
      ),
      actions: [
        FoxSecondaryButton(
          key: const Key('cancelRenamePackButton'),
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        FoxPrimaryButton(
          key: const Key('confirmRenamePackButton'),
          label: l10n.save,
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}
