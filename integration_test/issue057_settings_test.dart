// Issue #057 — Settings screen: edit daily XP goal + display name.
//
// Drives the real app end-to-end: fresh install -> Home -> overflow menu ->
// Settings -> each new ListTile opens its real edit dialog -> saving writes
// through `StatsRepository` and is reflected immediately in the ListTile's
// subtitle and in Home (greeting, goal ring), without reopening either
// screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Settings display name + daily XP goal: open dialog, edit, save, '
      'reflected in the ListTile subtitle and on Home', (tester) async {
    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 10, 17, 9));

    await pumpFoxStreakApp(tester, db: db, clock: clock);
    await skipOnboardingAndOpenLibrary(tester);
    await tester.pageBack();
    await settle(tester);
    expect(find.byKey(const Key('homeScreen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('homeOverflowMenu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('settingsMenuItem')));
    await settle(tester);
    expect(find.byKey(const Key('settingsScreen')), findsOneWidget);

    final l10n = AppLocalizations.of(
      tester.element(find.byKey(const Key('settingsScreen'))),
    )!;

    // Fresh install: no display name yet, default daily goal is 100 XP.
    final displayNameTile = find.byKey(const Key('displayNameListTile'));
    final dailyGoalTile = find.byKey(const Key('dailyGoalListTile'));
    expect(
      find.descendant(
        of: displayNameTile,
        matching: find.text(l10n.settingsDisplayNameUnset),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dailyGoalTile,
        matching: find.text(l10n.settingsDailyGoalSubtitle(100)),
      ),
      findsOneWidget,
    );

    // --- Display name ---------------------------------------------------
    await tester.tap(displayNameTile);
    await settle(tester);
    final nameField = find.byKey(const Key('settingsDisplayNameField'));
    expect(nameField, findsOneWidget);
    expect(tester.widget<TextField>(nameField).controller!.text, '');

    await tester.enterText(nameField, 'Mia');
    await tester.tap(find.byKey(const Key('settingsSaveDisplayNameButton')));
    await settle(tester);

    expect(find.byKey(const Key('settingsScreen')), findsOneWidget);
    expect(
      find.descendant(of: displayNameTile, matching: find.text('Mia')),
      findsOneWidget,
    );

    // ...and Home's greeting picks it up without reopening Settings.
    await tester.pageBack();
    await settle(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('homeGreeting')),
        matching: find.textContaining('Mia'),
      ),
      findsOneWidget,
    );

    // --- Daily XP goal ---------------------------------------------------
    await tester.tap(find.byKey(const Key('homeOverflowMenu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('settingsMenuItem')));
    await settle(tester);

    await tester.tap(dailyGoalTile);
    await settle(tester);
    final goalField = find.byKey(const Key('settingsDailyGoalField'));
    final goalSaveButton = find.byKey(const Key('settingsSaveDailyGoalButton'));
    expect(tester.widget<TextField>(goalField).controller!.text, '100');
    expect(
      tester.widget<FoxPrimaryButton>(goalSaveButton).onPressed,
      isNotNull,
    );

    // Out-of-range input disables save and shows the validation message.
    await tester.enterText(goalField, '5');
    await settle(tester);
    expect(tester.widget<FoxPrimaryButton>(goalSaveButton).onPressed, isNull);
    expect(find.text(l10n.settingsDailyGoalValidationError), findsOneWidget);

    // Non-numeric input is rejected the same way.
    await tester.enterText(goalField, 'abc');
    await settle(tester);
    expect(tester.widget<FoxPrimaryButton>(goalSaveButton).onPressed, isNull);

    // A valid value re-enables save.
    await tester.enterText(goalField, '250');
    await settle(tester);
    expect(
      tester.widget<FoxPrimaryButton>(goalSaveButton).onPressed,
      isNotNull,
    );
    expect(find.text(l10n.settingsDailyGoalValidationError), findsNothing);

    await tester.tap(goalSaveButton);
    await settle(tester);

    expect(find.byKey(const Key('settingsScreen')), findsOneWidget);
    expect(
      find.descendant(
        of: dailyGoalTile,
        matching: find.text(l10n.settingsDailyGoalSubtitle(250)),
      ),
      findsOneWidget,
    );

    // ...and Home's goal ring targets the new value without reopening
    // Settings.
    await tester.pageBack();
    await settle(tester);
    final ring = tester.widget<FoxGoalRing>(find.byKey(const Key('goalRing')));
    expect(ring.semanticsValue, l10n.homeGoalRingValue(0, 250));
  });
}
