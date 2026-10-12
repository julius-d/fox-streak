// Widget tests for the dial pad exercise card (issue #008 regression,
// added alongside #009's hintUsed plumbing fix).
//
// Covers the one bit of behavior that had no test anywhere in the repo:
// the reveal-hint eye icon sets ExerciseDraft.hintUsed, and it stays true
// after the 2s auto-hide (sticky for the lifetime of the card/item), so
// the lesson controller can copy it onto the recorded outcome.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/exercises/dial_pad_exercise.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

const Item _phoneItem = Item(
  id: 1,
  setId: 1,
  type: 'phone',
  prompt: 'Mama',
  answer: '017112345678',
  position: 0,
);

Future<void> pumpDialPad(
  WidgetTester tester, {
  required void Function(ExerciseDraft) onDraft,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: buildDialPadExercise(
            item: _phoneItem,
            l10n: AppLocalizationsEn(),
            onStateChanged: onDraft,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('hintUsed stays false until the reveal-hint eye icon is tapped', (
    tester,
  ) async {
    ExerciseDraft? draft;
    await pumpDialPad(tester, onDraft: (d) => draft = d);

    await tester.tap(find.byKey(const Key('dialPadKey1')));
    await tester.pump();
    expect(draft!.hintUsed, isFalse);
  });

  testWidgets(
    'tapping reveal-hint sets hintUsed and keeps it true after auto-hide',
    (tester) async {
      ExerciseDraft? draft;
      await pumpDialPad(tester, onDraft: (d) => draft = d);

      await tester.tap(find.byKey(const Key('dialPadRevealHint')));
      await tester.pump();
      expect(draft!.hintUsed, isTrue);

      // Auto-hides after 2 seconds, but hintUsed is sticky for this item.
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byKey(const Key('dialPadKey1')));
      await tester.pump();
      expect(draft!.hintUsed, isTrue);
    },
  );
}
