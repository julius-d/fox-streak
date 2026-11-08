// Integration test for the slim lesson top row (issue #119).
//
// Drives the real `LessonScreen` with the real `MultipleChoiceCard`: no
// title, and the progress bar and three-dots menu sit on one row that stays
// put between the answering and feedback states.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('title-less lesson top row stays put across lesson states', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 10, 12, 9));

    final setId = await db
        .into(db.questionSets)
        .insert(
          QuestionSetsCompanion.insert(
            title: 'Animals',
            description: const Value(''),
            createdBy: 'test',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    final items = <Item>[];
    for (final (prompt, answer, position) in [
      ('der Hund', 'dog', 0),
      ('die Katze', 'cat', 1),
    ]) {
      final id = await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              setId: setId,
              type: 'choice',
              prompt: prompt,
              answer: answer,
              position: position,
            ),
          );
      items.add(
        Item(
          id: id,
          setId: setId,
          type: 'choice',
          prompt: prompt,
          answer: answer,
          position: position,
        ),
      );
    }

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
          locale: const Locale('en'),
          home: LessonScreen(setId: setId, items: items),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Rect rect(String key) => tester.getRect(find.byKey(Key(key)));

    expect(find.text('Lesson'), findsNothing);
    expect(find.byType(AppBar), findsNothing);

    final bar = rect('lessonProgressBar');
    final menu = rect('lessonOverflowMenu');
    expect(menu.height, greaterThanOrEqualTo(48));
    expect(bar.center.dy, closeTo(menu.center.dy, 0.5));
    expect(bar.right, lessThanOrEqualTo(menu.left));

    final shown = [
      'dog',
      'cat',
    ].firstWhere((a) => find.text(a).evaluate().isNotEmpty);
    await tester.tap(find.text(shown));
    await tester.pump();
    await tester.tap(find.byKey(const Key('checkButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lessonFeedbackBanner')), findsOneWidget);

    expect(rect('lessonOverflowMenu'), menu);
    expect(rect('lessonProgressBar').top, bar.top);
    expect(rect('lessonProgressBar').left, bar.left);
  });
}
