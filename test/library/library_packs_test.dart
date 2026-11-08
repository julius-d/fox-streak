// Widget tests for pack grouping in the library (issue #121): single-pack
// plain list, collapsible sections, persistence, empty-pack hint, moving
// sets, and pack management (rename/delete).
//
// NOTE on pumping: no `pumpAndSettle()` — same drift `watch()` fake-async
// caveat as `library_screen_test.dart`'s `settle()`.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/packs_repository.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/library/library_screen.dart';
import 'package:fox_streak_app/src/library/pack_sections.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

import '../data/test_helpers.dart';

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

/// `testWidgets` that unmounts the tree at the end (flushes drift's
/// stream-close timer before the fake-async invariant check).
void testPacks(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await unmount(tester);
  });
}

class LibraryEnv {
  final AppDatabase db;
  final FakeClock clock;
  final SetsRepository sets;
  final PacksRepository packs;

  LibraryEnv(this.db, this.clock)
    : sets = SetsRepository(db, clock),
      packs = PacksRepository(db, clock);

  Future<int> downloadedPack(String title, {int at = 1}) => db
      .into(db.packs)
      .insert(
        PacksCompanion.insert(
          title: title,
          createdAt: at,
          sourceUrl: const Value('https://a.example/m.json'),
          sourcePackId: Value('pack-$title'),
          downloadedAt: Value(at),
        ),
      );

  Future<int> downloadedSet(String title, int packId) =>
      sets.importSetFromJson({
        'format': 'foxstreak-set',
        'version': 1,
        'title': title,
        'createdBy': 'x',
        'items': <Map<String, dynamic>>[],
      }, packId: packId);
}

Future<LibraryEnv> pumpLibrary(
  WidgetTester tester, {
  Future<void> Function(LibraryEnv env)? seed,
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool dark = false,
  Size? size,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
  final env = LibraryEnv(db, FakeClock(kTestToday));
  if (seed != null) await seed(env);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(env.clock),
      ],
      child: MaterialApp(
        locale: locale,
        theme: dark ? FoxStreakTheme.dark() : FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const LibraryScreen(),
      ),
    ),
  );
  await settle(tester);
  return env;
}

