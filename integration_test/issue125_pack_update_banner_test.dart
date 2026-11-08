// Startup pack-update check + Home banner (issue #125).
//
// Boots the real app with a downloaded pack whose upstream set changed since
// the download: Home shows the blue "New content" banner, "Update" updates
// the pack in place, the banner confirms and disappears, and the Library
// shows the new content. `httpClientProvider` is a `MockClient` — no real
// network access.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/main.dart';
import 'package:fox_streak_app/src/data/marketplace_repository.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/marketplace/marketplace_providers.dart';

import 'helpers.dart';

const _source = 'https://marketplace.example/marketplace.json';
const _packId = 'c56a4180-65aa-42ec-a945-5fd21dec0538';
const _setId = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';

Map<String, dynamic> _setJson(String title) => {
  'format': 'foxstreak-set',
  'version': 1,
  'id': _setId,
  'title': title,
  'description': '',
  'createdBy': 'Jane',
  'category': 'vocab',
  'items': [
    {
      'type': 'phone',
      'prompt': 'Mama',
      'answer': '999',
      'id': 'a1b2c3d4-0000-4000-8000-000000000001',
    },
  ],
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home offers the pack update, applies it and confirms', (
    tester,
  ) async {
    final client = MockClient((http.Request request) async {
      final path = request.url.path;
      if (path.endsWith('marketplace.json')) {
        return http.Response(
          jsonEncode({
            'format': 'foxstreak-marketplace',
            'version': 1,
            'name': 'Jane',
            'description': '',
            'packs': [
              {
                'id': _packId,
                'title': 'Animals pack',
                'description': '',
                'url': 'packs/animals.json',
              },
            ],
          }),
          200,
        );
      }
      if (path.endsWith('packs/animals.json')) {
        return http.Response(
          jsonEncode({
            'format': 'foxstreak-pack',
            'version': 1,
            'id': _packId,
            'title': 'Animals pack',
            'description': '',
            'sets': [
              {
                'id': _setId,
                'title': 'Animals v2',
                'description': '',
                'category': 'vocab',
                'itemCount': 1,
                'updatedAt': '2026-11-01',
                'url': 'sets/animals.json',
              },
            ],
          }),
          200,
        );
      }
      if (path.endsWith('sets/animals.json')) {
        return http.Response(jsonEncode(_setJson('Animals v2')), 200);
      }
      return http.Response('not found', 404);
    });

    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 11, 8, 9));
    await StatsRepository(db, clock).setOnboarded();
    await MarketplaceRepository(db, SetsRepository(db, clock)).downloadPack(
      sourceUrl: _source,
      packId: _packId,
      title: 'Animals pack',
      description: '',
      sets: [
        FetchedMarketplaceSet(
          setId: _setId,
          listingUpdatedAt: '2026-10-01',
          json: _setJson('Animals v1'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          systemClockProvider.overrideWithValue(clock),
          integrationTestSilentSound,
          httpClientProvider.overrideWithValue(client),
        ],
        child: const FoxStreakApp(),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('packUpdateBanner')), findsOneWidget);
    expect(find.text('New content in Animals pack'), findsOneWidget);

    await tester.tap(find.byKey(const Key('foxFeedbackBannerAction')));
    await settle(tester);
    expect(find.text('Packs updated'), findsOneWidget);

    // The confirmation goes away on its own.
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    expect(find.byKey(const Key('packUpdateBanner')), findsNothing);

    // The Library shows the new content.
    await tester.tap(find.byKey(const Key('homeBrowseSetsButton')));
    await settle(tester);
    expect(find.text('Animals v2'), findsOneWidget);
  });
}
