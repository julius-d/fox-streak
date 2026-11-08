// Tests for the startup pack-update check and the Home banner (issue #125):
// check result states, banner visibility/precedence/dismiss, the update flow
// incl. overwrite dialog, partial failure retry and leaving Home mid-update.
// No real network — `httpClientProvider` is a `MockClient`.
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
import 'package:fox_streak_app/src/data/marketplace_repository.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/home/home_screen.dart';
import 'package:fox_streak_app/src/marketplace/marketplace_providers.dart';
import 'package:fox_streak_app/src/marketplace/pack_update_controller.dart';
import 'package:fox_streak_app/src/stats/streak_freeze_service.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../data/test_helpers.dart';

const _source = 'https://m.example/marketplace.json';
const _animalsUuid = 'c56a4180-65aa-42ec-a945-5fd21dec0538';
const _plantsUuid = 'c56a4180-65aa-42ec-a945-5fd21dec0539';
const _dogsUuid = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';
const _catsUuid = '3f2504e0-4f89-41d3-9a0c-0305e82c3302';
const _fernUuid = '3f2504e0-4f89-41d3-9a0c-0305e82c3303';

/// A mutable fake marketplace with two packs.
class FakeMarketplace {
  final Map<String, String> packTitles = {
    _animalsUuid: 'Animals pack',
    _plantsUuid: 'Plants pack',
  };
  // pack id -> set id -> (title, updatedAt)
  final Map<String, Map<String, (String, String)>> sets = {
    _animalsUuid: {
      _dogsUuid: ('Dogs', '2026-10-01'),
      _catsUuid: ('Cats', '2026-10-01'),
    },
    _plantsUuid: {_fernUuid: ('Ferns', '2026-10-01')},
  };
  final Set<String> failingSets = {};
  bool offline = false;
  Completer<void>? gate;
  final List<String> requested = [];

  String _packPath(String id) => id == _animalsUuid ? 'animals' : 'plants';

  Map<String, dynamic> setJson(String setId) {
    final (title, _) = sets.values.firstWhere(
      (m) => m.containsKey(setId),
    )[setId]!;
    return {
      'format': 'foxstreak-set',
      'version': 1,
      'id': setId,
      'title': title,
      'description': 'About $title',
      'createdBy': 'Jane',
      'category': 'vocab',
      'items': [
        {
          'type': 'phone',
          'prompt': 'Mama',
          'answer': '111',
          'id': 'a1b2c3d4-0000-4000-8000-${setId.substring(24)}',
        },
      ],
    };
  }

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    requested.add(path);
    if (offline) throw http.ClientException('offline');
    if (path.endsWith('marketplace.json')) {
      return http.Response(
        jsonEncode({
          'format': 'foxstreak-marketplace',
          'version': 1,
          'name': 'Test market',
          'description': '',
          'packs': [
            for (final id in packTitles.keys)
              {
                'id': id,
                'title': packTitles[id],
                'description': '',
                'url': 'packs/${_packPath(id)}.json',
              },
          ],
        }),
        200,
      );
    }
    for (final id in packTitles.keys) {
      if (path.endsWith('packs/${_packPath(id)}.json')) {
        return http.Response(
          jsonEncode({
            'format': 'foxstreak-pack',
            'version': 1,
            'id': id,
            'title': packTitles[id],
            'description': '',
            'sets': [
              for (final e in sets[id]!.entries)
                {
                  'id': e.key,
                  'title': e.value.$1,
                  'description': '',
                  'category': 'vocab',
                  'itemCount': 1,
                  'updatedAt': e.value.$2,
                  'url': 'sets/${e.key}.json',
                },
            ],
          }),
          200,
        );
      }
    }
    for (final id in sets.values.expand((m) => m.keys)) {
      if (path.endsWith('sets/$id.json')) {
        if (gate != null) await gate!.future;
        if (failingSets.contains(id)) return http.Response('boom', 500);
        return http.Response(jsonEncode(setJson(id)), 200);
      }
    }
    return http.Response('not found', 404);
  }

  /// Marks every set of [packId] as changed upstream.
  void touch(String packId) {
    sets[packId]!.updateAll((_, v) => (v.$1, '2026-11-01'));
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

/// Downloads [packId] from [fake] into [db] the way the Marketplace does.
Future<void> seedDownloadedPack(
  AppDatabase db,
  FakeMarketplace fake,
  String packId,
) async {
  final repo = MarketplaceRepository(
    db,
    SetsRepository(db, FakeClock(kTestToday)),
  );
  await repo.downloadPack(
    sourceUrl: _source,
    packId: packId,
    title: fake.packTitles[packId]!,
    description: '',
    sets: [
      for (final e in fake.sets[packId]!.entries)
        FetchedMarketplaceSet(
          setId: e.key,
          listingUpdatedAt: e.value.$2,
          json: fake.setJson(e.key),
        ),
    ],
  );
}

class Harness {
  final AppDatabase db;
  final FakeMarketplace fake;
  final ValueNotifier<bool> showHome = ValueNotifier(true);
  late ProviderContainer container;

  Harness(this.db, this.fake);
}

Widget _app(Harness h, {bool freezeBanner = false}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      appDatabaseProvider.overrideWithValue(h.db),
      systemClockProvider.overrideWithValue(FakeClock(kTestToday)),
      httpClientProvider.overrideWithValue(MockClient(h.fake.handle)),
      if (freezeBanner)
        streakFreezeAutoApplyProvider.overrideWith((ref) async => true),
    ],
    child: Builder(
      builder: (context) {
        h.container = ProviderScope.containerOf(context);
        return MaterialApp(
          theme: FoxStreakTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<bool>(
            valueListenable: h.showHome,
            builder: (_, show, _) =>
                show ? const HomeScreen() : const Scaffold(body: Text('away')),
          ),
        );
      },
    ),
  );
}

