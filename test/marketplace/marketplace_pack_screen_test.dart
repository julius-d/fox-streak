// Widget tests for the Marketplace pack screen (issue #121): read-only set
// preview, "Download pack" / "Update pack" / "Pack is up to date" states,
// progress, all-or-nothing failure with retry, and the locally-edited-sets
// summary dialog. No real network — `httpClientProvider` is a `MockClient`.
//
// NOTE on pumping: no `pumpAndSettle()` (drift `watch()` under fake async).

import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/marketplace/marketplace_client.dart';
import 'package:fox_streak_app/src/marketplace/marketplace_providers.dart';
import 'package:fox_streak_app/src/marketplace/marketplace_sets_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../data/test_helpers.dart';

const _source = 'https://m.example/marketplace.json';
const _packUuid = 'c56a4180-65aa-42ec-a945-5fd21dec0538';
const _dogsUuid = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';
const _catsUuid = '3f2504e0-4f89-41d3-9a0c-0305e82c3302';
const _birdsUuid = '3f2504e0-4f89-41d3-9a0c-0305e82c3303';

/// A mutable fake marketplace: one pack with a changeable set list.
class FakeMarketplace {
  String packTitle = 'Animals pack';
  // set uuid -> (title, updatedAt)
  final Map<String, (String, String)> sets = {
    _dogsUuid: ('Dogs', '2026-10-01'),
    _catsUuid: ('Cats', '2026-10-01'),
  };
  final Set<String> failingSets = {};
  Completer<void>? gate;
  final List<String> requested = [];

  String _slug(String uuid) => 'set-$uuid';

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    requested.add(path);
    if (path.endsWith('packs/animals.json')) {
      return http.Response(
        jsonEncode({
          'format': 'foxstreak-pack',
          'version': 1,
          'id': _packUuid,
          'title': packTitle,
          'description': 'All the animals',
          'sets': [
            for (final e in sets.entries)
              {
                'id': e.key,
                'title': e.value.$1,
                'description': 'About ${e.value.$1}',
                'category': 'vocab',
                'itemCount': 1,
                'updatedAt': e.value.$2,
                'url': 'sets/${_slug(e.key)}.json',
              },
          ],
        }),
        200,
      );
    }
    for (final e in sets.entries) {
      if (path.endsWith('sets/${_slug(e.key)}.json')) {
        if (gate != null) await gate!.future;
        if (failingSets.contains(e.key)) return http.Response('boom', 500);
        return http.Response(
          jsonEncode({
            'format': 'foxstreak-set',
            'version': 1,
            'id': e.key,
            'title': e.value.$1,
            'description': 'About ${e.value.$1}',
            'createdBy': 'Jane',
            'category': 'vocab',
            'items': [
              {
                'type': 'phone',
                'prompt': 'Mama',
                'answer': '111',
                'id': 'a1b2c3d4-0000-4000-8000-${e.key.substring(24)}',
              },
            ],
          }),
          200,
        );
      }
    }
    return http.Response('not found', 404);
  }
}

