// Marketplace set preview screen (issue #101): title, description,
// creator, category, item count, with a single contextual primary action
// — "Add to Library" (never imported), "Update" (imported, marketplace
// copy changed), or a disabled "Already up to date" (imported, unchanged).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/marketplace_repository.dart';
import '../data/providers.dart';
import '../data/set_json_codec.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'marketplace_client.dart';
import 'marketplace_fetch_view.dart';
import 'marketplace_providers.dart';

class _PreviewData {
  final Map<String, dynamic> json;
  final ShareSet shareSet;
  final MarketplaceImportState importState;

  const _PreviewData(this.json, this.shareSet, this.importState);
}

class MarketplaceSetPreviewScreen extends ConsumerStatefulWidget {
  final String sourceUrl;
  final Uri packUrl;
  final String packId;
  final MarketplaceSetRef setRef;

  const MarketplaceSetPreviewScreen({
    super.key,
    required this.sourceUrl,
    required this.packUrl,
    required this.packId,
    required this.setRef,
  });

  @override
  ConsumerState<MarketplaceSetPreviewScreen> createState() =>
      _MarketplaceSetPreviewScreenState();
}

class _MarketplaceSetPreviewScreenState
    extends ConsumerState<MarketplaceSetPreviewScreen> {
  int _reloadToken = 0;
  bool _busy = false;

  Future<_PreviewData> _load() async {
    final client = ref.read(marketplaceClientProvider);
    final json = await client.fetchSetJson(widget.packUrl, widget.setRef.url);
    final shareSet = decodeSetFromJson(json);
    final importState = await ref
        .read(marketplaceRepositoryProvider)
        .importStateFor(
          sourceUrl: widget.sourceUrl,
          packId: widget.packId,
          setId: widget.setRef.id,
          listingUpdatedAt: widget.setRef.updatedAt,
        );
    return _PreviewData(json, shareSet, importState);
  }

  Future<void> _onPrimaryPressed(_PreviewData data) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(marketplaceRepositoryProvider);
    if (data.importState.status == MarketplaceSetStatus.updateAvailable) {
      final localSetId = data.importState.localSetId!;
      final editedLocally = await repo.isLocallyEdited(localSetId);
      if (!mounted) return;
      if (editedLocally) {
        final confirmed = await FoxConfirmDialog.show(
          context: context,
          title: l10n.marketplaceUpdateConfirmTitle,
          message: l10n.marketplaceUpdateConfirmMessage,
          confirmLabel: l10n.marketplaceUpdateAction,
          cancelLabel: l10n.cancel,
          confirmKey: const Key('confirmOverwriteLocalEditsButton'),
          cancelKey: const Key('cancelOverwriteLocalEditsButton'),
        );
        if (confirmed != true) return;
      }
    }
    setState(() => _busy = true);
    try {
      if (data.importState.status == MarketplaceSetStatus.notImported) {
        await repo.importSet(
          sourceUrl: widget.sourceUrl,
          packId: widget.packId,
          setId: widget.setRef.id,
          listingUpdatedAt: widget.setRef.updatedAt,
          setJson: data.json,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.marketplaceImportSuccessMessage)),
        );
      } else {
        await repo.updateSet(
          localSetId: data.importState.localSetId!,
          sourceUrl: widget.sourceUrl,
          packId: widget.packId,
          setId: widget.setRef.id,
          listingUpdatedAt: widget.setRef.updatedAt,
          setJson: data.json,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.marketplaceUpdateSuccessMessage)),
        );
      }
      if (!mounted) return;
      setState(() => _reloadToken++);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.importFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _categoryLabel(AppLocalizations l10n, String category) =>
      switch (category) {
        'math' => l10n.categoryMath,
        'geography' => l10n.categoryGeography,
        'general' => l10n.categoryGeneral,
        _ => l10n.categoryVocab,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      key: const Key('marketplaceSetPreviewScreen'),
      appBar: AppBar(title: Text(widget.setRef.title)),
      body: MarketplaceFetchView<_PreviewData>(
        key: ValueKey(_reloadToken),
        fetch: _load,
        builder: (context, data) {
          final (label, enabled, loading) = switch (data.importState.status) {
            MarketplaceSetStatus.notImported => (
              l10n.marketplaceAddToLibrary,
              !_busy,
              _busy,
            ),
            MarketplaceSetStatus.updateAvailable => (
              l10n.marketplaceUpdateAction,
              !_busy,
              _busy,
            ),
            MarketplaceSetStatus.upToDate => (
              l10n.marketplaceAlreadyUpToDate,
              false,
              false,
            ),
          };
          return Padding(
            padding: const EdgeInsets.all(FoxSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (data.shareSet.description.isNotEmpty) ...<Widget>[
                  Text(
                    data.shareSet.description,
                    key: const Key('marketplacePreviewDescription'),
                  ),
                  const SizedBox(height: FoxSpacing.md),
                ],
                Text(
                  l10n.marketplacePreviewCreatedBy(data.shareSet.createdBy),
                  key: const Key('marketplacePreviewCreatedBy'),
                ),
                const SizedBox(height: FoxSpacing.sm),
                Text(
                  _categoryLabel(l10n, data.shareSet.category),
                  key: const Key('marketplacePreviewCategory'),
                ),
                const SizedBox(height: FoxSpacing.sm),
                Text(
                  l10n.setItemCount(data.shareSet.items.length),
                  key: const Key('marketplacePreviewItemCount'),
                ),
                const SizedBox(height: FoxSpacing.xl),
                FoxPrimaryButton(
                  key: const Key('marketplacePrimaryActionButton'),
                  label: label,
                  expanded: true,
                  isLoading: loading,
                  onPressed: enabled ? () => _onPrimaryPressed(data) : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
