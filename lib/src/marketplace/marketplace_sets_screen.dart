// Marketplace pack screen (issue #101, reworked by #121): a chosen Pack with
// its Sets as a read-only preview, and "Download pack" as the main action —
// replaced by "Update pack" / "Pack is up to date" once downloaded. Always
// fetched fresh, same as the Packs screen.
//
// Download and update fetch every needed set first and only then write them
// in one DB transaction, so a failure (e.g. offline) leaves nothing
// half-done.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/marketplace_repository.dart';
import '../data/providers.dart';
import '../library/item_type_icons.dart';
import '../pet/pet_providers.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'marketplace_client.dart';
import 'marketplace_fetch_view.dart';
import 'marketplace_providers.dart';
import 'marketplace_set_preview_screen.dart';
import 'pack_update_controller.dart';

class _PackData {
  final MarketplacePackListing listing;
  final MarketplacePackState state;

  const _PackData(this.listing, this.state);
}

class MarketplaceSetsScreen extends ConsumerStatefulWidget {
  final String sourceUrl;
  final Uri manifestUrl;
  final MarketplacePackRef pack;

  const MarketplaceSetsScreen({
    super.key,
    required this.sourceUrl,
    required this.manifestUrl,
    required this.pack,
  });

  @override
  ConsumerState<MarketplaceSetsScreen> createState() =>
      _MarketplaceSetsScreenState();
}

class _MarketplaceSetsScreenState extends ConsumerState<MarketplaceSetsScreen> {
  int _reloadToken = 0;
  bool _busy = false;
  int _done = 0;
  int _total = 0;
  bool _failed = false;

  // Pure URL math (no network): the same resolution `fetchPack` performs,
  // recomputed so set JSON can be fetched relative to the pack.
  Uri get _packUrl => widget.manifestUrl.resolveUri(Uri.parse(widget.pack.url));

  Map<String, String> _listed(MarketplacePackListing listing) => {
    for (final set in listing.sets) set.id: set.updatedAt,
  };

  Future<_PackData> _load() async {
    final listing = await ref
        .read(marketplaceClientProvider)
        .fetchPack(widget.manifestUrl, widget.pack.url);
    await ref
        .read(marketplaceRepositoryProvider)
        .syncPackMeta(
          sourceUrl: widget.sourceUrl,
          packId: widget.pack.id,
          title: listing.title,
          description: listing.description,
        );
    final state = await ref
        .read(marketplaceRepositoryProvider)
        .packStateFor(
          sourceUrl: widget.sourceUrl,
          packId: widget.pack.id,
          listedSets: _listed(listing),
        );
    return _PackData(listing, state);
  }

  Future<List<FetchedMarketplaceSet>> _fetchSets(
    List<MarketplaceSetRef> refs,
  ) async {
    final client = ref.read(marketplaceClientProvider);
    final fetched = <FetchedMarketplaceSet>[];
    setState(() {
      _done = 0;
      _total = refs.length;
    });
    for (final setRef in refs) {
      final json = await client.fetchSetJson(_packUrl, setRef.url);
      fetched.add(
        FetchedMarketplaceSet(
          setId: setRef.id,
          listingUpdatedAt: setRef.updatedAt,
          json: json,
        ),
      );
      if (mounted) setState(() => _done = fetched.length);
    }
    return fetched;
  }

  Future<void> _onPrimaryPressed(_PackData data) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(marketplaceRepositoryProvider);
    final listing = data.listing;
    final isUpdate = data.state.status == MarketplacePackStatus.updateAvailable;

    var toFetch = listing.sets;
    final skipped = <String>{};
    if (isUpdate) {
      final outdated = (await repo.outdatedSetIds(
        sourceUrl: widget.sourceUrl,
        packId: widget.pack.id,
        listedSets: _listed(listing),
      )).toSet();
      final edited = await repo.locallyEditedSets(
        sourceUrl: widget.sourceUrl,
        packId: widget.pack.id,
        setIds: outdated,
      );
      if (!mounted) return;
      if (edited.isNotEmpty) {
        final overwrite = await FoxConfirmDialog.show(
          context: context,
          title: l10n.marketplacePackOverwriteTitle,
          message: l10n.marketplacePackOverwriteMessage(
            edited.map((e) => '• ${e.set.title}').join('\n'),
          ),
          confirmLabel: l10n.marketplacePackOverwriteConfirm,
          cancelLabel: l10n.marketplacePackOverwriteSkip,
          confirmKey: const Key('confirmOverwriteLocalEditsButton'),
          cancelKey: const Key('skipOverwriteLocalEditsButton'),
        );
        if (overwrite != true) skipped.addAll(edited.map((e) => e.setId));
      }
      toFetch = [
        for (final set in listing.sets)
          if (outdated.contains(set.id) && !skipped.contains(set.id)) set,
      ];
    }