void testHome(
  String description,
  Future<void> Function(WidgetTester, Harness) body, {
  List<String> downloaded = const [],
  bool touchAfterSeed = true,
  bool freezeBanner = false,
}) {
  testWidgets(description, (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    await StatsRepository(db, FakeClock(kTestToday)).setOnboarded();
    final fake = FakeMarketplace();
    for (final id in downloaded) {
      await seedDownloadedPack(db, fake, id);
      if (touchAfterSeed) fake.touch(id);
    }
    final h = Harness(db, fake);
    await tester.pumpWidget(_app(h, freezeBanner: freezeBanner));
    await settle(tester);
    await body(tester, h);
    await unmount(tester);
  });
}

final _banner = find.byKey(const Key('packUpdateBanner'));
final _action = find.byKey(const Key('foxFeedbackBannerAction'));
final _close = find.byKey(const Key('foxFeedbackBannerClose'));

Future<List<QuestionSet>> _setsOf(AppDatabase db, String packId) async {
  final pack = (await db.select(db.packs).get()).singleWhere(
    (p) => p.sourcePackId == packId,
  );
  return (await db.select(db.questionSets).get())
      .where((s) => s.packId == pack.id)
      .toList();
}

void main() {
  group('check', () {
    testHome('without downloaded packs: no banner and no network', (
      tester,
      h,
    ) async {
      expect(_banner, findsNothing);
      expect(h.fake.requested, isEmpty);
    });

    testHome(
      'up to date packs show nothing',
      (tester, h) async {
        expect(h.fake.requested, isNotEmpty);
        expect(_banner, findsNothing);
      },
      downloaded: [_animalsUuid],
      touchAfterSeed: false,
    );

    testWidgets('offline or unreachable source: nothing shown, no error', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());
      await StatsRepository(db, FakeClock(kTestToday)).setOnboarded();
      final fake = FakeMarketplace();
      await seedDownloadedPack(db, fake, _animalsUuid);
      fake
        ..touch(_animalsUuid)
        ..offline = true;
      final h = Harness(db, fake);
      await tester.pumpWidget(_app(h));
      await settle(tester);
      expect(fake.requested, isNotEmpty);
      expect(_banner, findsNothing);
      expect(find.textContaining('rror'), findsNothing);
      await unmount(tester);
    });

    testHome('one pack with changes names the pack', (tester, h) async {
      expect(_banner, findsOneWidget);
      expect(find.text('New content in Animals pack'), findsOneWidget);
      expect(_action, findsOneWidget);
      expect(_close, findsOneWidget);
    }, downloaded: [_animalsUuid]);

    testHome(
      'a set added upstream counts as an update',
      (tester, h) async {
        h.fake.sets[_animalsUuid]![_fernUuid] = ('Ferns', '2026-11-01');
        await tester.pumpWidget(_app(h));
        await settle(tester);
        expect(find.text('New content in Animals pack'), findsOneWidget);
      },
      downloaded: [_animalsUuid],
      touchAfterSeed: false,
    );

    testHome('several packs with changes show one banner with the count', (
      tester,
      h,
    ) async {
      expect(_banner, findsOneWidget);
      expect(find.text('Updates available for 2 packs'), findsOneWidget);
    }, downloaded: [_animalsUuid, _plantsUuid]);

    testHome('resuming the app does not check again', (tester, h) async {
      final before = h.fake.requested.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(h.fake.requested.length, before);
    }, downloaded: [_animalsUuid]);
  });

  group('banner', () {
    testHome(
      'streak-freeze banner takes precedence; never two banners',
      (tester, h) async {
        expect(
          find.byKey(const Key('streakFreezeAppliedBanner')),
          findsOneWidget,
        );
        expect(_banner, findsNothing);
      },
      downloaded: [_animalsUuid],
      freezeBanner: true,
    );

    testHome(
      'dismiss hides it for the session and it returns on the next start',
      (tester, h) async {
        await tester.tap(_close);
        await settle(tester);
        expect(_banner, findsNothing);

        // Same session: leaving and returning to Home keeps it hidden.
        h.showHome.value = false;
        await settle(tester);
        h.showHome.value = true;
        await settle(tester);
        expect(_banner, findsNothing);

        // Next cold start: updates are still pending.
        await tester.pumpWidget(_app(h));
        await settle(tester);
        expect(_banner, findsOneWidget);
      },
      downloaded: [_animalsUuid],
    );

    testHome('dismiss is hidden while an update runs', (tester, h) async {
      h.fake.gate = Completer<void>();
      await tester.tap(_action);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Updating packs'), findsOneWidget);
      expect(_close, findsNothing);
      expect(_action, findsNothing);
      h.fake.gate!.complete();
      await settle(tester);
    }, downloaded: [_animalsUuid]);
  });

  group('update', () {
    testHome(
      'updates all affected packs in place, confirms and then disappears',
      (tester, h) async {
        await tester.tap(_action);
        await settle(tester);
        expect(find.text('Packs updated'), findsOneWidget);
        for (final id in [_animalsUuid, _plantsUuid]) {
          final listed = h.fake.sets[id]!;
          final rows = await db(h).select(db(h).importedMarketplaceSets).get();
          expect(
            rows
                .where((r) => r.packId == id)
                .every((r) => r.listingUpdatedAt == '2026-11-01'),
            isTrue,
          );
          expect(await _setsOf(db(h), id), hasLength(listed.length));
        }
        await tester.pump(const Duration(seconds: 4));
        expect(_banner, findsNothing);
      },
      downloaded: [_animalsUuid, _plantsUuid],
    );

    testHome('sets added upstream arrive, sets removed upstream stay', (
      tester,
      h,
    ) async {
      h.fake.sets[_animalsUuid]!
        ..remove(_catsUuid)
        ..[_fernUuid] = ('Ferns', '2026-11-01');
      await tester.pumpWidget(_app(h));
      await settle(tester);
      await tester.tap(_action);
      await settle(tester);
      expect((await _setsOf(db(h), _animalsUuid)).map((s) => s.title), {
        'Dogs',
        'Cats',
        'Ferns',
      });
    }, downloaded: [_animalsUuid]);

    testHome(
      'edited sets: the overwrite dialog lists them; skipping keeps them',
      (tester, h) async {
        final dogs = (await _setsOf(
          db(h),
          _animalsUuid,
        )).singleWhere((s) => s.title == 'Dogs');
        await SetsRepository(
          db(h),
          FakeClock(kTestToday.add(const Duration(days: 1))),
        ).updateSet(id: dogs.id, title: 'My dogs');
        await tester.tap(_action);
        await settle(tester);
        expect(find.text('Overwrite your local edits?'), findsOneWidget);
        expect(find.textContaining('• My dogs'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('skipOverwriteLocalEditsButton')),
        );
        await settle(tester);
        expect((await _setsOf(db(h), _animalsUuid)).map((s) => s.title), [
          'My dogs',
          'Cats',
        ]);
        expect(find.text('Packs updated'), findsOneWidget);
      },
      downloaded: [_animalsUuid],
    );

    testHome(
      'edited sets: confirming overwrites them (one dialog for all packs)',
      (tester, h) async {
        final sets = SetsRepository(
          db(h),
          FakeClock(kTestToday.add(const Duration(days: 1))),
        );
        for (final id in [_animalsUuid, _plantsUuid]) {
          final first = (await _setsOf(db(h), id)).first;
          await sets.updateSet(id: first.id, title: 'Mine ${first.title}');
        }
        await tester.tap(_action);
        await settle(tester);
        expect(find.text('Overwrite your local edits?'), findsOneWidget);
        expect(find.textContaining('• Mine Dogs'), findsOneWidget);
        expect(find.textContaining('• Mine Ferns'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('confirmOverwriteLocalEditsButton')),
        );
        await settle(tester);
        expect((await _setsOf(db(h), _animalsUuid)).map((s) => s.title), [
          'Dogs',
          'Cats',
        ]);
        expect((await _setsOf(db(h), _plantsUuid)).map((s) => s.title), [
          'Ferns',
        ]);
      },
      downloaded: [_animalsUuid, _plantsUuid],
    );

    testHome(
      'a failing pack leaves existing sets intact; retry only covers it',
      (tester, h) async {
        h.fake.failingSets.add(_fernUuid);
        await tester.tap(_action);
        await settle(tester);
        expect(find.textContaining('Some packs are updated'), findsOneWidget);
        expect(_close, findsOneWidget);
        // Animals updated, Plants untouched.
        final rows = await db(h).select(db(h).importedMarketplaceSets).get();
        expect(
          rows.singleWhere((r) => r.setId == _dogsUuid).listingUpdatedAt,
          '2026-11-01',
        );
        expect(
          rows.singleWhere((r) => r.setId == _fernUuid).listingUpdatedAt,
          '2026-10-01',
        );
        expect(await _setsOf(db(h), _plantsUuid), hasLength(1));

        h.fake.failingSets.clear();
        h.fake.requested.clear();
        await tester.tap(_action);
        await settle(tester);
        expect(find.text('Packs updated'), findsOneWidget);
        expect(h.fake.requested.where((p) => p.contains('sets/')).toList(), [
          '/packs/sets/$_fernUuid.json',
        ]);
      },
      downloaded: [_animalsUuid, _plantsUuid],
    );

    testHome('a single failing pack shows the plain retry message', (
      tester,
      h,
    ) async {
      h.fake.failingSets.add(_dogsUuid);
      await tester.tap(_action);
      await settle(tester);
      expect(find.textContaining('The update did not finish'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    }, downloaded: [_animalsUuid]);

    testHome(
      'keeps running when the learner leaves Home; the result is shown once',
      (tester, h) async {
        h.fake.gate = Completer<void>();
        await tester.tap(_action);
        await tester.pump(const Duration(milliseconds: 100));
        h.showHome.value = false;
        await settle(tester);

        h.fake.gate!.complete();
        await settle(tester);
        h.showHome.value = true;
        await settle(tester);
        expect(find.text('Packs updated'), findsOneWidget);

        await tester.pump(const Duration(seconds: 4));
        expect(_banner, findsNothing);
        h.showHome.value = false;
        await settle(tester);
        h.showHome.value = true;
        await settle(tester);
        expect(_banner, findsNothing);
      },
      downloaded: [_animalsUuid],
    );

    testHome('a pack already being updated elsewhere is not updated twice', (
      tester,
      h,
    ) async {
      h.container
          .read(packUpdateLocksProvider)
          .tryAcquire(_source, _animalsUuid);
      h.fake.requested.clear();
      await tester.tap(_action);
      await settle(tester);
      expect(h.fake.requested.where((p) => p.contains('sets/')), isEmpty);
      expect(_banner, findsNothing);
    }, downloaded: [_animalsUuid]);

    testHome('skipping every edited set keeps the update pending', (
      tester,
      h,
    ) async {
      final sets = SetsRepository(
        db(h),
        FakeClock(kTestToday.add(const Duration(days: 1))),
      );
      for (final s in await _setsOf(db(h), _plantsUuid)) {
        await sets.updateSet(id: s.id, title: 'Mine');
      }
      await tester.tap(_action);
      await settle(tester);
      await tester.tap(find.byKey(const Key('skipOverwriteLocalEditsButton')));
      await settle(tester);
      expect(find.text('New content in Plants pack'), findsOneWidget);
    }, downloaded: [_plantsUuid]);

    testHome('a pack updated elsewhere drops out of the banner', (
      tester,
      h,
    ) async {
      final controller = h.container.read(
        packUpdateControllerProvider.notifier,
      );
      controller.packChanged(_source, _animalsUuid);
      await settle(tester);
      expect(find.text('New content in Plants pack'), findsOneWidget);
      controller.packChanged(_source, _plantsUuid);
      await settle(tester);
      expect(_banner, findsNothing);
    }, downloaded: [_animalsUuid, _plantsUuid]);

    testHome('a pack deleted before the update is skipped silently', (
      tester,
      h,
    ) async {
      await (db(
        h,
      ).delete(db(h).packs)..where((t) => t.sourceUrl.isNotNull())).go();
      await tester.tap(_action);
      await settle(tester);
      expect(_banner, findsNothing);
      expect(find.textContaining('did not finish'), findsNothing);
    }, downloaded: [_animalsUuid]);
  });
}

AppDatabase db(Harness h) => h.db;
