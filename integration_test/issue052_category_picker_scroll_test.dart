// Issue #052 — category picker wraps mid-word on narrow phone screens.
//
// Drives the real app end-to-end at a 360dp-wide (smallest common Android
// phone) surface: opens the set editor, scrolls the category picker to
// reach the last ("General") segment that's off-screen at this width,
// selects it, saves, and confirms both that selecting an off-screen
// segment actually works through real scroll gestures and that the saved
// set really persisted that category — not just that the picker renders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations_en.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scrolling the category picker at 360dp width and picking the '
      'off-screen "General" segment saves that category', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 10, 17, 9));
    final l10n = AppLocalizationsEn();

    await pumpFoxStreakApp(tester, db: db, clock: clock);
    await skipOnboardingAndOpenLibrary(tester);

    await openNewSetEditor(tester);

    // "General" is the 4th segment — scrolled out of the visible
    // viewport (not hit-testable) at 360dp until it's scrolled into
    // view, proving the picker is really scrollable (not just
    // narrower) and that scrolled-to segments remain tappable.
    // `SingleChildScrollView` builds its whole child eagerly, so a bare
    // (non-hit-testable-scoped) finder would find it even while
    // off-screen — hence `.hitTestable()` here, not a plain `find`.
    final generalOption = find.byKey(const Key('categoryOption-general'));
    expect(generalOption.hitTestable(), findsNothing);
    await tester.dragUntilVisible(
      generalOption,
      find.byKey(const Key('categoryField')),
      const Offset(-50, 0),
    );
    await settle(tester);
    expect(generalOption.hitTestable(), findsOneWidget);

    await tester.tap(generalOption.hitTestable());
    await settle(tester);

    await tester.enterText(find.byKey(const Key('titleField')), 'Random facts');
    await tester.enterText(find.byKey(const Key('creatorField')), 'Papa');
    await tester.tap(find.byKey(const Key('saveSetButton')));
    await settle(tester);
    expect(listTileWithText('Random facts'), findsOneWidget);

    // Re-open the editor (via rename) and confirm the picker pre-fills
    // from the saved category — proves the off-screen tap actually
    // registered on the scrolled-to segment, not a stale/visible one.
    await tester.tap(setMenuButton('Random facts'));
    await settle(tester);
    await tester.tap(find.text(l10n.rename));
    await settle(tester);
    final segmented = tester.widget<SegmentedButton<String>>(
      find.byKey(const Key('categoryField')),
    );
    expect(segmented.selected, {'general'});
    expect(find.text(l10n.categoryGeneral), findsOneWidget);
  });
}
