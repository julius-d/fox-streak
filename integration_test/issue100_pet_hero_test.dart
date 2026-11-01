// Issue #100 — Hero animation for the pet between Home and Pet Collection.
//
// Drives the real app's Navigator push/pop between `HomeScreen` and
// `PetCollectionScreen` (not just each screen pumped in isolation, as
// `test/home/home_screen_test.dart`/`test/pet/pet_screens_test.dart` do) —
// the one thing only a real navigation transition can prove: both routes'
// `Hero`s are briefly mounted together during the flight, which is exactly
// when Flutter throws if two Heroes in the same route ever shared a tag.
// Also covers equipping a different pet while on PetCollectionScreen and
// navigating back (the pet that flies home is whichever is equipped at pop
// time, per the issue's "Decisions"), and that reduce motion leaves the
// flow working with no flight at all.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/main.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/pet_repository.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
import 'package:fox_streak_app/src/pet/pet_hero.dart';

import 'helpers.dart';

// Crab: a real catalog entry distinct from the default fox, so the test can
// own two pets and equip whichever one isn't currently equipped.
final _crab = petEntryForId('emoji_u1f980_lottie');

/// Pumps the real [FoxStreakApp] with OS reduce-motion forced on, mirroring
/// `test/pet/pet_screens_test.dart`'s `_disableAnimations` builder — but
/// applied outside `FoxStreakApp` (which exposes no `builder` passthrough),
/// reading the ambient `MediaQueryData` the test binding's `View` already
/// provides so device size/etc. stay real.
Future<void> _pumpReduceMotionApp(
  WidgetTester tester, {
  required AppDatabase db,
  required FakeClock clock,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
        integrationTestSilentSound,
      ],
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: const FoxStreakApp(),
        ),
      ),
    ),
  );
  await settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'tapping the pet on Home pushes PetCollectionScreen with both sides '
    'sharing equippedPetHeroTag, and navigating back carries whichever pet '
    'is equipped at pop time (issue #100)',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 28, 9));
      await StatsRepository(db, clock).setOnboarded();
      await PetRepository(db).addOwnedPet(_crab.id);

      await pumpFoxStreakApp(tester, db: db, clock: clock);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(
        find.byKey(const Key('foxPet-$kDefaultPetId')),
        findsOneWidget,
        reason: 'the default fox starts owned+equipped',
      );

      // Mid-flight: both HomeScreen's and PetCollectionScreen's Heroes are
      // briefly mounted together. A tag collision would throw right here.
      await tester.tap(find.byKey(const Key('homePetButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);

      await settle(tester);
      expect(find.byKey(const Key('petCollectionScreen')), findsOneWidget);
      final equippedTileHero = find.ancestor(
        of: find.byKey(const Key('foxPet-$kDefaultPetId')),
        matching: find.byType(Hero),
      );
      expect(equippedTileHero, findsOneWidget);
      expect(tester.widget<Hero>(equippedTileHero).tag, equippedPetHeroTag);

      // Equip the other owned pet (crab) while on the collection screen —
      // no navigation happens from equipping itself.
      await tester.tap(find.byKey(Key('petTile-${_crab.id}')));
      await settle(tester);
      expect(
        (await StatsRepository(db, clock).getProfile()).equippedPetId,
        _crab.id,
      );

      // Pop back to Home: mid-flight again, then settled. The pet that
      // flies back is crab (whatever was equipped at pop time), not fox.
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);

      await settle(tester);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(find.byKey(Key('foxPet-${_crab.id}')), findsOneWidget);
      expect(find.byKey(const Key('foxPet-$kDefaultPetId')), findsNothing);
    },
  );

  testWidgets(
    'with OS reduce motion on, the same Home <-> PetCollection round trip '
    'still works, with no Hero flight at all (issue #100)',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 28, 9));
      await StatsRepository(db, clock).setOnboarded();
      await PetRepository(db).addOwnedPet(_crab.id);

      await _pumpReduceMotionApp(tester, db: db, clock: clock);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('foxPet-$kDefaultPetId')),
          matching: find.byType(Hero),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('homePetButton')));
      await settle(tester);
      expect(find.byKey(const Key('petCollectionScreen')), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('foxPet-$kDefaultPetId')),
          matching: find.byType(Hero),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(Key('petTile-${_crab.id}')));
      await settle(tester);

      await tester.pageBack();
      await settle(tester);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(find.byKey(Key('foxPet-${_crab.id}')), findsOneWidget);
    },
  );
}
