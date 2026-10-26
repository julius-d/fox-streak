// Widget tests for the lootbox reveal + pet collection screens
// (issue #059).
//
// NOTE on pumping: do NOT use `pumpAndSettle()` for `PetCollectionScreen`
// — same drift `watch()` fake-async caveat as `library_screen_test.dart`'s
// own `settle()` (it watches `profileProvider`/`ownedPetIdsProvider`).

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

const _reward = PetEntry(
  id: 'emoji_u1f980_lottie',
  assetPath: 'assets/noto-emoji/pet/emoji_u1f980_lottie.json',
  emoji: '🦀',
);
const _petReward = PetReward(_reward);
const _coinsReward = CoinsReward(40);

Future<AppDatabase> pumpCollectionScreen(
  WidgetTester tester, {
  AppDatabase? database,
}) async {
  final db = database ?? AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
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
  });
}
