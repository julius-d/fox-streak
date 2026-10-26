// Widget tests for the lootbox reveal + pet collection screens
// (issue #059; rarity/seasonal labels + owned-count badge by #069).
//
// NOTE on pumping: do NOT use `pumpAndSettle()` for `PetCollectionScreen`
// — same drift `watch()` fake-async caveat as `library_screen_test.dart`'s
// own `settle()` (it watches `profileProvider`/`ownedPetCountsProvider`).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/pet_repository.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/pet/lootbox_reward.dart';
import 'package:fox_streak_app/src/pet/lootbox_screen.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
import 'package:fox_streak_app/src/pet/pet_collection_screen.dart';
import 'package:fox_streak_app/src/stats/pet_service.dart';

/// Turns off a `FoxPet`'s loop-with-pause (issue #071) so it plays once
/// and holds, instead of looping for as long as these screens stay mounted.
Widget _disableAnimations(BuildContext context, Widget? child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(disableAnimations: true),
  child: child!,
);

/// Pumps frames until none are scheduled (or [cap] is hit, which fails).
Future<void> settle(WidgetTester tester, {int cap = 50}) async {
  for (var i = 0; i < cap; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) return;
  }
  fail('UI did not settle after $cap frames');
}

/// Unmounts the tree and flushes drift's stream-close timer so the fake-async
/// invariant check passes (see note above).
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

// Crab: a real catalog entry (Uncommon rarity), used throughout instead of
// a hand-rolled fixture so it carries correct rarity/sortOrder/season data.
final _reward = petEntryForId('emoji_u1f980_lottie');
final _petReward = PetReward(_reward);
const _coinsReward = CoinsReward(40);

Future<AppDatabase> pumpCollectionScreen(
  WidgetTester tester, {
  AppDatabase? database,
  Future<List<PetEntry>> Function()? catalog,
}) async {
  final db = database ?? AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
  // Tall enough that every one of the catalog's 11 tiles (4 rows of 3) is
  // already built, so tests can find any tile's key directly without
  // scrolling/`ensureVisible` racing the grid's lazy build.
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        if (catalog != null)
          petCatalogLoaderProvider.overrideWithValue(catalog),
      ],
      child: const MaterialApp(
        builder: _disableAnimations,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PetCollectionScreen(),
      ),
    ),
  );
  await settle(tester);
  return db;
}

