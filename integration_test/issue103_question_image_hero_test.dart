// Issue #103 — Hero animation for the question image expanding full-screen.
//
// Drives the real `LessonScreen`'s Navigator push/pop between the exercise
// card's `FoxQuestionImage` and the `FoxFullScreenImageViewer` it opens —
// not just each widget pumped in isolation, as
// `test/widgets/fox_question_image_test.dart` does — the one thing only a
// real navigation transition can prove: both routes' `Hero`s are briefly
// mounted together during the flight, which is exactly when Flutter throws
// if two Heroes in the same route ever shared a tag (mirrors
// `issue100_pet_hero_test.dart`'s approach for the pet Hero). Also covers
// that reduce motion leaves the same tap-to-expand/collapse flow working
// with no flight at all.

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/lesson/lesson_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

import 'helpers.dart';

const String _kTinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAYAAAD/Rn+7AAAAMElEQVR4nO3OsQ0AAAjDsJ7P1+UKFIYM3p1O+lnogEGDdMCgQTpg0CAdMGiQDhi8ttSp4yqPxYvYAAAAAElFTkSuQmCC';

/// Inserts a one-item choice set whose item has a base64 image, and returns
/// its (real, DB-assigned) setId.
Future<int> _insertImageItemSet(AppDatabase db) async {
  final setId = await db
      .into(db.questionSets)
      .insert(
        QuestionSetsCompanion.insert(
          title: 'Issue 103',
          description: const Value(''),
          createdBy: 'test',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  await db
      .into(db.items)
      .insert(
        ItemsCompanion.insert(
          setId: setId,
          type: 'choice',
          prompt: 'der Hund',
          answer: 'dog',
          choices: const Value('["cat","mouse","bird"]'),
          position: 0,
          imageType: const Value('base64'),
          imageContent: const Value(_kTinyPngBase64),
        ),
      );
  return setId;
}

/// Boots [LessonScreen] directly (mirrors `pumpLessonScreen` in helpers.dart)
/// with OS reduce-motion forced on via a `MediaQuery` wrapper — `helpers.dart`'s
/// `pumpLessonScreen` exposes no builder passthrough for this.
Future<void> _pumpReduceMotionLessonScreen(
  WidgetTester tester, {
  required AppDatabase db,
  required FakeClock clock,
  required int setId,
  required List<Item> items,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
        integrationTestSilentSound,
      ],
      child: MaterialApp(
        theme: FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: app!,
        ),
        home: LessonScreen(
          key: ValueKey(items.map((item) => item.id).join(',')),
          setId: setId,
          items: items,
        ),
      ),
    ),
  );
  await settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'tapping the question image pushes FoxFullScreenImageViewer with both '
    'sides sharing the same Hero tag, and tapping it again pops back '
    '(issue #103)',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 11, 3, 9));

      final setId = await _insertImageItemSet(db);
      final items = await db.select(db.items).get();

      await pumpLessonScreen(
        tester,
        db: db,
        clock: clock,
        setId: setId,
        items: items,
      );
      expect(
        find.byKey(const Key('foxQuestionImageTapTarget')),
        findsOneWidget,
      );
      final cardHero = find.ancestor(
        of: find.byKey(const Key('foxQuestionImageTapTarget')),
        matching: find.byType(Hero),
      );
      expect(cardHero, findsNothing);
      final cardImageHero = find.ancestor(
        of: find.byType(Image),
        matching: find.byType(Hero),
      );
      expect(cardImageHero, findsOneWidget);
      final tag = tester.widget<Hero>(cardImageHero).tag;

      // Mid-flight: both the card's and the full-screen viewer's Heroes are
      // briefly mounted together. A tag collision would throw right here.
      await tester.tap(find.byKey(const Key('foxQuestionImageTapTarget')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);

      await settle(tester);
      expect(find.byKey(const Key('fullScreenImageView')), findsOneWidget);
      final viewerImageHero = find.ancestor(
        of: find.byType(Image),
        matching: find.byType(Hero),
      );
      expect(viewerImageHero, findsOneWidget);
      expect(tester.widget<Hero>(viewerImageHero).tag, tag);

      // Pop back: mid-flight again, then settled on the question card.
      await tester.tap(find.byKey(const Key('fullScreenImageViewTapTarget')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);

      await settle(tester);
      expect(find.byKey(const Key('fullScreenImageView')), findsNothing);
      expect(
        find.byKey(const Key('foxQuestionImageTapTarget')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'with OS reduce motion on, the same tap-to-expand/collapse round trip '
    'still works, with no Hero flight at all (issue #103)',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 11, 3, 9));

      final setId = await _insertImageItemSet(db);
      final items = await db.select(db.items).get();

      await _pumpReduceMotionLessonScreen(
        tester,
        db: db,
        clock: clock,
        setId: setId,
        items: items,
      );
      expect(
        find.byKey(const Key('foxQuestionImageTapTarget')),
        findsOneWidget,
      );
      expect(find.byType(Hero), findsNothing);

      await tester.tap(find.byKey(const Key('foxQuestionImageTapTarget')));
      await settle(tester);
      expect(find.byKey(const Key('fullScreenImageView')), findsOneWidget);
      expect(find.byType(Hero), findsNothing);

      await tester.tap(find.byKey(const Key('fullScreenImageViewTapTarget')));
      await settle(tester);
      expect(find.byKey(const Key('fullScreenImageView')), findsNothing);
      expect(
        find.byKey(const Key('foxQuestionImageTapTarget')),
        findsOneWidget,
      );
    },
  );
}
