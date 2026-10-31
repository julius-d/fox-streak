// Integration test for the date/free-text keyboard-stability fix (#092).
//
// Drives the real `LessonScreen` (not a bare card) for both affected
// exercise types on a phone-sized viewport, simulating the Android
// on-screen keyboard via `tester.view.viewInsets` (flutter_test's
// `FakeViewPadding`, no real platform keyboard needed). Proves:
// - the input stays anchored near the top instead of jumping when the
//   simulated keyboard opens,
// - the CHECK button stays visible/tappable above the simulated keyboard,
// - completing the date's year field no longer closes the keyboard
//   (focus stays put).

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/database.dart';

import 'helpers.dart';

const _phoneSize = Size(360, 780);
const _simulatedKeyboardHeight = 300.0;

/// Inserts a one-item set of [type] and returns its (real, DB-assigned)
/// setId — `LessonController.submitGrade` records an `attempts` row with a
/// foreign key on `item_id`, so the lesson's items must be real rows, not
/// synthetic `Item` values with a made-up id.
Future<int> _insertSingleItemSet(
  AppDatabase db, {
  required String type,
  required String prompt,
  required String answer,
}) async {
  final setId = await db
      .into(db.questionSets)
      .insert(
        QuestionSetsCompanion.insert(
          title: 'Issue 092',
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
          type: type,
          prompt: prompt,
          answer: answer,
          position: 0,
        ),
      );
  return setId;
}

/// Boots a one-item lesson of [itemType] on a phone-sized viewport, asserts
/// [inputKey]'s top position barely moves once the keyboard opens (not a
/// centered-then-jumps layout) and that CHECK stays reachable above the
/// simulated keyboard, then lets [answerAndCheck] fill in the answer and
/// tap CHECK, landing on the feedback banner.
Future<void> _verifyInputStaysStableAcrossKeyboardOpen(
  WidgetTester tester, {
  required String itemType,
  required String prompt,
  required String answer,
  required Key inputKey,
  required Future<void> Function(WidgetTester tester) answerAndCheck,
}) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });

  final db = makeIntegrationTestDb();
  addTearDown(db.close);
  final clock = FakeClock(DateTime(2026, 10, 31, 9));

  final setId = await _insertSingleItemSet(
    db,
    type: itemType,
    prompt: prompt,
    answer: answer,
  );
  final items = await db.select(db.items).get();

  await pumpLessonScreen(
    tester,
    db: db,
    clock: clock,
    setId: setId,
    items: items,
  );

  final topBefore = tester.getTopLeft(find.byKey(inputKey)).dy;
  final checkBottomBefore = tester
      .getBottomRight(find.byKey(const Key('checkButton')))
      .dy;
  // Anchored near the top, not vertically centered on a 780-tall view.
  expect(topBefore, lessThan(300));

  tester.view.viewInsets = const FakeViewPadding(
    bottom: _simulatedKeyboardHeight,
  );
  await tester.pumpAndSettle();

  final topAfter = tester.getTopLeft(find.byKey(inputKey)).dy;
  final checkBottomAfter = tester
      .getBottomRight(find.byKey(const Key('checkButton')))
      .dy;

  // The input doesn't jump once the keyboard opens.
  expect((topAfter - topBefore).abs(), lessThan(5));
  // CHECK stays above the simulated keyboard, below where it started.
  expect(
    checkBottomAfter,
    lessThanOrEqualTo(_phoneSize.height - _simulatedKeyboardHeight),
  );
  expect(checkBottomBefore, greaterThan(checkBottomAfter));

  await answerAndCheck(tester);

  // CHECK is now enabled and tappable above the (still open) keyboard.
  await tester.tap(find.byKey(const Key('checkButton')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('lessonFeedbackBanner')), findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'date exercise: input stays near the top and CHECK stays reachable '
    'when the keyboard opens; completing the year keeps focus',
    (tester) async {
      await _verifyInputStaysStableAcrossKeyboardOpen(
        tester,
        itemType: 'date',
        prompt: "Mama's birthday",
        answer: '1985-05-14',
        inputKey: const Key('dateExerciseCard'),
        answerAndCheck: (tester) async {
          await tester.enterText(
            find.byKey(const Key('dateExerciseMonthField')),
            '05',
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('dateExerciseDayField')),
            '14',
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('dateExerciseYearField')),
            '1985',
          );
          await tester.pumpAndSettle();

          // Completing the year field keeps focus (keyboard stays open).
          expect(
            tester.binding.focusManager.primaryFocus?.debugLabel,
            'dateExerciseYear',
          );
        },
      );
    },
  );

  testWidgets('free-text exercise: input stays near the top and CHECK stays '
      'reachable when the keyboard opens', (tester) async {
    await _verifyInputStaysStableAcrossKeyboardOpen(
      tester,
      itemType: 'freeText',
      prompt: 'dog',
      answer: 'Hund',
      inputKey: const Key('freeTextAnswerField'),
      answerAndCheck: (tester) async {
        await tester.enterText(
          find.byKey(const Key('freeTextAnswerField')),
          'Hund',
        );
        await tester.pumpAndSettle();
      },
    );
  });
}
