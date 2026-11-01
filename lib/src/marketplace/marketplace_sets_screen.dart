// Marketplace sets screen (issue #101): a chosen Pack's Sets (title,
// description, item count, category) — always fetched fresh, same as the
// Packs screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../library/item_type_icons.dart';
import '../pet/pet_providers.dart';
import '../widgets/widgets.dart';
import 'marketplace_client.dart';
import 'marketplace_fetch_view.dart';
import 'marketplace_providers.dart';
import 'marketplace_set_preview_screen.dart';

class MarketplaceSetsScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      key: const Key('marketplaceSetsScreen'),
      appBar: AppBar(title: Text(pack.title)),
      body: MarketplaceFetchView<MarketplacePackListing>(
        fetch: () => ref
            .read(marketplaceClientProvider)
            .fetchPack(manifestUrl, pack.url),
        builder: (context, listing) {
          if (listing.sets.isEmpty) {
            return FoxEmptyState(
              title: l10n.marketplaceSetsEmptyTitle,
              message: l10n.marketplaceSetsEmptyMessage,
              pet: ref.watch(equippedPetProvider),
              titleKey: const Key('marketplaceSetsEmptyTitle'),
            );
          }
          // Pure URL math (no network): the same resolution `fetchPack`
          // already performed to reach `listing`, recomputed so the
          // preview screen can fetch each Set's JSON without the client
          // re-exposing its internal resolved pack URL.
          final packUrl = manifestUrl.resolveUri(Uri.parse(pack.url));
          return ListView.builder(
            itemCount: listing.sets.length,
            itemBuilder: (context, index) {
              final setRef = listing.sets[index];
              return ListTile(
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
                      sourceUrl: sourceUrl,
                      packUrl: packUrl,
                      packId: pack.id,
                      setRef: setRef,
                    ),
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
