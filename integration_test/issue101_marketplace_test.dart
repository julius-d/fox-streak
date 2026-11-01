// Marketplace browse/import/update flow (issue #101).
//
// Drives the real app through Library's `newSetFab` speed-dial's new
// "Marketplace" mini-FAB: add a source, browse Source -> Packs -> Sets ->
// Set preview, "Add to Library", then simulate the publisher changing the
// set and exercise "Update". `httpClientProvider` is overridden with a
// `MockClient` serving a tiny fake marketplace — no real network access.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/main.dart';
import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/marketplace/marketplace_providers.dart';

import 'helpers.dart';

/// Pumps the real `FoxStreakApp` with [db]/[clock] overridden, same as
/// `helpers.dart`'s `pumpFoxStreakApp`, plus `httpClientProvider` pointed
/// at [httpClient] (a `MockClient`) so this flow's marketplace fetches
/// never touch the real network.
Future<void> _pumpAppWithMarketplace(
  WidgetTester tester, {
  required AppDatabase db,
  required Clock clock,
  required http.Client httpClient,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
        integrationTestSilentSound,
        httpClientProvider.overrideWithValue(httpClient),
      ],
      child: const FoxStreakApp(),
    ),
  );
  await settle(tester);
}

const _manifestJson = '''
{
  "format": "foxstreak-marketplace",
  "version": 1,
  "name": "Jane's Packs",
  "description": "Language packs",
  "packs": [
    {
      "id": "c56a4180-65aa-42ec-a945-5fd21dec0538",
      "title": "English for Germans",
      "description": "Vocabulary packs",
      "url": "packs/english.json"
    }
  ]
}
''';

String _packJson({required String setUpdatedAt}) =>
    '''
{
  "format": "foxstreak-pack",
  "version": 1,
  "id": "c56a4180-65aa-42ec-a945-5fd21dec0538",
  "title": "English for Germans",
  "description": "Vocabulary packs",
  "sets": [
    {
      "id": "3f2504e0-4f89-41d3-9a0c-0305e82c3301",
      "title": "Animals",
      "description": "Basic animal vocabulary",
      "category": "vocab",
      "itemCount": 2,
      "updatedAt": "$setUpdatedAt",
      "url": "sets/animals.foxstreak.json"
    }
  ]
}
''';

const _setJsonV1 = '''
{
  "format": "foxstreak-set",
  "version": 1,
  "id": "3f2504e0-4f89-41d3-9a0c-0305e82c3301",
  "title": "Animals",
  "description": "Basic animal vocabulary",
  "createdBy": "Jane",
  "category": "vocab",
  "items": [
    {
      "type": "phone",
      "prompt": "Mama",
      "answer": "111",
      "id": "a1b2c3d4-0000-4000-8000-000000000001"
    },
    {
      "type": "phone",
      "prompt": "Papa",
      "answer": "222",
      "id": "a1b2c3d4-0000-4000-8000-000000000002"
    }
  ]
}
''';

