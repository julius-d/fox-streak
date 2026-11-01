// Marketplace packs screen (issue #101): a chosen source's Packs — always
// fetched fresh (no offline caching of listings, per the issue's MVP
// decision), unlike the sources list's cached `name`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/database.dart';
import '../pet/pet_providers.dart';
import '../widgets/widgets.dart';
import 'marketplace_client.dart';
import 'marketplace_fetch_view.dart';
import 'marketplace_providers.dart';
import 'marketplace_sets_screen.dart';

class MarketplacePacksScreen extends ConsumerWidget {
  final MarketplaceSource source;

  const MarketplacePacksScreen({super.key, required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final manifestUrl = Uri.parse(source.url);
    return Scaffold(
      key: const Key('marketplacePacksScreen'),
      appBar: AppBar(title: Text(source.name)),
      body: MarketplaceFetchView<MarketplaceManifest>(
        fetch: () =>
            ref.read(marketplaceClientProvider).fetchManifest(manifestUrl),
        builder: (context, manifest) {
          if (manifest.packs.isEmpty) {
            return FoxEmptyState(
              title: l10n.marketplacePacksEmptyTitle,
              message: l10n.marketplacePacksEmptyMessage,
              pet: ref.watch(equippedPetProvider),
              titleKey: const Key('marketplacePacksEmptyTitle'),
            );
          }
          return ListView.builder(
            itemCount: manifest.packs.length,
            itemBuilder: (context, index) {
              final pack = manifest.packs[index];
              return ListTile(
                key: Key('marketplacePackTile-${pack.id}'),
                title: Text(pack.title),
                subtitle: pack.description.isEmpty
                    ? null
                    : Text(pack.description),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MarketplaceSetsScreen(
                      sourceUrl: source.url,
                      manifestUrl: manifestUrl,
                      pack: pack,
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
