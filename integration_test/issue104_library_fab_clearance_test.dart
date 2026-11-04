// Issue #104 — Library screen's FAB/system-inset list clearance.
//
// `ListView.builder` pairs with the "New set" FAB; without reserved
// bottom space, the last row's trailing action(s) end up scrolled
// directly underneath the FAB, which — being on top in paint order —
// actually receives a tap aimed at that location instead of the row's
// button. Seeds enough rows to overflow the default (800x600, see
// `macos/Runner/Base.lproj/MainMenu.xib`) desktop window, scrolls the
// list to its end, and taps the last row's play button: if the FAB
// still covers it, the tap lands on the FAB instead (expanding the
// speed-dial) rather than attempting to start a lesson.
//
// Kept as its own file (not alongside the Set Detail / Marketplace
// Sources specs) — running all three `testWidgets` in one process
// reliably hung before the third one; three independent file-per-screen
// runs do not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizationsEn();

  testWidgets(
    'Library: scrolled to the end, the last set\'s play button starts a '
    'lesson instead of hitting the collapsed "New set" FAB',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 17, 9));

      final setsRepo = SetsRepository(db, clock);
      for (var i = 1; i <= 20; i++) {
        await setsRepo.createSet(
          title: 'Set ${i.toString().padLeft(2, '0')}',
          createdBy: 'Tester',
        );
      }

      await pumpFoxStreakApp(tester, db: db, clock: clock);
      await skipOnboardingAndOpenLibrary(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await settle(tester);
      expect(listTileWithText('Set 20'), findsOneWidget);

      await tester.tap(playSetButton('Set 20'));
      await settle(tester);

      // Hitting the FAB instead would expand the speed-dial (scrim shown)
      // rather than attempt to start the (empty) lesson.
      expect(find.byKey(const Key('newSetFabScrim')), findsNothing);
      expect(find.text(l10n.lessonEmptySetNote), findsOneWidget);
    },
  );
}
