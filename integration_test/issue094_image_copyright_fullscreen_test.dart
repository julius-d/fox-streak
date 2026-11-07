// Issue #094 — image copyright caption + tap-to-expand full-screen view.
//
// Drives the real app: creates a set, adds a choice item with a base64
// image + copyright via the real item editor's new copyright field. The
// caption + tap-to-expand are question-card-only (`FoxQuestionImage`): the
// set detail row keeps the small, square, non-interactive `FoxItemImage`
// thumbnail unchanged (#014) — no caption there, since Material's
// `ListTile.leading` can't fit a thumbnail-sized image plus a caption bar.
// This test asserts the caption renders on the real lesson exercise card,
// and that tapping the real image there opens the real full-screen viewer,
// which then closes again on tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

const String _kTinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAYAAAD/Rn+7AAAAMElEQVR4nO3OsQ0AAAjDsJ7P1+UKFIYM3p1O+lnogEGDdMCgQTpg0CAdMGiQDhi8ttSp4yqPxYvYAAAAAElFTkSuQmCC';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a base64 image + copyright saved via the item editor shows no caption '
    'on the set detail thumbnail, but shows it on the lesson exercise card '
    '— tapping the real image there opens the full-screen viewer',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 17, 9));

      await pumpFoxStreakApp(tester, db: db, clock: clock);
      await skipOnboardingAndOpenLibrary(tester);

      await openNewSetEditor(tester);
      await tester.enterText(find.byKey(const Key('titleField')), 'Animals');
      await tester.enterText(find.byKey(const Key('creatorField')), 'Mama');
      await tester.tap(find.byKey(const Key('saveSetButton')));
      await settle(tester);
      await openSetDetail(tester, 'Animals');

      await tester.tap(find.byKey(const Key('addItemFab')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('itemPromptField')), 'Hund');
      await tester.enterText(find.byKey(const Key('itemAnswerField')), 'dog');
      await tester.tap(find.byKey(const Key('itemImageTypeField')));
      await settle(tester);
      await tester.tap(find.text('Base64 image').last);
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('itemImageContentField')),
        _kTinyPngBase64,
      );
      await tester.enterText(
        find.byKey(const Key('itemImageCopyrightField')),
        '© Jane Doe',
      );
      await tester.ensureVisible(find.byKey(const Key('saveItemButton')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);

      // Set detail: the small thumbnail renders (via FoxItemImage), but no
      // caption bar — doesn't fit a ListTile leading — and tapping it does
      // nothing (no tap target wired up, unlike the question-card image).
      expect(find.text('© Jane Doe'), findsNothing);
      await tester.tap(find.byType(FoxItemImage));
      await settle(tester);
      expect(find.byKey(const Key('fullScreenImageView')), findsNothing);

      // Lesson: the caption renders above the prompt on the real exercise
      // card, and tapping the real image opens the real full-screen viewer,
      // which closes again on tap.
      await tester.tap(find.byKey(const Key('startLessonFab')));
      await settle(tester);
      expect(find.text('© Jane Doe'), findsOneWidget);

      await tester.tap(find.byKey(const Key('foxQuestionImageTapTarget')));
      await settle(tester);
      expect(find.byKey(const Key('fullScreenImageView')), findsOneWidget);
      expect(find.text('© Jane Doe'), findsOneWidget);

      // #113: gallery-style full screen — question above the image, the
      // note directly under it, white close button top-left.
      expect(
        tester
            .widget<Scaffold>(find.byKey(const Key('fullScreenImageView')))
            .backgroundColor,
        Colors.black,
      );
      expect(
        find.byKey(const Key('fullScreenImageViewQuestion')),
        findsOneWidget,
      );
      final image = tester.getRect(find.byType(Image));
      final caption = tester.getRect(
        find.byKey(const Key('foxItemImageCaption')),
      );
      expect(caption.right, closeTo(image.right, 0.5));
      expect(caption.top, closeTo(image.bottom, 0.5));

      await tester.tap(find.byKey(const Key('fullScreenImageViewClose')));
      await settle(tester);
      expect(find.byKey(const Key('fullScreenImageView')), findsNothing);

      await tester.tap(find.byKey(const Key('foxQuestionImageTapTarget')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('fullScreenImageViewTapTarget')));
      await settle(tester);
      expect(find.byKey(const Key('fullScreenImageView')), findsNothing);
    },
  );
}
