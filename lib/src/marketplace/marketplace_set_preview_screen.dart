// Marketplace set preview screen (issue #101, read-only since #121): title,
// description, creator, category and item count of one set of a pack. Sets
// are only obtained by downloading the whole pack, so there is no action.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../data/set_json_codec.dart';
import '../theme/fox_streak_theme.dart';
import 'marketplace_client.dart';
import 'marketplace_fetch_view.dart';
import 'marketplace_providers.dart';

class MarketplaceSetPreviewScreen extends ConsumerWidget {
  final Uri packUrl;
  final MarketplaceSetRef setRef;

  const MarketplaceSetPreviewScreen({
    super.key,
    required this.packUrl,
    required this.setRef,
  });

  String _categoryLabel(AppLocalizations l10n, String category) =>
      switch (category) {
        'math' => l10n.categoryMath,
        'geography' => l10n.categoryGeography,
        'general' => l10n.categoryGeneral,
        _ => l10n.categoryVocab,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      key: const Key('marketplaceSetPreviewScreen'),
      appBar: AppBar(title: Text(setRef.title)),
      body: MarketplaceFetchView<ShareSet>(
        fetch: () async => decodeSetFromJson(
          await ref
              .read(marketplaceClientProvider)
              .fetchSetJson(packUrl, setRef.url),
        ),
        builder: (context, shareSet) {
          return Padding(
            padding: const EdgeInsets.all(FoxSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (shareSet.description.isNotEmpty) ...<Widget>[
                  Text(
                    shareSet.description,
                    key: const Key('marketplacePreviewDescription'),
                  ),
                  const SizedBox(height: FoxSpacing.md),
                ],
                Text(
                  l10n.marketplacePreviewCreatedBy(shareSet.createdBy),
                  key: const Key('marketplacePreviewCreatedBy'),
                ),
                const SizedBox(height: FoxSpacing.sm),
                Text(
                  _categoryLabel(l10n, shareSet.category),
                  key: const Key('marketplacePreviewCategory'),
                ),
                const SizedBox(height: FoxSpacing.sm),
                Text(
                  l10n.setItemCount(shareSet.items.length),
                  key: const Key('marketplacePreviewItemCount'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
