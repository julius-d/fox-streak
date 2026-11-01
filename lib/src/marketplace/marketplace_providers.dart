// Riverpod wiring for the Marketplace feature (issue #101).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/database.dart';
import '../data/providers.dart';
import 'marketplace_client.dart';

/// HTTP client for marketplace fetches; override with a fake/mock in tests
/// (e.g. `package:http/testing.dart`'s `MockClient`) so no test ever makes
/// a real network call — same injection pattern as [Clock].
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final marketplaceClientProvider = Provider<MarketplaceClient>((ref) {
  return MarketplaceClient(ref.watch(httpClientProvider));
});

/// All added marketplace sources, ordered by id (repository order).
final marketplaceSourcesProvider = StreamProvider<List<MarketplaceSource>>((
  ref,
) {
  return ref.watch(marketplaceRepositoryProvider).watchSources();
});
