// Issue #104 — Marketplace Sources screen's FAB/system-inset list clearance.
//
// `ListView.builder` pairs with the "Add source" FAB; without reserved
// bottom space, the last row's trailing action ends up scrolled directly
// underneath the FAB, which — being on top in paint order — actually
// receives a tap aimed at that location instead of the row's button.
// Seeds enough sources to overflow the default (800x600, see
// `macos/Runner/Base.lproj/MainMenu.xib`) desktop window, scrolls the
// list to its end, and taps the last source's delete button: if the FAB
// still covers it, the tap lands on the FAB instead (opening its own
// add-source dialog) rather than this remove-confirm dialog.
//
// Kept as its own file — see `issue104_library_fab_clearance_test.dart`'s
// header for why this isn't bundled with the other two #104 specs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/data/marketplace_repository.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizationsEn();

  testWidgets(
    'Marketplace Sources: scrolled to the end, the last source\'s delete '
    'button opens its confirm dialog instead of hitting the "Add source" FAB',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 17, 9));

      final setsRepo = SetsRepository(db, clock);
      final marketplaceRepo = MarketplaceRepository(db, setsRepo);
      for (var i = 1; i <= 20; i++) {
        final label = i.toString().padLeft(2, '0');
        await marketplaceRepo.addSource(
          url: 'https://example.com/source$label',
          name: 'Source $label',
        );
      }

      await pumpFoxStreakApp(tester, db: db, clock: clock);
      await skipOnboardingAndOpenLibrary(tester);
      await tester.tap(find.byKey(const Key('newSetFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('marketplaceFab')));
      await settle(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await settle(tester);
      expect(listTileWithText('Source 20'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: listTileWithText('Source 20'),
          matching: find.byIcon(Icons.delete_outline),
        ),
      );
      await settle(tester);

      // Hitting "Add source" instead would open its own add dialog rather
      // than this remove-confirm dialog.
      expect(find.text(l10n.marketplaceRemoveSourceTitle), findsOneWidget);
      await tester.tap(find.text(l10n.marketplaceRemoveSourceAction));
      await settle(tester);

      // `ListView.builder` only mounts visible rows, so after scrolling to
      // the end only the (new) last row — not the first — is guaranteed
      // to still be built here.
      expect(listTileWithText('Source 20'), findsNothing);
      expect(listTileWithText('Source 19'), findsOneWidget);
    },
  );
}