    if (isUpdate && toFetch.isEmpty) return; // everything skipped
    // Already being updated from the Home banner (#125): never twice.
    final locks = ref.read(packUpdateLocksProvider);
    if (!locks.tryAcquire(widget.sourceUrl, widget.pack.id)) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final fetched = await _fetchSets(toFetch);
      if (isUpdate) {
        await repo.updatePack(
          sourceUrl: widget.sourceUrl,
          packId: widget.pack.id,
          title: listing.title,
          description: listing.description,
          sets: fetched,
        );
      } else {
        await repo.downloadPack(
          sourceUrl: widget.sourceUrl,
          packId: widget.pack.id,
          title: listing.title,
          description: listing.description,
          sets: fetched,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUpdate
                ? l10n.marketplacePackUpdated
                : l10n.marketplacePackDownloaded,
          ),
        ),
      );
      ref
          .read(packUpdateControllerProvider.notifier)
          .packChanged(widget.sourceUrl, widget.pack.id);
      setState(() => _reloadToken++);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      locks.release(widget.sourceUrl, widget.pack.id);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      key: const Key('marketplaceSetsScreen'),
      appBar: AppBar(title: Text(widget.pack.title)),
      body: MarketplaceFetchView<_PackData>(
        key: ValueKey(_reloadToken),
        fetch: _load,
        builder: (context, data) {
          final listing = data.listing;
          if (listing.sets.isEmpty) {
            return FoxEmptyState(
              title: l10n.marketplaceSetsEmptyTitle,
              message: l10n.marketplaceSetsEmptyMessage,
              pet: ref.watch(equippedPetProvider),
              titleKey: const Key('marketplaceSetsEmptyTitle'),
            );
          }
          final (label, enabled) = switch (data.state.status) {
            MarketplacePackStatus.notDownloaded => (
              l10n.marketplaceDownloadPack,
              !_busy,
            ),
            MarketplacePackStatus.updateAvailable => (
              l10n.marketplaceUpdatePack,
              !_busy,
            ),
            MarketplacePackStatus.upToDate => (
              l10n.marketplacePackUpToDate,
              false,
            ),
          };
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(FoxSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (listing.description.isNotEmpty) ...[
                      Text(
                        listing.description,
                        key: const Key('marketplacePackDescription'),
                      ),
                      const SizedBox(height: FoxSpacing.md),
                    ],
                    FoxPrimaryButton(
                      key: const Key('marketplacePrimaryActionButton'),
                      label: label,
                      expanded: true,
                      isLoading: _busy,
                      onPressed: enabled ? () => _onPrimaryPressed(data) : null,
                    ),
                    if (_busy && _total > 0) ...[
                      const SizedBox(height: FoxSpacing.md),
                      FoxProgressBar(
                        key: const Key('marketplaceDownloadProgress'),
                        value: _done / _total,
                        semanticsLabel: l10n.marketplaceDownloadProgress(
                          _done,
                          _total,
                        ),
                      ),
                      const SizedBox(height: FoxSpacing.xs),
                      Text(l10n.marketplaceDownloadProgress(_done, _total)),
                    ],
                    if (_failed) ...[
                      const SizedBox(height: FoxSpacing.md),
                      FoxFeedbackBanner.error(
                        key: const Key('marketplaceDownloadError'),
                        message: l10n.marketplaceDownloadFailed,
                      ),
                    ],
                    const SizedBox(height: FoxSpacing.lg),
                    Text(
                      l10n.marketplacePackSetsHeading,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              for (final setRef in listing.sets)
                ListTile(
                  key: Key('marketplaceSetTile-${setRef.id}'),
                  leading: Icon(
                    iconForSetCategory(setRef.category),
                    color: colorForSetCategory(context, setRef.category),
                  ),
                  title: Text(setRef.title),
                  subtitle: Text(
                    setRef.description.isEmpty
                        ? l10n.setItemCount(setRef.itemCount)
                        : '${setRef.description} · '
                              '${l10n.setItemCount(setRef.itemCount)}',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MarketplaceSetPreviewScreen(
                        packUrl: _packUrl,
                        setRef: setRef,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
