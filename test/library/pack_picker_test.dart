// Widget tests for the pack picker used when creating or importing a set
// (issue #121): default selection, own packs only, inline "new pack".

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/packs_repository.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/library/pack_picker.dart';
import 'package:fox_streak_app/src/library/set_editor_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

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

void testPicker(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await unmount(tester);
  });
}

class PickerEnv {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  final FakeClock clock = FakeClock(kTestToday);
  late final SetsRepository sets = SetsRepository(db, clock);
  late final PacksRepository packs = PacksRepository(db, clock);
}

Future<PickerEnv> pumpHome(WidgetTester tester, Widget home) async {
  final env = PickerEnv();
  addTearDown(() async => env.db.close());
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
        home: home,
      ),
    ),
  );
  await settle(tester);
  return env;
}

Future<void> choose(WidgetTester tester, Key option) async {
  await tester.tap(find.byKey(const Key('packPicker')));
  await settle(tester);
  await tester.tap(find.byKey(option).last);
  await settle(tester);
}

Future<void> saveNewSet(WidgetTester tester, String title) async {
  await tester.enterText(find.byKey(const Key('titleField')), title);
  await tester.enterText(find.byKey(const Key('creatorField')), 'me');
  await tester.tap(find.byKey(const Key('saveSetButton')));
  await settle(tester);
}

void main() {
  group('SetEditorScreen pack picker', () {
    testPicker('defaults to the only pack and saves the set into it', (
      tester,
    ) async {
      final env = await pumpHome(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<int>(builder: (_) => const SetEditorScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.text('My sets'), findsWidgets);

      await saveNewSet(tester, 'Fresh');

      final only = (await env.packs.getAllPacks()).single;
      expect((await env.sets.getAllSets()).single.packId, only.id);
    });

    testPicker('defaults to the pack last used', (tester) async {
      final env = PickerEnv();
      addTearDown(() async => env.db.close());
      final tripId = await env.packs.createPack('Trip');
      await env.sets.createSet(title: 'Older', createdBy: 'me');
      env.clock.setNow(kTestToday.add(const Duration(minutes: 5)));
      await env.sets.createSet(title: 'Newer', createdBy: 'me', packId: tripId);
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
            home: const SetEditorScreen(),
          ),
        ),
      );
      await settle(tester);

      await saveNewSet(tester, 'Third');

      final third = (await env.sets.getAllSets()).firstWhere(
        (s) => s.title == 'Third',
      );
      expect(third.packId, tripId);
    });

    testPicker('lists own packs only, never downloaded ones', (tester) async {
      final env = await pumpHome(tester, const SetEditorScreen());
      final own = await env.packs.createPack('Trip');
      await env.db
          .into(env.db.packs)
          .insert(
            PacksCompanion.insert(
              title: 'Remote pack',
              createdAt: 1,
              sourceUrl: const Value('https://a.example/m.json'),
              sourcePackId: const Value('p'),
              downloadedAt: const Value(1),
            ),
          );
      await settle(tester);

      await tester.tap(find.byKey(const Key('packPicker')));
      await settle(tester);

      expect(find.byKey(Key('packPickerOption-$own')), findsWidgets);
      expect(find.text('Remote pack'), findsNothing);
      expect(find.text('New pack…'), findsOneWidget);
    });

    testPicker('inline new pack is created, selected and used', (tester) async {
      final env = await pumpHome(tester, const SetEditorScreen());

      await choose(tester, const Key('packPickerNewPackOption'));
      expect(find.byKey(const Key('newPackTitleField')), findsOneWidget);
      // Create is disabled until a title is typed.
      expect(
        tester
            .widget<FoxSecondaryButton>(
              find.byKey(const Key('createPackButton')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('newPackTitleField')),
        'Brand new',
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('createPackButton')));
      await settle(tester);

      // Selected right away; the inline field is gone.
      expect(find.byKey(const Key('newPackTitleField')), findsNothing);
      expect(find.text('Brand new'), findsWidgets);

      await saveNewSet(tester, 'In new pack');

      final packs = await env.packs.getAllPacks();
      final created = packs.firstWhere((p) => p.title == 'Brand new');
      final set = (await env.sets.getAllSets()).single;
      expect(set.packId, created.id);
    });

    testPicker('is not shown when editing an existing set', (tester) async {
      final env = PickerEnv();
      addTearDown(() async => env.db.close());
      final id = await env.sets.createSet(title: 'Old', createdBy: 'me');
      final existing = (await env.sets.getSetById(id))!;
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
            home: SetEditorScreen(existing: existing),
          ),
        ),
      );
      await settle(tester);
      expect(find.byKey(const Key('packPicker')), findsNothing);
    });
  });

  group('showPackChoiceDialog (file import)', () {
    Future<PickerEnv> openDialog(
      WidgetTester tester,
      void Function(int?) onResult,
    ) async {
      final env = await pumpHome(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async =>
                  onResult(await showPackChoiceDialog(context)),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      return env;
    }

    testPicker('returns the preselected pack on confirm', (tester) async {
      int? result;
      var called = false;
      final env = await openDialog(tester, (r) {
        result = r;
        called = true;
      });
      expect(find.text('Import into which pack?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmPackChoiceButton')));
      await settle(tester);

      expect(called, isTrue);
      expect(result, (await env.packs.getAllPacks()).single.id);
    });

    testPicker('lets the learner pick another pack or create one', (
      tester,
    ) async {
      int? result;
      final env = await openDialog(tester, (r) => result = r);
      final other = await env.packs.createPack('Other');
      await settle(tester);

      await choose(tester, Key('packPickerOption-$other'));
      await tester.tap(find.byKey(const Key('confirmPackChoiceButton')));
      await settle(tester);
      expect(result, other);
    });

    testPicker('opening "New pack…" disables Import until a pack exists', (
      tester,
    ) async {
      await openDialog(tester, (_) {});
      await choose(tester, const Key('packPickerNewPackOption'));
      expect(
        tester
            .widget<FoxPrimaryButton>(
              find.byKey(const Key('confirmPackChoiceButton')),
            )
            .onPressed,
        isNull,
      );
    });

    testPicker('cancel resolves to null', (tester) async {
      int? result = -1;
      await openDialog(tester, (r) => result = r);
      await tester.tap(find.byKey(const Key('cancelPackChoiceButton')));
      await settle(tester);
      expect(result, isNull);
    });
  });
}
