// Widget tests for CoinShopScreen (issue #091): disabled/enabled buy-button
// states, the confirm/cancel buy flow, and that a successful buy spends
// coins + awards a streak freeze (reusing #087's addStreakFreezes).
//
// NOTE on pumping: bounded `settle()` instead of `pumpAndSettle()` — same
// drift `watch()`-under-fake-async caveat as `test/home/home_screen_test.dart`
// (this screen watches `profileProvider` directly).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/shop/coin_shop_screen.dart';
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

Future<AppDatabase> pumpCoinShop(
  WidgetTester tester,
  FakeClock clock, {
  Future<void> Function(StatsRepository stats)? seed,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
  if (seed != null) {
    await seed(StatsRepository(db, clock));
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
      ],
      child: MaterialApp(
        theme: FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CoinShopScreen(),
      ),
    ),
  );
  await settle(tester);
  return db;
}

void main() {
  testWidgets(
    'buy button is disabled when coinsTotal is below the price (issue #091)',
    (tester) async {
      final clock = FakeClock(kTestToday);
      await pumpCoinShop(tester, clock, seed: (stats) => stats.addCoins(100));

      final button = tester.widget<FoxPrimaryButton>(
        find.byKey(const Key('coinShopBuyButton')),
      );
      expect(button.onPressed, isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'buy button is enabled once coinsTotal reaches the price (issue #091)',
    (tester) async {
      final clock = FakeClock(kTestToday);
      await pumpCoinShop(
        tester,
        clock,
        seed: (stats) => stats.addCoins(kStreakOnIcePriceCoins),
      );

      final button = tester.widget<FoxPrimaryButton>(
        find.byKey(const Key('coinShopBuyButton')),
      );
      expect(button.onPressed, isNotNull);
      await unmount(tester);
    },
  );

  testWidgets('cancelling the confirm dialog spends nothing (issue #091)', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    final db = await pumpCoinShop(
      tester,
      clock,
      seed: (stats) => stats.addCoins(kStreakOnIcePriceCoins),
    );

    await tester.tap(find.byKey(const Key('coinShopBuyButton')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('coinShopCancelBuyButton')));
    await settle(tester);

    final repo = StatsRepository(db, clock);
    final profile = await repo.getProfile();
    expect(profile.coinsTotal, kStreakOnIcePriceCoins);
    expect(profile.streakFreezesAvailable, 0);
    expect(
      find.byKey(const Key('coinShopPurchaseSuccessBanner')),
      findsNothing,
    );
    await unmount(tester);
  });

  testWidgets('confirming the buy dialog spends the fixed price and awards one '
      'streak on ice, then shows a success banner; buying again stays '
      'possible while affordable (issue #091)', (tester) async {
    final clock = FakeClock(kTestToday);
    final db = await pumpCoinShop(
      tester,
      clock,
      seed: (stats) => stats.addCoins(kStreakOnIcePriceCoins * 2),
    );
    final repo = StatsRepository(db, clock);

    await tester.tap(find.byKey(const Key('coinShopBuyButton')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('coinShopConfirmBuyButton')));
    await settle(tester);

    var profile = await repo.getProfile();
    expect(profile.coinsTotal, kStreakOnIcePriceCoins);
    expect(profile.streakFreezesAvailable, 1);
    expect(
      find.byKey(const Key('coinShopPurchaseSuccessBanner')),
      findsOneWidget,
    );

    final button = tester.widget<FoxPrimaryButton>(
      find.byKey(const Key('coinShopBuyButton')),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('coinShopBuyButton')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('coinShopConfirmBuyButton')));
    await settle(tester);

    profile = await repo.getProfile();
    expect(profile.coinsTotal, 0);
    expect(profile.streakFreezesAvailable, 2);
    await unmount(tester);
  });
}
