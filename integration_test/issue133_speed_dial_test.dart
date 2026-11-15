// Issue #133 — Library "New set" speed-dial on the real app: layout above
// a simulated edge-to-edge nav bar with 2x text, and the staggered open /
// reverse close motion running in real time.
//
// The bottom system inset and text scale are set on the test view (what
// edge-to-edge Android reports), so the overlap regression is guarded
// without an Android device.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/library/set_editor_screen.dart';

import 'helpers.dart';

const _mainFab = Key('newSetFab');
const _scrim = Key('newSetFabScrim');
const _optionsTopFirst = [
  Key('marketplaceFab'),
  Key('importSetFab'),
  Key('newSetMiniFab'),
];
const double _navBar = 48;

double _scaleOf(WidgetTester tester, Key option) => tester
    .widget<ScaleTransition>(
      find
          .ancestor(
            of: find.byKey(option),
            matching: find.byType(ScaleTransition),
          )
          .first,
    )
    .scale
    .value;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'with a 48dp nav bar + 2x text the options pop bottom → top above the '
    'main FAB, close back into it, and "New set" opens the editor',
    (tester) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view
        ..padding = FakeViewPadding(bottom: _navBar * dpr)
        ..viewPadding = FakeViewPadding(bottom: _navBar * dpr);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 11, 15, 9));
      await SetsRepository(
        db,
        clock,
      ).createSet(title: 'Animals', createdBy: 'Tester');
      await pumpFoxStreakApp(tester, db: db, clock: clock);
      await skipOnboardingAndOpenLibrary(tester);

      final collapsed = tester.getRect(find.byKey(_mainFab));
      final screenHeight = tester.view.physicalSize.height / dpr;
      expect(collapsed.bottom, lessThanOrEqualTo(screenHeight - _navBar));

      // Open: sample frames in real time — the lowest option leads.
      await tester.tap(find.byKey(_mainFab));
      var staggered = false;
      var peak = 0.0;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final newSet = _scaleOf(tester, const Key('newSetMiniFab'));
        final marketplace = _scaleOf(tester, const Key('marketplaceFab'));
        if (newSet > marketplace + 0.05) staggered = true;
        peak = math.max(peak, newSet);
      }
      await settle(tester);
      expect(staggered, isTrue, reason: 'options pop bottom → top');
      expect(peak, greaterThan(1.0), reason: 'bouncy overshoot');

      final main = tester.getRect(find.byKey(_mainFab));
      expect(main.size, const Size(56, 56));
      for (final key in _optionsTopFirst) {
        final rect = tester.getRect(find.byKey(key));
        expect(rect.bottom, lessThan(main.top), reason: '$key overlaps FAB');
        expect(_scaleOf(tester, key), 1, reason: '$key');
      }

      // Close via the scrim: reverse animation, back to the exact collapsed
      // FAB.
      await tester.tap(find.byKey(_scrim));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(_scrim), findsOneWidget, reason: 'animating out');
      await settle(tester);
      expect(find.byKey(_scrim), findsNothing);
      expect(tester.getRect(find.byKey(_mainFab)), collapsed);

      // Reopen; the lowest option is fully tappable and opens the editor.
      await tester.tap(find.byKey(_mainFab));
      await settle(tester);
      await tester.tap(find.byKey(const Key('newSetMiniFab')));
      await settle(tester);
      expect(find.byType(SetEditorScreen), findsOneWidget);
    },
  );
}
