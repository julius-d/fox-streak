// Integration test for issue #112: a multiple-choice question with an image
// shows image + all four options without scrolling on a 360x800 phone, and
// the options block does not move when an option is picked or the result
// is revealed. Driven through the real `LessonScreen` (shell banner and
// bottom button included).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/lesson/lesson_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

import 'helpers.dart';

const _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+A8AAQUAAdafFaMAAAAASUVORK5CYII=';

class _FixedClock extends Clock {
  @override
  DateTime now() => DateTime(2026, 11, 6, 12);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('image + four options fit on 360x800 and stay put on reveal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final setId = await db
        .into(db.questionSets)
        .insert(
          QuestionSetsCompanion.insert(
            title: 'Flags',
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
            prompt: 'Which country is this?',
            answer: 'Peru',
            choices: const Value('["Chile","Bolivia","Brazil"]'),
            position: 0,
            imageType: const Value('base64'),
            imageContent: const Value(_tinyPng),
          ),
        );
    final items = await db.select(db.items).get();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          systemClockProvider.overrideWithValue(_FixedClock()),
          integrationTestSilentSound,
        ],
        child: MaterialApp(
          theme: FoxStreakTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LessonScreen(setId: setId, items: items),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.getRect(
      find.byKey(const Key('foxQuestionImageTapTarget')),
    );
    expect(image.height, greaterThanOrEqualTo(240));

    final check = tester.getRect(find.byKey(const Key('checkButton')));
    Rect option(int i) => tester.getRect(find.byKey(Key('choiceOption$i')));
    for (var i = 0; i < 4; i++) {
      expect(option(i).bottom, lessThanOrEqualTo(check.top));
    }
    final before = [for (var i = 0; i < 4; i++) option(i)];

    await tester.tap(find.text('Peru'));
    await tester.pumpAndSettle();
    expect([for (var i = 0; i < 4; i++) option(i)], before);

    await tester.tap(find.byKey(const Key('checkButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lessonFeedbackBanner')), findsOneWidget);
    expect([for (var i = 0; i < 4; i++) option(i)], before);
  });
}
