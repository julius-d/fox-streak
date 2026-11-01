// Widget tests for MarketplaceSourcesScreen (issue #101): empty state,
// adding a source (happy path, duplicate, fetch failure), and removing a
// source via the confirm dialog. No real network access —
// `httpClientProvider` is overridden with a `MockClient`.
//
// NOTE on pumping: do NOT use `pumpAndSettle()` here — same drift
// `watch()`-under-fake-async caveat as `library_screen_test.dart`'s own
// `settle()` (this screen watches `marketplaceSourcesProvider`).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/marketplace/marketplace_providers.dart';
import 'package:fox_streak_app/src/marketplace/marketplace_sources_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _validManifest = '''
{
  "format": "foxstreak-marketplace",
  "version": 1,
  "name": "Jane's Packs",
  "description": "Language packs",
  "packs": []
}
''';

/// Pumps frames until none are scheduled (or [cap] is hit, which fails).
Future<void> settle(WidgetTester tester, {int cap = 50}) async {
  for (var i = 0; i < cap; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) return;
  }
  fail('UI did not settle after $cap frames');
}

/// Unmounts the tree and flushes drift's stream-close timer so the
/// fake-async invariant check passes (see note above).
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Pumps `MarketplaceSourcesScreen` with an in-memory DB + mocked HTTP
/// client that returns [manifestResponse] for any `marketplace.json`
/// fetch (status [manifestStatus]).
Future<AppDatabase> pumpSourcesScreen(
  WidgetTester tester, {
  String manifestResponse = _validManifest,
  int manifestStatus = 200,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        httpClientProvider.overrideWithValue(
          MockClient(
            (_) async => http.Response(manifestResponse, manifestStatus),
          ),
        ),
      ],
      child: MaterialApp(
        theme: FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MarketplaceSourcesScreen(),
      ),
    ),
  );
  await settle(tester);
  return db;
}

void main() {
  testWidgets('shows the empty state with an add-a-marketplace CTA', (
    tester,
  ) async {
    await pumpSourcesScreen(tester);
    expect(
      find.byKey(const Key('marketplaceSourcesEmptyTitle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('marketplaceSourcesEmptyCta')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'adding a valid marketplace URL fetches + validates the manifest and '
    'lists it by its manifest name',
    (tester) async {
      await pumpSourcesScreen(tester);

      await tester.tap(find.byKey(const Key('addMarketplaceSourceFab')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('marketplaceSourceUrlField')),
        'https://example.github.io/my-marketplace',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('confirmAddMarketplaceSourceButton')),
      );
      await settle(tester);

      expect(find.text("Jane's Packs"), findsOneWidget);
      expect(
        find.text('https://example.github.io/my-marketplace/marketplace.json'),
        findsOneWidget,
      );
      await unmount(tester);
    },
  );

  testWidgets('adding the same URL twice shows a duplicate error', (
    tester,
  ) async {
    await pumpSourcesScreen(tester);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const Key('addMarketplaceSourceFab')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('marketplaceSourceUrlField')),
        'https://example.github.io/marketplace.json',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('confirmAddMarketplaceSourceButton')),
      );
      await settle(tester);
    }

    expect(find.text('This marketplace was already added.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a broken source (404) shows an add-source error, not a crash', (
    tester,
  ) async {
    await pumpSourcesScreen(
      tester,
      manifestResponse: 'not found',
      manifestStatus: 404,
    );

    await tester.tap(find.byKey(const Key('addMarketplaceSourceFab')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('marketplaceSourceUrlField')),
      'https://example.github.io/marketplace.json',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('confirmAddMarketplaceSourceButton')),
    );
    await settle(tester);

    expect(
      find.text('Could not add this marketplace. Check the URL and try again.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('marketplaceSourcesEmptyTitle')),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets(
    'removing a source via the confirm dialog deletes it; cancel keeps it',
    (tester) async {
      await pumpSourcesScreen(tester);
      await tester.tap(find.byKey(const Key('addMarketplaceSourceFab')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('marketplaceSourceUrlField')),
        'https://example.github.io/marketplace.json',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('confirmAddMarketplaceSourceButton')),
      );
      await settle(tester);
      expect(find.text("Jane's Packs"), findsOneWidget);

      // Cancel leaves it in place.
      await tester.tap(find.byKey(const Key('removeMarketplaceSource-1')));
      await settle(tester);
      await tester.tap(
        find.byKey(const Key('cancelRemoveMarketplaceSource-1')),
      );
      await settle(tester);
      expect(find.text("Jane's Packs"), findsOneWidget);

      // Confirm removes it.
      await tester.tap(find.byKey(const Key('removeMarketplaceSource-1')));
      await settle(tester);
      await tester.tap(
        find.byKey(const Key('confirmRemoveMarketplaceSource-1')),
      );
      await settle(tester);
      expect(find.text("Jane's Packs"), findsNothing);
      expect(
        find.byKey(const Key('marketplaceSourcesEmptyTitle')),
        findsOneWidget,
      );
      await unmount(tester);
    },
  );
}
