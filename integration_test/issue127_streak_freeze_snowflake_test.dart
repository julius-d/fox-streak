// Issue #127 — The snowflake is the one icon for a streak freeze.
//
// Drives the real `FoxStreakApp` in light and dark theme: Home's streak
// badge, Streak Details' freeze balance and the coin shop's freeze balance
// all show the same icy-blue Material snowflake (no #108 ice cube left), the
// coin shop copy says "streak freeze" with proper plurals, and the real
// `WheelScreen`'s streak-freeze slice paints the same snowflake glyph in the
// icy slice's contrasting foreground color.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/lesson/wheel_painter.dart';
import 'package:fox_streak_app/src/lesson/wheel_screen.dart';
import 'package:fox_streak_app/src/pet/lootbox_reward.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

import 'helpers.dart';

/// The single snowflake inside the subtree keyed [key].
Finder _snowflakeIn(Key key) => find.descendant(
  of: find.byKey(key),
  matching: find.byIcon(FoxStreakFreezeIcon.iconData),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final (String name, Brightness brightness, ThemeData theme)
      in <(String, Brightness, ThemeData)>[
        ('light', Brightness.light, FoxStreakTheme.light()),
        ('dark', Brightness.dark, FoxStreakTheme.dark()),
      ]) {
    final Color ice = theme.extension<FoxSemanticColors>()!.ice;

    testWidgets(
      'Home badge, Streak Details and coin shop all show the same icy-blue '
      'snowflake for a streak freeze, and the shop says "streak freeze" '
      '($name theme)',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        final db = makeIntegrationTestDb();
        addTearDown(db.close);
        final today = DateTime(2026, 11, 14, 9);
        final clock = FakeClock(today);
        final statsRepo = StatsRepository(db, clock);
        await statsRepo.setOnboarded();
        await statsRepo.addCoins(1000);
        await statsRepo.addStreakFreezes(2);
        final yesterday = toLocalDayString(DateTime(2026, 11, 13));
        final todayDay = toLocalDayString(today);
        await statsRepo.recordDailyActivity(
          day: yesterday,
          xpDelta: 0,
          source: DailyActivitySource.streakOnIce,
        );
        await statsRepo.recordDailyActivity(
          day: todayDay,
          xpDelta: 10,
          source: DailyActivitySource.lessonCompleted,
        );
        await statsRepo.setStreak(streakCount: 2, lastActiveDay: todayDay);

        await pumpFoxStreakApp(tester, db: db, clock: clock);

        // Home: flame for today, snowflake for the frozen day before it.
        final Finder badgeSnowflake = _snowflakeIn(const Key('streakBadge'));
        expect(badgeSnowflake, findsOneWidget);
        expect(tester.widget<Icon>(badgeSnowflake).color, ice);
        expect(
          find.descendant(
            of: find.byKey(const Key('streakBadge')),
            matching: find.byIcon(Icons.local_fire_department),
          ),
          findsOneWidget,
        );

        // Streak Details: snowflake in front of the balance line only.
        await tester.tap(find.byKey(const Key('streakBadgeButton')));
        await settle(tester);
        final Finder detailsSnowflake = find.byIcon(
          FoxStreakFreezeIcon.iconData,
        );
        expect(detailsSnowflake, findsOneWidget);
        expect(tester.widget<Icon>(detailsSnowflake).color, ice);
        expect(find.text('2 streak freezes available'), findsOneWidget);
        expect(
          tester.getCenter(detailsSnowflake).dx,
          lessThan(
            tester
                .getTopLeft(
                  find.byKey(const Key('streakFreezesAvailableLabel')),
                )
                .dx,
          ),
        );
        await tester.pageBack();
        await settle(tester);

        // Coin shop: snowflake + "streak freeze" copy, through a purchase.
        await tester.tap(find.byKey(const Key('coinBadgeButton')));
        await settle(tester);
        final Finder shopSnowflake = _snowflakeIn(const Key('coinShopScreen'));
        expect(shopSnowflake, findsOneWidget);
        expect(tester.widget<Icon>(shopSnowflake).color, ice);
        expect(find.text('2 streak freezes'), findsOneWidget);

        await tester.tap(find.byKey(const Key('coinShopBuyButton')));
        await settle(tester);
        expect(find.text('Buy streak freeze?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('coinShopConfirmBuyButton')));
        await settle(tester);
        expect(find.text('You bought a streak freeze! ❄️'), findsOneWidget);
        expect(find.text('3 streak freezes'), findsOneWidget);
        expect(find.textContaining('on ice'), findsNothing);
      },
    );

    testWidgets(
      "the wheel's streak-freeze slice paints the snowflake glyph in the "
      "icy slice's contrasting color and still lands on it ($name theme)",
      (tester) async {
        const reward = WheelStreakOnIceReward();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: theme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: WheelScreen(reward: reward, l10n: AppLocalizationsEn()),
            ),
          ),
        );
        await tester.pump();

        WheelPainter painter() =>
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byKey(const Key('wheelDial')),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as WheelPainter;
        final int index = kWheelSegments.indexOf(reward);
        final FoxSemanticColors semantics = theme
            .extension<FoxSemanticColors>()!;
        expect(
          painter().labels[index],
          isA<WheelIconLabel>().having(
            (label) => label.icon,
            'icon',
            FoxStreakFreezeIcon.iconData,
          ),
        );
        expect(painter().sliceColors[index], semantics.ice);
        expect(painter().onSliceColors[index], semantics.onIce);

        await tester.tap(find.byKey(const Key('wheelSpinButton')));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(painter().winningIndex, index);
        expect(find.text('You won a streak freeze! ❄️'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