void main() {
  group('groupSetsByPack', () {
    test('keeps pack order and gives empty packs an empty section', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final env = LibraryEnv(db, FakeClock(kTestToday));
      final other = await env.packs.createPack('Other');
      final a = await env.sets.createSet(title: 'A', createdBy: 'me');
      final b = await env.sets.createSet(
        title: 'B',
        createdBy: 'me',
        packId: other,
      );
      final c = await env.sets.createSet(title: 'C', createdBy: 'me');
      final empty = await env.packs.createPack('Empty');

      final sections = groupSetsByPack(
        await env.packs.getAllPacks(),
        await env.sets.getAllSets(),
      );

      expect(sections.map((s) => s.pack.title), ['My sets', 'Other', 'Empty']);
      expect(sections[0].sets.map((s) => s.id), [a, c]);
      expect(sections[1].sets.map((s) => s.id), [b]);
      expect(sections[2].pack.id, empty);
      expect(sections[2].sets, isEmpty);
    });
  });

  group('single pack', () {
    testPacks('looks like a plain set list: no header, no collapse control', (
      tester,
    ) async {
      final env = await pumpLibrary(
        tester,
        seed: (env) async {
          await env.sets.createSet(title: 'Animals', createdBy: 'me');
        },
      );
      final pack = (await env.packs.getAllPacks()).single;

      expect(find.text('Animals'), findsOneWidget);
      expect(find.byKey(Key('packHeader-${pack.id}')), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testPacks('a single downloaded pack is plain too', (tester) async {
      await pumpLibrary(
        tester,
        seed: (env) async {
          // Remove the default own pack: only a downloaded pack remains.
          final dl = await env.downloadedPack('Remote');
          await env.downloadedSet('Remote set', dl);
          await env.packs.deletePack((await env.packs.getAllPacks()).first.id);
        },
      );
      expect(find.text('Remote set'), findsOneWidget);
      expect(find.text('Remote'), findsNothing);
    });
  });

  group('sections', () {
    testPacks('own packs first, then downloaded; headers show title + '
        'count', (tester) async {
      final env = await pumpLibrary(
        tester,
        seed: (env) async {
          final dl = await env.downloadedPack('Remote pack');
          await env.downloadedSet('Remote set', dl);
          final own = await env.packs.createPack('Trip');
          await env.sets.createSet(title: 'Own one', createdBy: 'me');
          await env.sets.createSet(
            title: 'Trip set',
            createdBy: 'me',
            packId: own,
          );
        },
      );
      final packs = await env.packs.getAllPacks();
      expect(packs.map((p) => p.title), ['My sets', 'Trip', 'Remote pack']);

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('My sets'), lessThan(top('Trip')));
      expect(top('Trip'), lessThan(top('Remote pack')));
      expect(find.text('1 set'), findsNWidgets(3));
      // Set cards sit below their header.
      expect(top('Own one'), greaterThan(top('My sets')));
      expect(top('Own one'), lessThan(top('Trip')));
    });

    testPacks('tapping a header collapses/expands and the state is '
        'persisted', (tester) async {
      late int tripId;
      final env = await pumpLibrary(
        tester,
        seed: (env) async {
          tripId = await env.packs.createPack('Trip');
          await env.sets.createSet(
            title: 'Trip set',
            createdBy: 'me',
            packId: tripId,
          );
          await env.sets.createSet(title: 'Own one', createdBy: 'me');
        },
      );
      expect(find.text('Trip set'), findsOneWidget);

      await tester.tap(find.byKey(Key('packHeader-$tripId')));
      await settle(tester);
      expect(find.text('Trip set'), findsNothing);
      expect(find.text('Own one'), findsOneWidget);
      expect((await env.packs.getPackById(tripId))!.collapsed, isTrue);

      // "Restart": a fresh tree on the same database stays collapsed.
      await unmount(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(env.db),
            systemClockProvider.overrideWithValue(env.clock),
          ],
          child: MaterialApp(
            theme: FoxStreakTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LibraryScreen(),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Trip set'), findsNothing);

      await tester.tap(find.byKey(Key('packHeader-$tripId')));
      await settle(tester);
      expect(find.text('Trip set'), findsOneWidget);
      expect((await env.packs.getPackById(tripId))!.collapsed, isFalse);
    });

    testPacks('header is a 48dp target announcing its state', (tester) async {
      late int tripId;
      await pumpLibrary(
        tester,
        seed: (env) async {
          tripId = await env.packs.createPack('Trip');
          await env.sets.createSet(
            title: 'Trip set',
            createdBy: 'me',
            packId: tripId,
          );
        },
      );
      final header = find.byKey(Key('packHeader-$tripId'));
      expect(tester.getSize(header).height, greaterThanOrEqualTo(48));
      expect(
        find.bySemanticsLabel('Trip, 1 set, expanded. Tap to collapse.'),
        findsOneWidget,
      );

      await tester.tap(header);
      await settle(tester);
      expect(
        find.bySemanticsLabel('Trip, 1 set, collapsed. Tap to expand.'),
        findsOneWidget,
      );
    });

    testPacks('long pack titles wrap instead of clipping, also with large '
        'text', (tester) async {
      const title =
          'A really quite extraordinarily long pack title that has to wrap '
          'onto several lines on a narrow phone';
      late int packId;
      await pumpLibrary(
        tester,
        textScale: 2,
        size: const Size(360, 800),
        seed: (env) async {
          packId = await env.packs.createPack(title);
        },
      );
      expect(tester.takeException(), isNull);
      final text = find.descendant(
        of: find.byKey(Key('packHeader-$packId')),
        matching: find.text(title),
      );
      expect(text, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.getSize(text).height, greaterThan(60));
    });

    testPacks('renders in dark mode and German', (tester) async {
      await pumpLibrary(
        tester,
        locale: const Locale('de'),
        dark: true,
        seed: (env) async {
          await env.packs.createPack('Reise');
          await env.sets.createSet(title: 'Eins', createdBy: 'me');
        },
      );
      expect(find.text('Meine Sets'), findsOneWidget);
      expect(find.text('1 Set'), findsOneWidget);
      expect(find.text('Dieses Pack hat noch keine Sets.'), findsOneWidget);
    });
  });

  group('empty own pack', () {
    testPacks('shows a hint and an "Add set" action opening the editor '
        'preselecting that pack', (tester) async {
      late int emptyId;
      await pumpLibrary(
        tester,
        seed: (env) async {
          await env.sets.createSet(title: 'Own one', createdBy: 'me');
          emptyId = await env.packs.createPack('Empty one');
        },
      );
      expect(find.byKey(const Key('packEmptyHint')), findsOneWidget);

      await tester.tap(find.byKey(const Key('packAddSetButton')));
      await settle(tester);

      expect(find.byKey(const Key('titleField')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('titleField')), 'New set');
      await tester.enterText(find.byKey(const Key('creatorField')), 'me');
      await tester.tap(find.byKey(const Key('saveSetButton')));
      await settle(tester);

      final env = ProviderScope.containerOf(
        tester.element(find.byType(LibraryScreen)),
      );
      final created = (await env.read(setsRepositoryProvider).getAllSets())
          .firstWhere((s) => s.title == 'New set');
      expect(created.packId, emptyId);
    });
  });

  group('empty downloaded pack', () {
    testPacks('shows the hint but no "Add set" action', (tester) async {
      await pumpLibrary(
        tester,
        seed: (env) async {
          await env.sets.createSet(title: 'Own', createdBy: 'me');
          await env.downloadedPack('Remote');
        },
      );
      expect(find.byKey(const Key('packEmptyHint')), findsOneWidget);
      expect(find.byKey(const Key('packAddSetButton')), findsNothing);
    });
  });

  group('moving sets', () {
    testPacks('own sets can be moved to another own pack; downloaded sets '
        'cannot be moved', (tester) async {
      late int setId;
      late int downloadedSetId;
      late int otherId;
      final env = await pumpLibrary(
        tester,
        seed: (env) async {
          setId = await env.sets.createSet(title: 'Movable', createdBy: 'me');
          otherId = await env.packs.createPack('Other');
          final dl = await env.downloadedPack('Remote');
          downloadedSetId = await env.downloadedSet('Fixed', dl);
        },
      );

      await tester.tap(find.byKey(Key('setMenu-$downloadedSetId')));
      await settle(tester);
      expect(find.text('Move to pack…'), findsNothing);
      await tester.tapAt(const Offset(1, 1)); // dismiss
      await settle(tester);

      await tester.tap(find.byKey(Key('setMenu-$setId')));
      await settle(tester);
      await tester.tap(find.text('Move to pack…'));
      await settle(tester);
      // Only the other *own* pack is offered, never a downloaded one.
      expect(find.byKey(Key('moveTarget-$otherId')), findsOneWidget);
      expect(find.byType(SimpleDialogOption), findsOneWidget);
      await tester.tap(find.byKey(Key('moveTarget-$otherId')));
      await settle(tester);

      expect((await env.sets.getSetById(setId))!.packId, otherId);
    });

    testPacks('no move entry with a single own pack', (tester) async {
      late int setId;
      await pumpLibrary(
        tester,
        seed: (env) async {
          setId = await env.sets.createSet(title: 'Alone', createdBy: 'me');
        },
      );
      await tester.tap(find.byKey(Key('setMenu-$setId')));
      await settle(tester);
      expect(find.text('Move to pack…'), findsNothing);
    });
  });

  group('pack management', () {
    Future<void> openManagement(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('managePacksButton')));
      await settle(tester);
    }

    testPacks('own packs can be renamed; downloaded packs cannot', (
      tester,
    ) async {
      late int ownId;
      late int dlId;
      final env = await pumpLibrary(
        tester,
        seed: (env) async {
          ownId = await env.packs.createPack('Old name');
          dlId = await env.downloadedPack('Remote');
          await env.downloadedSet('S', dlId);
        },
      );
      await openManagement(tester);

      await tester.tap(find.byKey(Key('packMenu-$dlId')));
      await settle(tester);
      expect(find.text('Rename pack'), findsNothing);
      expect(find.text('Delete pack'), findsOneWidget);
      await tester.tapAt(const Offset(1, 1));
      await settle(tester);

      await tester.tap(find.byKey(Key('packMenu-$ownId')));
      await settle(tester);
      await tester.tap(find.text('Rename pack'));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('renamePackField')),
        'New name',
      );
      await tester.tap(find.byKey(const Key('confirmRenamePackButton')));
      await settle(tester);

      expect((await env.packs.getPackById(ownId))!.title, 'New name');
      expect(find.text('New name'), findsOneWidget);
    });

    testPacks('delete asks for confirmation and states the set count', (
      tester,
    ) async {
      late int packId;
      final env = await pumpLibrary(
        tester,
        seed: (env) async {
          packId = await env.packs.createPack('Doomed');
          await env.sets.createSet(
            title: 'One',
            createdBy: 'me',
            packId: packId,
          );
          await env.sets.createSet(
            title: 'Two',
            createdBy: 'me',
            packId: packId,
          );
        },
      );
      await openManagement(tester);

      await tester.tap(find.byKey(Key('packMenu-$packId')));
      await settle(tester);
      await tester.tap(find.text('Delete pack'));
      await settle(tester);
      expect(find.textContaining('its 2 sets'), findsOneWidget);

      // Cancel keeps everything.
      await tester.tap(find.byKey(const Key('cancelDeletePackButton')));
      await settle(tester);
      expect(await env.packs.getPackById(packId), isNotNull);

      await tester.tap(find.byKey(Key('packMenu-$packId')));
      await settle(tester);
      await tester.tap(find.text('Delete pack'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirmDeletePackButton')));
      await settle(tester);

      expect(await env.packs.getPackById(packId), isNull);
      expect(await env.sets.getAllSets(), isEmpty);
    });

    testPacks('deleting the last pack recreates an empty "My sets"', (
      tester,
    ) async {
      final env = await pumpLibrary(tester);
      final only = (await env.packs.getAllPacks()).single;
      await openManagement(tester);

      await tester.tap(find.byKey(Key('packMenu-${only.id}')));
      await settle(tester);
      await tester.tap(find.text('Delete pack'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirmDeletePackButton')));
      await settle(tester);

      final packs = await env.packs.getAllPacks();
      expect(packs, hasLength(1));
      expect(packs.single.title, 'My sets');
      expect(packs.single.id, isNot(only.id));
      expect(find.text('My sets'), findsOneWidget);
    });
  });
}