Future<void> settle(WidgetTester tester, {int cap = 50}) async {
  for (var i = 0; i < cap; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) return;
  }
  fail('UI did not settle after $cap frames');
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void testPackScreen(
  String description,
  Future<void> Function(WidgetTester, AppDatabase, FakeMarketplace) body,
) {
  testWidgets(description, (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    final fake = FakeMarketplace();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          systemClockProvider.overrideWithValue(FakeClock(kTestToday)),
          httpClientProvider.overrideWithValue(MockClient(fake.handle)),
        ],
        child: MaterialApp(
          theme: FoxStreakTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MarketplaceSetsScreen(
            sourceUrl: _source,
            manifestUrl: Uri.parse(_source),
            pack: const MarketplacePackRef(
              id: _packUuid,
              title: 'Animals pack',
              description: 'All the animals',
              url: 'packs/animals.json',
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await body(tester, db, fake);
    await unmount(tester);
  });
}

final _primary = find.byKey(const Key('marketplacePrimaryActionButton'));

Future<List<QuestionSet>> _downloadedSets(AppDatabase db) async {
  final pack = (await db.select(db.packs).get()).where(
    (p) => p.sourceUrl != null,
  );
  if (pack.isEmpty) return [];
  return (await db.select(db.questionSets).get())
      .where((s) => s.packId == pack.single.id)
      .toList();
}

void main() {
  testPackScreen('offers the whole pack for download with a read-only set '
      'preview and no per-set import', (tester, db, fake) async {
    expect(find.text('Download pack'), findsOneWidget);
    expect(find.text('Dogs'), findsOneWidget);
    expect(find.text('Cats'), findsOneWidget);
    expect(find.text('Sets in this pack'), findsOneWidget);

    await tester.tap(find.text('Dogs'));
    await settle(tester);
    expect(
      find.byKey(const Key('marketplaceSetPreviewScreen')),
      findsOneWidget,
    );
    expect(find.text('Created by Jane'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    expect(_primary, findsNothing);
    expect(find.text('Add to Library'), findsNothing);
    expect(await db.select(db.importedMarketplaceSets).get(), isEmpty);
  });

  testPackScreen('download creates the local pack with all sets and then '
      'shows "up to date"', (tester, db, fake) async {
    await tester.tap(_primary);
    await settle(tester);

    expect(find.text('Pack added to your Library.'), findsOneWidget);
    final pack = (await db.select(db.packs).get()).singleWhere(
      (p) => p.sourceUrl != null,
    );
    expect(pack.title, 'Animals pack');
    expect(pack.description, 'All the animals');
    expect(pack.sourcePackId, _packUuid);
    expect((await _downloadedSets(db)).map((s) => s.title), ['Dogs', 'Cats']);

    expect(find.text('Pack is up to date'), findsOneWidget);
    final button = tester.widget<FoxPrimaryButton>(_primary);
    expect(button.onPressed, isNull);
  });

  testPackScreen('shows progress while downloading', (tester, db, fake) async {
    fake.gate = Completer<void>();
    await tester.tap(_primary);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Downloading set 0 of 2…'), findsOneWidget);
    expect(
      find.byKey(const Key('marketplaceDownloadProgress')),
      findsOneWidget,
    );

    fake.gate!.complete();
    await settle(tester);
    expect(find.text('Downloading set 0 of 2…'), findsNothing);
    expect(await _downloadedSets(db), hasLength(2));
  });

  testPackScreen('a failing set leaves nothing behind, tells the learner and '
      'allows retry', (tester, db, fake) async {
    fake.failingSets.add(_catsUuid);
    await tester.tap(_primary);
    await settle(tester);

    expect(find.byKey(const Key('marketplaceDownloadError')), findsOneWidget);
    expect(
      find.textContaining('Download failed — nothing was saved'),
      findsOneWidget,
    );
    expect(await db.select(db.packs).get(), hasLength(1)); // only "My sets"
    expect(await _downloadedSets(db), isEmpty);
    expect(await db.select(db.importedMarketplaceSets).get(), isEmpty);
    // Still offers the download.
    expect(find.text('Download pack'), findsOneWidget);

    fake.failingSets.clear();
    await tester.tap(_primary);
    await settle(tester);
    expect(find.byKey(const Key('marketplaceDownloadError')), findsNothing);
    expect(await _downloadedSets(db), hasLength(2));
  });

  group('update', () {
    Future<void> downloadFirst(WidgetTester tester) async {
      await tester.tap(_primary);
      await settle(tester);
    }

    Future<void> reopen(WidgetTester tester, AppDatabase db) async {
      // The screen fetches once per instance; rebuild it to see new state.
      final screen = tester.widget<MarketplaceSetsScreen>(
        find.byType(MarketplaceSetsScreen),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            systemClockProvider.overrideWithValue(FakeClock(kTestToday)),
            httpClientProvider.overrideWithValue(MockClient(_current!.handle)),
          ],
          child: MaterialApp(
            theme: FoxStreakTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: screen,
          ),
        ),
      );
      await settle(tester);
    }

    testPackScreen('updates changed sets, adds new ones and keeps sets '
        'removed upstream', (tester, db, fake) async {
      _current = fake;
      await downloadFirst(tester);

      fake.packTitle = 'Animals v2';
      fake.sets
        ..[_dogsUuid] = ('Dogs v2', '2026-11-01')
        ..remove(_catsUuid)
        ..[_birdsUuid] = ('Birds', '2026-11-01');
      await reopen(tester, db);
      expect(find.text('Update pack'), findsOneWidget);

      await tester.tap(_primary);
      await settle(tester);

      expect(find.text('Pack updated.'), findsOneWidget);
      expect((await _downloadedSets(db)).map((s) => s.title), [
        'Dogs v2',
        'Cats', // removed upstream, kept locally
        'Birds',
      ]);
      final pack = (await db.select(db.packs).get()).singleWhere(
        (p) => p.sourceUrl != null,
      );
      expect(pack.title, 'Animals v2');
      expect(find.text('Pack is up to date'), findsOneWidget);
      // Only one local pack for this Marketplace pack, ever.
      expect(
        (await db.select(db.packs).get()).where((p) => p.sourceUrl != null),
        hasLength(1),
      );
    });

    testPackScreen('one summary lists locally edited sets; skipping leaves '
        'them untouched, other sets still update', (tester, db, fake) async {
      _current = fake;
      await downloadFirst(tester);
      final dogs = (await _downloadedSets(db))
          .firstWhere((s) => s.title == 'Dogs');
      final clock = FakeClock(kTestToday.add(const Duration(hours: 2)));
      await SetsRepository(db, clock).updateSet(id: dogs.id, title: 'My dogs');

      fake.sets
        ..[_dogsUuid] = ('Dogs v2', '2026-11-01')
        ..[_catsUuid] = ('Cats v2', '2026-11-01');
      await reopen(tester, db);

      await tester.tap(_primary);
      await settle(tester);

      expect(find.text('Overwrite your local edits?'), findsOneWidget);
      expect(find.textContaining('• My dogs'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Cats'),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('skipOverwriteLocalEditsButton')));
      await settle(tester);

      expect((await _downloadedSets(db)).map((s) => s.title), [
        'My dogs',
        'Cats v2',
      ]);
      // The skipped set is still outdated.
      expect(find.text('Update pack'), findsOneWidget);
    });

    testPackScreen('confirming the overwrite replaces the edited sets', (
      tester,
      db,
      fake,
    ) async {
      _current = fake;
      await downloadFirst(tester);
      final dogs = (await _downloadedSets(db))
          .firstWhere((s) => s.title == 'Dogs');
      final clock = FakeClock(kTestToday.add(const Duration(hours: 2)));
      await SetsRepository(db, clock).updateSet(id: dogs.id, title: 'My dogs');
      fake.sets[_dogsUuid] = ('Dogs v2', '2026-11-01');
      await reopen(tester, db);

      await tester.tap(_primary);
      await settle(tester);
      await tester.tap(
        find.byKey(const Key('confirmOverwriteLocalEditsButton')),
      );
      await settle(tester);

      expect((await _downloadedSets(db)).map((s) => s.title), [
        'Dogs v2',
        'Cats',
      ]);
      expect(find.text('Pack is up to date'), findsOneWidget);
    });

    testPackScreen('a failed update leaves the downloaded sets intact', (
      tester,
      db,
      fake,
    ) async {
      _current = fake;
      await downloadFirst(tester);
      fake.sets
        ..[_dogsUuid] = ('Dogs v2', '2026-11-01')
        ..[_catsUuid] = ('Cats v2', '2026-11-01');
      fake.failingSets.add(_catsUuid);
      await reopen(tester, db);

      await tester.tap(_primary);
      await settle(tester);

      expect(find.byKey(const Key('marketplaceDownloadError')), findsOneWidget);
      expect((await _downloadedSets(db)).map((s) => s.title), ['Dogs', 'Cats']);
    });
  });
}

/// The fake behind the currently running test (for [reopen]).
FakeMarketplace? _current;
