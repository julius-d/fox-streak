// Marketplace fetch client (issue #101): plain HTTP GET fetches for the
// manifest/pack-listing documents (the Set document itself is fetched as a
// raw JSON map and handed to `set_json_codec.dart`'s existing
// `decodeSetFromJson`/`importSetFromJson` — no separate validation here).
//
// Enforces the Marketplace API's security rule: `packs[].url`/`sets[].url`
// must be relative to the document they were fetched from — an absolute
// (has a scheme) or protocol-relative (`//...`) `url` is rejected, not
// followed, so a manifest can never redirect the app to an unapproved host.
// See `docs/marketplace-api.md`.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/validation.dart'
    show effectiveSetCategory, isValidUuid, kSetCategories;

const String kMarketplaceManifestFormat = 'foxstreak-marketplace';
const int kMarketplaceManifestVersion = 1;
const String kMarketplacePackFormat = 'foxstreak-pack';
const int kMarketplacePackVersion = 1;

/// Thrown on any marketplace fetch failure: no network, broken/unreachable
/// source, non-200 response, invalid JSON, a bad `format`/`version`
/// envelope, or a `url` that isn't relative to the document it came from.
/// Callers show this in place of the list/preview (MVP: no retry/backoff,
/// no offline caching — matching the `importFailed`-snackbar level of
/// effort).
class MarketplaceFetchException implements Exception {
  final String message;
  const MarketplaceFetchException(this.message);

  @override
  String toString() => 'MarketplaceFetchException: $message';
}

/// One entry in a manifest's `packs` list.
class MarketplacePackRef {
  final String id;
  final String title;
  final String description;
  final String url;

  const MarketplacePackRef({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
  });
}

/// A fetched + validated Marketplace manifest (level 1 of the API).
class MarketplaceManifest {
  final String name;
  final String description;
  final List<MarketplacePackRef> packs;

  const MarketplaceManifest({
    required this.name,
    required this.description,
    required this.packs,
  });
}

/// One entry in a pack listing's `sets` list.
class MarketplaceSetRef {
  final String id;
  final String title;
  final String description;
  final String category;
  final int itemCount;
  final String updatedAt;
  final String url;

  const MarketplaceSetRef({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.itemCount,
    required this.updatedAt,
    required this.url,
  });
}

/// A fetched + validated Pack listing (level 2 of the API).
class MarketplacePackListing {
  final String id;
  final String title;
  final String description;
  final List<MarketplaceSetRef> sets;

  const MarketplacePackListing({
    required this.id,
    required this.title,
    required this.description,
    required this.sets,
  });
}

/// Fetches + validates the Marketplace API's manifest/pack-listing
/// documents, injected with an [http.Client] (overridable with
/// `package:http/testing.dart`'s `MockClient` in tests — no real network
/// access in widget/integration tests, same pattern as [Clock] injection).
class MarketplaceClient {
  final http.Client _client;

  const MarketplaceClient(this._client);

