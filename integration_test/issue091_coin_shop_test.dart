// Issue #091 — Coin shop: buy streak on ice with coins.
//
// Drives the real app end-to-end: Home's CoinBadge opens CoinShopScreen,
// the buy button is disabled below the fixed price, and confirming a buy
// spends coins + awards a streak freeze (reusing #087's addStreakFreezes),
// visible immediately on both the shop screen and Streak Details.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/shop/coin_shop_screen.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'tapping the coin badge opens the coin shop; the buy button stays '
    'disabled below the fixed price',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 20, 9));
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();
      await statsRepo.addCoins(100);

      await pumpFoxStreakApp(tester, db: db, clock: clock);

      await tester.tap(find.byKey(const Key('coinBadgeButton')));
      await settle(tester);

      expect(find.byKey(const Key('coinShopScreen')), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('No streak on ice yet'), findsOneWidget);
      final button = tester.widget<FoxPrimaryButton>(
        find.byKey(const Key('coinShopBuyButton')),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'confirming a buy spends the fixed price and banks a streak freeze, '
    'visible on both the shop screen and Streak Details',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 20, 9));
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();
      await statsRepo.addCoins(kStreakOnIcePriceCoins);
      // Issue #108 hides Home's streak badge entirely at streakCount == 0,
      // and this test navigates to Streak Details via that badge below —
      // give it an active streak so there's a badge to tap (the streak
      // count itself is incidental to this purchase-flow test).
      await statsRepo.setStreak(
        streakCount: 1,
        lastActiveDay: toLocalDayString(clock.now()),
      );

      await pumpFoxStreakApp(tester, db: db, clock: clock);

      await tester.tap(find.byKey(const Key('coinBadgeButton')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('coinShopBuyButton')));
      await settle(tester);
      expect(find.text('Buy streak on ice?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('coinShopConfirmBuyButton')));
      await settle(tester);

      expect(find.text('You bought a streak on ice! ❄️'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('1 streak on ice'), findsOneWidget);
      final profile = await statsRepo.getProfile();
      expect(profile.coinsTotal, 0);
      expect(profile.streakFreezesAvailable, 1);

      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.byKey(const Key('streakBadgeButton')));
      await settle(tester);
      expect(find.text('1 streak freeze available'), findsOneWidget);
    },
  );
}
