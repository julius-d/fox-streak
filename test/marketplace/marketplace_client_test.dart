// Tests for MarketplaceClient (issue #101): the URL-shorthand resolution
// rule, the manifest/pack-listing fetch + validation, and in particular
// the relative-only `url` security rule — the whole point of this file is
// proving an absolute or protocol-relative `url` is never followed.

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/marketplace/marketplace_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('resolveManifestUrl', () {
    late MarketplaceClient client;
    setUp(() {
      client = MarketplaceClient(
        MockClient((_) async => http.Response('', 404)),
      );
    });

    test('a .json-ending URL is used as-is', () {
      final uri = client.resolveManifestUrl(
        'https://example.github.io/my-marketplace/marketplace.json',
      );
      expect(
        uri.toString(),
        'https://example.github.io/my-marketplace/marketplace.json',
      );
    });

    test('a bare base URL without a trailing slash appends '
        '/marketplace.json', () {
      final uri = client.resolveManifestUrl(
        'https://example.github.io/my-marketplace',
      );
      expect(
        uri.toString(),
        'https://example.github.io/my-marketplace/marketplace.json',
      );
    });

    test('a bare base URL with a trailing slash does not double the '
        'slash', () {
      final uri = client.resolveManifestUrl(
        'https://example.github.io/my-marketplace/',
      );
      expect(
        uri.toString(),
        'https://example.github.io/my-marketplace/marketplace.json',
      );
    });

    test('trims whitespace before resolving', () {
      final uri = client.resolveManifestUrl(
        '  https://example.github.io/marketplace.json  ',
      );
      expect(uri.toString(), 'https://example.github.io/marketplace.json');
    });

    test('rejects an input with no scheme/host', () {
      expect(
        () => client.resolveManifestUrl('not a url'),
        throwsA(isA<MarketplaceFetchException>()),
      );
      expect(
        () => client.resolveManifestUrl(''),
        throwsA(isA<MarketplaceFetchException>()),
      );
    });
  });

  group('fetchManifest', () {
    test('parses a valid manifest', () async {
      final client = MarketplaceClient(
        MockClient(
          (request) async => http.Response('''
            {
              "format": "foxstreak-marketplace",
              "version": 1,
              "name": "Jane's Packs",
              "description": "Language packs",
              "packs": [
                {
                  "id": "c56a4180-65aa-42ec-a945-5fd21dec0538",
                  "title": "English for Germans",
                  "description": "Vocab",
                  "url": "packs/english.json"
                }
              ]
            }
            ''', 200),
        ),
      );
      final manifest = await client.fetchManifest(
        Uri.parse('https://example.github.io/marketplace.json'),
      );
      expect(manifest.name, "Jane's Packs");
      expect(manifest.packs, hasLength(1));
      expect(manifest.packs.single.id, 'c56a4180-65aa-42ec-a945-5fd21dec0538');
      expect(manifest.packs.single.title, 'English for Germans');
      expect(manifest.packs.single.url, 'packs/english.json');
    });

    test('a non-200 response is a fetch error', () async {
      final client = MarketplaceClient(
        MockClient((_) async => http.Response('not found', 404)),
      );
      expect(
        () => client.fetchManifest(Uri.parse('https://e.example/m.json')),
        throwsA(isA<MarketplaceFetchException>()),
      );
    });

    test('invalid JSON is a fetch error', () async {
      final client = MarketplaceClient(
        MockClient((_) async => http.Response('not json', 200)),
      );
      expect(
        () => client.fetchManifest(Uri.parse('https://e.example/m.json')),
        throwsA(isA<MarketplaceFetchException>()),
      );
    });

    test('a non-object JSON body is a fetch error', () async {
      final client = MarketplaceClient(
        MockClient((_) async => http.Response('[1,2,3]', 200)),
      );
      expect(
        () => client.fetchManifest(Uri.parse('https://e.example/m.json')),
        throwsA(isA<MarketplaceFetchException>()),
      );
    });

    test('an unexpected format/version envelope is a fetch error', () async {
      final wrongFormat = MarketplaceClient(
        MockClient(
          (_) async => http.Response(
            '{"format": "something-else", "version": 1, "name": "x", "packs": []}',
            200,
          ),
        ),
      );
      expect(
        () => wrongFormat.fetchManifest(Uri.parse('https://e.example/m.json')),
        throwsA(isA<MarketplaceFetchException>()),
      );

      final wrongVersion = MarketplaceClient(
        MockClient(
          (_) async => http.Response(
            '{"format": "foxstreak-marketplace", "version": 2, "name": "x", "packs": []}',
            200,
          ),
        ),
      );
      expect(
        () => wrongVersion.fetchManifest(Uri.parse('https://e.example/m.json')),
        throwsA(isA<MarketplaceFetchException>()),
      );
    });

    test('a pack with an absolute url is rejected (security)', () async {
      final client = MarketplaceClient(
        MockClient(
          (_) async => http.Response('''
            {
              "format": "foxstreak-marketplace",
              "version": 1,
              "name": "x",
              "packs": [
                {
                  "id": "c56a4180-65aa-42ec-a945-5fd21dec0538",
                  "title": "T",
                  "url": "https://evil.example/packs/x.json"
                }
              ]
            }
            ''', 200),
        ),
      );
      expect(
        () => client.fetchManifest(Uri.parse('https://e.example/m.json')),
        throwsA(isA<MarketplaceFetchException>()),
      );
    });

    test(
      'a pack with a protocol-relative url is rejected (security)',
      () async {
        final client = MarketplaceClient(
          MockClient(
            (_) async => http.Response('''
            {
              "format": "foxstreak-marketplace",
              "version": 1,
              "name": "x",
              "packs": [
                {
                  "id": "c56a4180-65aa-42ec-a945-5fd21dec0538",
                  "title": "T",
                  "url": "//evil.example/packs/x.json"
                }
              ]
            }
            ''', 200),
          ),
        );
        expect(
          () => client.fetchManifest(Uri.parse('https://e.example/m.json')),
          throwsA(isA<MarketplaceFetchException>()),
        );
      },
    );

    test('a pack with a non-UUID id is rejected', () async {
      final client = MarketplaceClient(
        MockClient(
          (_) async => http.Response('''
            {
              "format": "foxstreak-marketplace",
              "version": 1,
              "name": "x",
              "packs": [
                {"id": "not-a-uuid", "title": "T", "url": "p.json"}
              ]
            }
            ''', 200),
        ),
      );
      expect(
        () => client.fetchManifest(Uri.parse('https://e.example/m.json')),
        throwsA(isA<MarketplaceFetchException>()),
      );
    });
  });

  group('fetchPack', () {
    test('parses a valid pack listing, resolving its url relative to the '
        'manifest', () async {
      Uri? requestedUri;
      final client = MarketplaceClient(
        MockClient((request) async {
          requestedUri = request.url;
          return http.Response('''
            {
              "format": "foxstreak-pack",
              "version": 1,
              "id": "c56a4180-65aa-42ec-a945-5fd21dec0538",
              "title": "English for Germans",
              "sets": [
                {
                  "id": "3f2504e0-4f89-41d3-9a0c-0305e82c3301",
                  "title": "Animals",
                  "description": "Basic animals",
                  "category": "vocab",
                  "itemCount": 12,
                  "updatedAt": "2026-10-01",
                  "url": "sets/animals.foxstreak.json"
                }
              ]
            }
            ''', 200);
        }),
      );
      final manifestUrl = Uri.parse(
        'https://example.github.io/my-marketplace/marketplace.json',
      );
      final listing = await client.fetchPack(manifestUrl, 'packs/english.json');
      expect(
        requestedUri.toString(),
        'https://example.github.io/my-marketplace/packs/english.json',
      );
      expect(listing.id, 'c56a4180-65aa-42ec-a945-5fd21dec0538');
      expect(listing.sets, hasLength(1));
      expect(listing.sets.single.title, 'Animals');
      expect(listing.sets.single.category, 'vocab');
      expect(listing.sets.single.itemCount, 12);
      expect(listing.sets.single.updatedAt, '2026-10-01');
    });

    test('a missing pack id is rejected (required, unlike the Set/item '
        'ids)', () async {
      final client = MarketplaceClient(
        MockClient(
          (_) async => http.Response(
            '{"format": "foxstreak-pack", "version": 1, "title": "T", "sets": []}',
            200,
          ),
        ),
      );
      expect(
        () => client.fetchPack(Uri.parse('https://e.example/m.json'), 'p.json'),
        throwsA(isA<MarketplaceFetchException>()),
      );
    });

    test('a set ref missing category defaults to vocab', () async {
      final client = MarketplaceClient(
        MockClient(
          (_) async => http.Response('''
            {
              "format": "foxstreak-pack",
              "version": 1,
              "id": "c56a4180-65aa-42ec-a945-5fd21dec0538",
              "title": "T",
              "sets": [
                {
                  "id": "3f2504e0-4f89-41d3-9a0c-0305e82c3301",
                  "title": "Animals",
                  "itemCount": 5,
                  "updatedAt": "2026-10-01",
                  "url": "a.json"
                }
              ]
            }
            ''', 200),
        ),
      );
      final listing = await client.fetchPack(
        Uri.parse('https://e.example/m.json'),
        'p.json',
      );
      expect(listing.sets.single.category, 'vocab');
    });

    test('a set ref with an absolute url is rejected (security)', () async {
      final client = MarketplaceClient(
        MockClient(
          (_) async => http.Response('''
            {
              "format": "foxstreak-pack",
              "version": 1,
              "id": "c56a4180-65aa-42ec-a945-5fd21dec0538",
              "title": "T",
              "sets": [
                {
                  "id": "3f2504e0-4f89-41d3-9a0c-0305e82c3301",
                  "title": "Animals",
                  "itemCount": 5,
                  "updatedAt": "2026-10-01",
                  "url": "https://evil.example/a.json"
                }
              ]
            }
            ''', 200),
        ),
      );
      expect(
        () => client.fetchPack(Uri.parse('https://e.example/m.json'), 'p.json'),
        throwsA(isA<MarketplaceFetchException>()),
      );
    });

    test(
      'a non-relative pack url is rejected before any fetch happens',
      () async {
        final client = MarketplaceClient(
          MockClient((_) async => http.Response('irrelevant', 200)),
        );
        expect(
          () => client.fetchPack(
            Uri.parse('https://e.example/m.json'),
            'https://evil.example/p.json',
          ),
          throwsA(isA<MarketplaceFetchException>()),
        );
      },
    );
  });

  group('fetchSetJson', () {
    test(
      'fetches the raw Set JSON, resolving its url relative to the pack',
      () async {
        Uri? requestedUri;
        final client = MarketplaceClient(
          MockClient((request) async {
            requestedUri = request.url;
            return http.Response(
              '{"format": "foxstreak-set", "version": 1, "title": "Animals", '
              '"createdBy": "Jane", "items": []}',
              200,
            );
          }),
        );
        final packUrl = Uri.parse(
          'https://example.github.io/my-marketplace/packs/english.json',
        );
        final json = await client.fetchSetJson(
          packUrl,
          'sets/animals.foxstreak.json',
        );
        expect(
          requestedUri.toString(),
          'https://example.github.io/my-marketplace/packs/sets/'
          'animals.foxstreak.json',
        );
        expect(json['title'], 'Animals');
      },
    );
  });
}