const _setJsonV2 = '''
{
  "format": "foxstreak-set",
  "version": 1,
  "id": "3f2504e0-4f89-41d3-9a0c-0305e82c3301",
  "title": "Animals (updated)",
  "description": "Basic animal vocabulary",
  "createdBy": "Jane",
  "category": "vocab",
  "items": [
    {
      "type": "phone",
      "prompt": "Mama",
      "answer": "999",
      "id": "a1b2c3d4-0000-4000-8000-000000000001"
    },
    {
      "type": "phone",
      "prompt": "Oma",
      "answer": "333",
      "id": "a1b2c3d4-0000-4000-8000-000000000003"
    }
  ]
}
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final l10n = AppLocalizationsEn();

  testWidgets(
    'add a marketplace source, browse to a Set, add it to the Library, '
    'then update it once the publisher changes it',
    (tester) async {
      var publisherUpdated = false;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('marketplace.json')) {
          return http.Response(_manifestJson, 200);
        }
        if (path.endsWith('packs/english.json')) {
          return http.Response(
            _packJson(
              setUpdatedAt: publisherUpdated ? '2026-11-01' : '2026-10-01',
            ),
            200,
          );
        }
        if (path.endsWith('sets/animals.foxstreak.json')) {
          return http.Response(publisherUpdated ? _setJsonV2 : _setJsonV1, 200);
        }
        return http.Response('not found', 404);
      });

      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 14, 9));

      await _pumpAppWithMarketplace(
        tester,
        db: db,
        clock: clock,
        httpClient: client,
      );
      await skipOnboardingAndOpenLibrary(tester);

      // Open the Marketplace via the newSetFab speed-dial's third mini-FAB.
      await tester.tap(find.byKey(const Key('newSetFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('marketplaceFab')));
      await settle(tester);
      expect(find.byKey(const Key('marketplaceSourcesScreen')), findsOneWidget);

      // Add a source, typing the bare base URL (shorthand).
      await tester.tap(find.byKey(const Key('addMarketplaceSourceFab')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('marketplaceSourceUrlField')),
        'https://marketplace.example',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('confirmAddMarketplaceSourceButton')),
      );
      await settle(tester);
      expect(find.text("Jane's Packs"), findsOneWidget);

      // Source -> Packs -> Sets -> Set preview.
      await tester.tap(find.text("Jane's Packs"));
      await settle(tester);
      expect(find.text('English for Germans'), findsOneWidget);
      await tester.tap(find.text('English for Germans'));
      await settle(tester);
      expect(find.text('Animals'), findsOneWidget);
      await tester.tap(find.text('Animals'));
      await settle(tester);

      expect(
        find.byKey(const Key('marketplaceSetPreviewScreen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('marketplacePreviewDescription')),
        findsOneWidget,
      );
      expect(find.text('Created by Jane'), findsOneWidget);
      expect(find.text(l10n.setItemCount(2)), findsOneWidget);
      expect(find.text('Add to Library'), findsOneWidget);

      // Add to Library.
      await tester.tap(find.byKey(const Key('marketplacePrimaryActionButton')));
      await settle(tester);
      expect(find.text('Added to your Library.'), findsOneWidget);
      // The button's status refreshes without leaving the screen.
      await pumpUntilFound(tester, find.text('Already up to date'));

      // Back out to the Library: the imported set is there with its items.
      await tester.pageBack();
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      expect(listTileWithText('Animals'), findsOneWidget);
      await openSetDetail(tester, 'Animals');
      expect(listTileWithText('Mama'), findsOneWidget);
      expect(listTileWithText('Papa'), findsOneWidget);
      await tester.pageBack();
      await settle(tester);

      // The publisher changes the set; browse back to it via the
      // Marketplace and update.
      publisherUpdated = true;
      await tester.tap(find.byKey(const Key('newSetFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('marketplaceFab')));
      await settle(tester);
      await tester.tap(find.text("Jane's Packs"));
      await settle(tester);
      await tester.tap(find.text('English for Germans'));
      await settle(tester);
      await tester.tap(find.text('Animals'));
      await settle(tester);

      expect(find.text('Update'), findsOneWidget);
      await tester.tap(find.byKey(const Key('marketplacePrimaryActionButton')));
      await settle(tester);
      expect(find.text('Set updated.'), findsOneWidget);

      // Back out to the Library: the set's content reflects the update —
      // new title, and items matched/updated or replaced per their id.
      await tester.pageBack();
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      expect(listTileWithText('Animals (updated)'), findsOneWidget);
      await openSetDetail(tester, 'Animals (updated)');
      expect(listTileWithText('Mama'), findsOneWidget);
      expect(listTileWithText('Oma'), findsOneWidget);
      expect(listTileWithText('Papa'), findsNothing);
    },
  );
}
