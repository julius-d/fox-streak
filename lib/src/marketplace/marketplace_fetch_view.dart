// Generic loading/error/data switcher for a one-shot marketplace fetch
// (issue #101): manifest, pack listing, or Set preview. MVP has no offline
// caching or retry — a failed fetch shows `l10n.marketplaceFetchError` in
// place of the list/preview; the user retries by navigating back and
// re-entering (see the issue's "Error handling" decisions).
//
// Pass a new [key] (e.g. `ValueKey` on a reload counter) to force a fresh
// fetch — reusing the same instance never re-fetches on its own.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';

class MarketplaceFetchView<T> extends StatefulWidget {
  final Future<T> Function() fetch;
  final Widget Function(BuildContext context, T data) builder;

  const MarketplaceFetchView({
    super.key,
    required this.fetch,
    required this.builder,
  });

  @override
  State<MarketplaceFetchView<T>> createState() =>
      _MarketplaceFetchViewState<T>();
}

class _MarketplaceFetchViewState<T> extends State<MarketplaceFetchView<T>> {
  late final Future<T> _future = widget.fetch();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            key: Key('marketplaceLoading'),
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(FoxSpacing.lg),
              child: FoxFeedbackBanner.error(
                key: const Key('marketplaceFetchError'),
                message: l10n.marketplaceFetchError,
              ),
            ),
          );
        }
        return widget.builder(context, snapshot.data as T);
      },
    );
  }
}
