// Issue #055 — Settings screen with haptics + sound toggles, reachable from
// Home's overflow menu, persisted across app restarts.
//
// Drives the real app end-to-end: fresh install -> skip onboarding -> opens
// the real overflow menu (order: "For parents" then "Settings") -> each
// entry opens its real screen -> flipping both switches takes effect
// immediately and persists -> a fresh app launch (same on-device DB, new
// widget tree, simulating a restart) seeds both providers from the
// persisted values on startup, without ever opening `SettingsScreen` again.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/widgets/widgets.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('overflow menu order + navigation, haptics/sound toggles take '
      'effect immediately, and survive a fresh app launch without '
      'reopening Settings', (tester) async {
    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 10, 17, 9));

    await pumpFoxStreakApp(tester, db: db, clock: clock);
    await skipOnboardingAndOpenLibrary(tester);
    // Back to Home.
    await tester.pageBack();
    await settle(tester);
    expect(find.byKey(const Key('homeScreen')), findsOneWidget);

    // Overflow menu shows "For parents" then "Settings", in that order.
    await tester.tap(find.byKey(const Key('homeOverflowMenu')));
    await settle(tester);
    final parentalItem = find.byKey(const Key('parentalInfoMenuItem'));
    final settingsItem = find.byKey(const Key('settingsMenuItem'));
    expect(parentalItem, findsOneWidget);
    expect(settingsItem, findsOneWidget);
    expect(
      tester.getTopLeft(parentalItem).dy,
      lessThan(tester.getTopLeft(settingsItem).dy),
    );

    // "For parents" opens the real ParentalInfoScreen.
    await tester.tap(parentalItem);
    await settle(tester);
    expect(find.byKey(const Key('parentalInfoScreen')), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    // "Settings" opens the real SettingsScreen, haptics on by default.
    await tester.tap(find.byKey(const Key('homeOverflowMenu')));
    await settle(tester);
    await tester.tap(settingsItem);
    await settle(tester);
    expect(find.byKey(const Key('settingsScreen')), findsOneWidget);

    final hapticsSwitch = find.byKey(const Key('hapticsSwitch'));
    final soundSwitch = find.byKey(const Key('soundSwitch'));
    expect(tester.widget<SwitchListTile>(hapticsSwitch).value, isTrue);
    expect(tester.widget<SwitchListTile>(soundSwitch).value, isTrue);
    final container = ProviderScope.containerOf(tester.element(hapticsSwitch));
    expect(container.read(foxHapticsEnabledProvider), isTrue);
    expect(container.read(foxSoundEnabledProvider), isTrue);

    // Toggling off takes effect immediately...
    await tester.tap(hapticsSwitch);
    await tester.tap(soundSwitch);
    await settle(tester);
    expect(tester.widget<SwitchListTile>(hapticsSwitch).value, isFalse);
    expect(tester.widget<SwitchListTile>(soundSwitch).value, isFalse);
    expect(container.read(foxHapticsEnabledProvider), isFalse);
    expect(container.read(foxSoundEnabledProvider), isFalse);

    // ...and back to Home, without ever reopening Settings.
    await tester.pageBack();
    await settle(tester);
    expect(find.byKey(const Key('homeScreen')), findsOneWidget);

    // A fresh app launch (same on-device DB, new widget tree) seeds both
    // providers from the persisted values on startup.
    await pumpFoxStreakApp(tester, db: db, clock: clock);
    expect(find.byKey(const Key('onboardingScreen')), findsNothing);
    expect(find.byKey(const Key('homeScreen')), findsOneWidget);
    expect(find.byKey(const Key('settingsScreen')), findsNothing);
    final relaunchedContainer = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('homeScreen'))),
    );
    expect(relaunchedContainer.read(foxHapticsEnabledProvider), isFalse);
    expect(relaunchedContainer.read(foxSoundEnabledProvider), isFalse);
  });
}