  /// Resolves the user-typed source [input] into the manifest URL to fetch,
  /// per the "URL shorthand" rule: an input ending in `.json` is used as-is;
  /// a bare base URL gets `/marketplace.json` appended (inserting the `/`
  /// only if [input] doesn't already end with one). A single, deterministic
  /// rule applied before any network call — never try-then-fallback.
  Uri resolveManifestUrl(String input) {
    final trimmed = input.trim();
    final withManifestPath = trimmed.toLowerCase().endsWith('.json')
        ? trimmed
        : '$trimmed${trimmed.endsWith('/') ? '' : '/'}marketplace.json';
    final uri = Uri.tryParse(withManifestPath);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const MarketplaceFetchException('invalid marketplace URL');
    }
    return uri;
  }

  /// Fetches + validates the manifest at [url] (already resolved via
  /// [resolveManifestUrl]).
  Future<MarketplaceManifest> fetchManifest(Uri url) async {
    final map = await _fetchJsonObject(url);
    _checkEnvelope(
      map,
      format: kMarketplaceManifestFormat,
      version: kMarketplaceManifestVersion,
    );
    final name = map['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const MarketplaceFetchException(
        'manifest name must be a non-empty string',
      );
    }
    final description = map['description'];
    final rawPacks = map['packs'];
    if (rawPacks is! List) {
      throw const MarketplaceFetchException('manifest packs must be a list');
    }
    final packs = <MarketplacePackRef>[
      for (var i = 0; i < rawPacks.length; i++) _decodePackRef(i, rawPacks[i]),
    ];
    return MarketplaceManifest(
      name: name.trim(),
      description: description is String ? description : '',
      packs: packs,
    );
  }

  MarketplacePackRef _decodePackRef(int index, dynamic raw) {
    final prefix = 'packs[$index]';
    if (raw is! Map) {
      throw MarketplaceFetchException('$prefix must be an object');
    }
    final id = raw['id'];
    final title = raw['title'];
    final description = raw['description'];
    final url = raw['url'];
    if (id is! String || !isValidUuid(id)) {
      throw MarketplaceFetchException('$prefix: id must be a valid UUID');
    }
    if (title is! String || title.trim().isEmpty) {
      throw MarketplaceFetchException(
        '$prefix: title must be a non-empty string',
      );
    }
    if (url is! String || url.isEmpty) {
      throw MarketplaceFetchException(
        '$prefix: url must be a non-empty string',
      );
    }
    _checkRelativeUrl(url, prefix: prefix);
    return MarketplacePackRef(
      id: id,
      title: title.trim(),
      description: description is String ? description : '',
      url: url,
    );
  }

  /// Fetches + validates the pack listing reachable from [manifestUrl] (the
  /// document [relativeUrl] was read from) via the pack's relative `url`.
  Future<MarketplacePackListing> fetchPack(
    Uri manifestUrl,
    String relativeUrl,
  ) async {
    final packUrl = _resolveRelative(
      manifestUrl,
      relativeUrl,
      prefix: 'pack url',
    );
    final map = await _fetchJsonObject(packUrl);
    _checkEnvelope(
      map,
      format: kMarketplacePackFormat,
      version: kMarketplacePackVersion,
    );
    final id = map['id'];
    final title = map['title'];
    final description = map['description'];
    final rawSets = map['sets'];
    // Pack listing `id` is required (not optional like the Set/item ids) —
    // this document type is new in #101, so there's no legacy-file
    // backward-compatibility concern.
    if (id is! String || !isValidUuid(id)) {
      throw const MarketplaceFetchException('pack id must be a valid UUID');
    }
    if (title is! String || title.trim().isEmpty) {
      throw const MarketplaceFetchException(
        'pack title must be a non-empty string',
      );
    }
    if (rawSets is! List) {
      throw const MarketplaceFetchException('pack sets must be a list');
    }
    final sets = <MarketplaceSetRef>[
      for (var i = 0; i < rawSets.length; i++) _decodeSetRef(i, rawSets[i]),
    ];
    return MarketplacePackListing(
      id: id,
      title: title.trim(),
      description: description is String ? description : '',
      sets: sets,
    );
  }

  MarketplaceSetRef _decodeSetRef(int index, dynamic raw) {
    final prefix = 'sets[$index]';
    if (raw is! Map) {
      throw MarketplaceFetchException('$prefix must be an object');
    }
    final id = raw['id'];
    final title = raw['title'];
    final description = raw['description'];
    final rawCategory = raw['category'];
    final itemCount = raw['itemCount'];
    final updatedAt = raw['updatedAt'];
    final url = raw['url'];
    if (id is! String || !isValidUuid(id)) {
      throw MarketplaceFetchException('$prefix: id must be a valid UUID');
    }
    if (title is! String || title.trim().isEmpty) {
      throw MarketplaceFetchException(
        '$prefix: title must be a non-empty string',
      );
    }
    if (rawCategory != null &&
        (rawCategory is! String || !kSetCategories.contains(rawCategory))) {
      throw MarketplaceFetchException(
        '$prefix: unknown category "$rawCategory"',
      );
    }
    if (itemCount is! int) {
      throw MarketplaceFetchException('$prefix: itemCount must be a number');
    }
    if (updatedAt is! String || updatedAt.isEmpty) {
      throw MarketplaceFetchException(
        '$prefix: updatedAt must be a non-empty string',
      );
    }
    if (url is! String || url.isEmpty) {
      throw MarketplaceFetchException(
        '$prefix: url must be a non-empty string',
      );
    }
    _checkRelativeUrl(url, prefix: prefix);
    return MarketplaceSetRef(
      id: id,
      title: title.trim(),
      description: description is String ? description : '',
      category: effectiveSetCategory(rawCategory as String?),
      itemCount: itemCount,
      updatedAt: updatedAt,
      url: url,
    );
  }

  /// Fetches the Set JSON itself as a raw map — reuses
  /// `decodeSetFromJson`/`importSetFromJson`'s existing v1 validation
  /// (#002/#094/#101) rather than duplicating it here. [packUrl] is the
  /// document [relativeUrl] was read from (the pack listing).
  Future<Map<String, dynamic>> fetchSetJson(
    Uri packUrl,
    String relativeUrl,
  ) async {
    final setUrl = _resolveRelative(packUrl, relativeUrl, prefix: 'set url');
    return _fetchJsonObject(setUrl);
  }

  Uri _resolveRelative(Uri from, String relative, {required String prefix}) {
    _checkRelativeUrl(relative, prefix: prefix);
    return from.resolveUri(Uri.parse(relative));
  }

  /// Rejects an absolute (has a scheme) or protocol-relative (`//...`) url
  /// — the only URLs ever followed are ones relative to the document they
  /// were read from, keeping every fetch on the manifest's own origin.
  void _checkRelativeUrl(String raw, {required String prefix}) {
    if (raw.startsWith('//')) {
      throw MarketplaceFetchException(
        '$prefix must be relative, not protocol-relative: "$raw"',
      );
    }
    final parsed = Uri.tryParse(raw);
    if (parsed == null) {
      throw MarketplaceFetchException('$prefix is not a valid URL: "$raw"');
    }
    if (parsed.hasScheme) {
      throw MarketplaceFetchException(
        '$prefix must be relative, not absolute: "$raw"',
      );
    }
  }

  Future<Map<String, dynamic>> _fetchJsonObject(Uri url) async {
    http.Response response;
    try {
      response = await _client.get(url);
    } catch (e) {
      throw MarketplaceFetchException('could not reach $url: $e');
    }
    if (response.statusCode != 200) {
      throw MarketplaceFetchException(
        '$url returned HTTP ${response.statusCode}',
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e) {
      throw MarketplaceFetchException('$url is not valid JSON: $e');
    }
    if (decoded is! Map) {
      throw MarketplaceFetchException('$url is not a JSON object');
    }
    // `jsonDecode` always gives JSON objects String keys, so this is a
    // cheap type-cast, not a copy.
    return decoded.cast<String, dynamic>();
  }

  void _checkEnvelope(
    Map<String, dynamic> map, {
    required String format,
    required int version,
  }) {
    final actualFormat = map['format'];
    if (actualFormat != format) {
      throw MarketplaceFetchException(
        'unknown format "$actualFormat" (expected "$format")',
      );
    }
    final actualVersion = map['version'];
    if (actualVersion != version) {
      throw MarketplaceFetchException(
        'unsupported version "$actualVersion" (expected $version)',
      );
    }
  }
}
