// Marketplace sources screen (issue #101): lists the user's added
// marketplace sources (empty state + "add a marketplace" action), lets
// them add/remove sources, and drills into a chosen source's Packs.
//
// Reachable from `LibraryScreen`'s `newSetFab` speed-dial third mini-FAB.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../data/providers.dart';
import '../pet/pet_providers.dart';
import '../widgets/widgets.dart';
import 'marketplace_client.dart';
import 'marketplace_packs_screen.dart';
import 'marketplace_providers.dart';

class MarketplaceSourcesScreen extends ConsumerWidget {
  const MarketplaceSourcesScreen({super.key});

  Future<void> _addSource(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _AddMarketplaceSourceDialog(),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    MarketplaceSource source,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await FoxConfirmDialog.show(
      context: context,
      title: l10n.marketplaceRemoveSourceTitle,
      message: l10n.marketplaceRemoveSourceMessage(source.name),
      confirmLabel: l10n.marketplaceRemoveSourceAction,
      cancelLabel: l10n.cancel,
      confirmKey: Key('confirmRemoveMarketplaceSource-${source.id}'),
      cancelKey: Key('cancelRemoveMarketplaceSource-${source.id}'),
    );
    if (confirmed == true) {
      await ref.read(marketplaceRepositoryProvider).removeSource(source.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sourcesAsync = ref.watch(marketplaceSourcesProvider);
    return Scaffold(
      key: const Key('marketplaceSourcesScreen'),
      appBar: AppBar(title: Text(l10n.marketplace)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addMarketplaceSourceFab'),
        onPressed: () => _addSource(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.marketplaceAddSource),
      ),
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (sources) {
          if (sources.isEmpty) {
            return FoxEmptyState(
              title: l10n.marketplaceSourcesEmptyTitle,
              message: l10n.marketplaceSourcesEmptyMessage,
              pet: ref.watch(equippedPetProvider),
              ctaLabel: l10n.marketplaceAddSource,
              onCta: () => _addSource(context),
              titleKey: const Key('marketplaceSourcesEmptyTitle'),
              ctaKey: const Key('marketplaceSourcesEmptyCta'),
            );
          }
          return ListView.builder(
            padding: fabListBottomPadding(context),
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              return ListTile(
                key: Key('marketplaceSourceTile-${source.id}'),
                title: Text(source.name),
                subtitle: Text(source.url),
                trailing: IconButton(
                  key: Key('removeMarketplaceSource-${source.id}'),
                  tooltip: l10n.marketplaceRemoveSourceAction,
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmRemove(context, ref, source),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MarketplacePacksScreen(source: source),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Dialog for adding a marketplace source by URL (#101): resolves the
/// bare-base-URL shorthand, fetches + validates the manifest, then stores
/// `(resolved url, manifest name)`.
class _AddMarketplaceSourceDialog extends ConsumerStatefulWidget {
  const _AddMarketplaceSourceDialog();

  @override
  ConsumerState<_AddMarketplaceSourceDialog> createState() =>
      _AddMarketplaceSourceDialogState();
}

class _AddMarketplaceSourceDialogState
    extends ConsumerState<_AddMarketplaceSourceDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(marketplaceClientProvider);
      final manifestUrl = client.resolveManifestUrl(_controller.text);
      final manifest = await client.fetchManifest(manifestUrl);
      await ref
          .read(marketplaceRepositoryProvider)
          .addSource(url: manifestUrl.toString(), name: manifest.name);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ArgumentError {
      if (!mounted) return;
      setState(() => _error = l10n.marketplaceAddSourceDuplicate);
    } on MarketplaceFetchException {
      if (!mounted) return;
      setState(() => _error = l10n.marketplaceAddSourceError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.marketplaceAddSource),
      content: TextField(
        key: const Key('marketplaceSourceUrlField'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          hintText: l10n.marketplaceAddSourceUrlHint,
          errorText: _error,
        ),
      ),
      actions: <Widget>[
        FoxSecondaryButton(
          key: const Key('cancelAddMarketplaceSourceButton'),
          label: l10n.cancel,
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
        ),
        FoxPrimaryButton(
          key: const Key('confirmAddMarketplaceSourceButton'),
          label: l10n.marketplaceAddSourceConfirm,
          isLoading: _loading,
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }
}