void main() {
  group('LootboxScreen', () {
    testWidgets(
      'tap starts the opening animation (no immediate reveal, no longer '
      'tappable); it reveals the reward + a single continue action only '
      'once the animation finishes',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: _disableAnimations,
            home: LootboxScreen(reward: _petReward, l10n: AppLocalizationsEn()),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('lootboxOpenButton')), findsOneWidget);
        expect(find.byKey(const Key('lootboxAnimation')), findsOneWidget);
        expect(find.byKey(const Key('lootboxContinueButton')), findsNothing);
        expect(find.byKey(Key('foxPet-${_reward.id}')), findsNothing);

        await tester.tap(find.byKey(const Key('lootboxOpenButton')));
        await tester.pump();

        // Opening: no longer a tap target, not yet revealed.
        expect(find.byKey(const Key('lootboxOpenButton')), findsNothing);
        expect(find.byKey(const Key('lootboxAnimation')), findsOneWidget);
        expect(find.byKey(const Key('lootboxContinueButton')), findsNothing);
        expect(find.byKey(Key('foxPet-${_reward.id}')), findsNothing);

        // A re-tap at the same spot mid-animation is a no-op (there is no
        // tap target there anymore).
        await tester.tapAt(tester.getCenter(find.byType(MaterialApp)));
        await tester.pump();
        expect(find.byKey(const Key('lootboxContinueButton')), findsNothing);

        // Revealed, once the animation completes.
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('lootboxAnimation')), findsNothing);
        expect(find.byKey(Key('foxPet-${_reward.id}')), findsOneWidget);
        expect(find.byKey(const Key('lootboxContinueButton')), findsOneWidget);
      },
    );

    testWidgets('continue pops the screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: _disableAnimations,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => LootboxScreen(
                        reward: _petReward,
                        l10n: AppLocalizationsEn(),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lootboxOpenButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lootboxContinueButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lootboxScreen')), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a coins reward reveals the coin Lottie + amount, not a pet '
        '(issue #065)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: _disableAnimations,
          home: LootboxScreen(reward: _coinsReward, l10n: AppLocalizationsEn()),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('lootboxCoinReveal')), findsNothing);
      await tester.tap(find.byKey(const Key('lootboxOpenButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lootboxCoinReveal')), findsOneWidget);
      expect(find.byKey(Key('foxPet-${_reward.id}')), findsNothing);
      expect(find.text('You won 40 coins!'), findsOneWidget);
      expect(find.byKey(const Key('lootboxContinueButton')), findsOneWidget);
    });
  });

  group('PetCollectionScreen', () {
    testWidgets('owned pet is tappable; not-yet-owned ones render '
        'locked', (tester) async {
      await pumpCollectionScreen(tester);

      expect(find.byKey(const Key('petCollectionGrid')), findsOneWidget);
      // Default fox is seeded as owned+equipped.
      expect(find.byKey(const Key('petTile-$kDefaultPetId')), findsOneWidget);
      // At least one other catalog entry is still locked.
      expect(find.byIcon(Icons.lock_outline), findsWidgets);

      await unmount(tester);
    });

    testWidgets('tapping an owned, not-yet-equipped pet equips it', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final statsRepo = StatsRepository(db);
      final petRepo = PetRepository(db);
      await petRepo.addOwnedPet(_reward.id);

      await pumpCollectionScreen(tester, database: db);

      // The catalog has grown past #059's original 7 entries (#063), so the
      // tile isn't guaranteed to already be within the scrollable grid's
      // viewport.
      await tester.ensureVisible(find.byKey(Key('petTile-${_reward.id}')));
      await settle(tester);
      await tester.tap(find.byKey(Key('petTile-${_reward.id}')));
      await settle(tester);

      expect((await statsRepo.getProfile()).equippedPetId, _reward.id);

      await unmount(tester);
    });

    testWidgets('tapping a locked (not-yet-owned) tile does nothing', (
      tester,
    ) async {
      final db = await pumpCollectionScreen(tester);
      final statsRepo = StatsRepository(db);
      final before = (await statsRepo.getProfile()).equippedPetId;

      // Any locked tile has no onTap target at all, so tapping its lock
      // icon is a no-op rather than throwing a hit-test warning.
      await tester.tap(find.byIcon(Icons.lock_outline).first);
      await settle(tester);

      expect((await statsRepo.getProfile()).equippedPetId, before);

      await unmount(tester);
    });

    testWidgets('tiles are ordered by sortOrder ascending (fox first) even '
        'if the catalog loader returns a different order (issue #069)', (
      tester,
    ) async {
      await pumpCollectionScreen(
        tester,
        catalog: () async => PetCatalog.entries.reversed.toList(),
      );

      final double foxTop = tester
          .getTopLeft(find.byKey(const Key('petTile-$kDefaultPetId')))
          .dy;
      final double phoenixTop = tester
          .getTopLeft(
            find.byKey(const Key('petTile-emoji_u1f426_200d_1f525_lottie')),
          )
          .dy;
      expect(foxTop, lessThan(phoenixTop));

      await unmount(tester);
    });

    testWidgets('every tile shows its rarity label under the pet, owned or '
        'locked, and a seasonal pet always labels "Seasonal" (issue #069)', (
      tester,
    ) async {
      await pumpCollectionScreen(tester);

      // Fox: owned, Common.
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('petRarityLabel-$kDefaultPetId')),
            )
            .data,
        'Common',
      );

      // Crab: locked, Uncommon.
      final rewardLabelKey = Key('petRarityLabel-${_reward.id}');
      await tester.ensureVisible(find.byKey(rewardLabelKey));
      await settle(tester);
      expect(tester.widget<Text>(find.byKey(rewardLabelKey)).data, 'Uncommon');

      // Snowman: locked, but always "Seasonal" rather than "Common".
      const snowmanId = 'emoji_u2603_lottie';
      await tester.ensureVisible(
        find.byKey(const Key('petRarityLabel-$snowmanId')),
      );
      await settle(tester);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('petRarityLabel-$snowmanId')))
            .data,
        'Seasonal',
      );

      await unmount(tester);
    });

    testWidgets('a pet owned more than once shows a "×N" badge; owned '
        'exactly once shows none (issue #069)', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final petRepo = PetRepository(db);
      await petRepo.addOwnedPet(_reward.id);
      await petRepo.addOwnedPet(_reward.id); // crab's count is now 2

      await pumpCollectionScreen(tester, database: db);

      await tester.ensureVisible(find.byKey(Key('petTile-${_reward.id}')));
      await settle(tester);

      expect(find.byKey(Key('petOwnedCount-${_reward.id}')), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
      // Default fox, owned exactly once, shows no badge.
      expect(
        find.byKey(const Key('petOwnedCount-$kDefaultPetId')),
        findsNothing,
      );

      await unmount(tester);
    });
  });
}
