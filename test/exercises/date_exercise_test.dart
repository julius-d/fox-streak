// Widget tests for the date exercise card (issue #009).
//
// Pumps `DateExercise` directly (no DB access needed — it only grades
// against the given item's stored answer). Covers: leap-year grading,
// ISO zero-padding, auto-advance + backspace-back, CHECK disabled until
// all 3 fields are filled, hint reveal sets hintUsed, and the
// correctAnswerLabel is always locale-formatted (never raw ISO).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/exercises/date_exercise.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

/// Records calls instead of touching a real platform audio channel
/// (issue #054 regression guard).
class _FakeSoundPlayer implements FoxSoundPlayer {
  int playCorrectCallCount = 0;
  int playLevelUpCallCount = 0;

  @override
  Future<void> playCorrect() async {
    playCorrectCallCount++;
  }

  @override
  Future<void> playLevelUp() async {
    playLevelUpCallCount++;
  }
}

Item _dateItem({
  String answer = '1985-05-14',
  String prompt = "Mama's birthday",
}) {
  return Item(
    id: 1,
    setId: 1,
    type: 'date',
    prompt: prompt,
    answer: answer,
    position: 0,
  );
}

Future<void> pumpDateExercise(
  WidgetTester tester, {
  required Item item,
  Locale locale = const Locale('en'),
  void Function(ExerciseDraft)? onDraft,
  FoxSoundPlayer? soundPlayer,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        foxSoundPlayerProvider.overrideWithValue(
          soundPlayer ?? _FakeSoundPlayer(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        theme: FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: buildDateExercise(
            item: item,
            l10n: AppLocalizationsEn(),
            onStateChanged: (draft) => onDraft?.call(draft),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

String? focusedLabel(WidgetTester tester) =>
    tester.binding.focusManager.primaryFocus?.debugLabel;

void main() {
  testWidgets('CHECK disabled until all 3 fields are filled', (tester) async {
    ExerciseDraft? draft;
    await pumpDateExercise(
      tester,
      item: _dateItem(),
      onDraft: (d) => draft = d,
    );
    expect(draft, isNull);

    await tester.enterText(
      find.byKey(const Key('dateExerciseMonthField')),
      '05',
    );
    await tester.pump();
    expect(draft!.hasAnswer, isFalse);

    await tester.enterText(find.byKey(const Key('dateExerciseDayField')), '14');
    await tester.pump();
    expect(draft!.hasAnswer, isFalse);

    await tester.enterText(
      find.byKey(const Key('dateExerciseYearField')),
      '1985',
    );
    await tester.pump();
    expect(draft!.hasAnswer, isTrue);
  });

  testWidgets(
    'ISO zero-padding: single-digit day/month still grades correctly',
    (tester) async {
      ExerciseDraft? draft;
      await pumpDateExercise(
        tester,
        item: _dateItem(answer: '1985-05-04'),
        onDraft: (d) => draft = d,
      );

      await tester.enterText(
        find.byKey(const Key('dateExerciseMonthField')),
        '5',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('dateExerciseDayField')),
        '4',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('dateExerciseYearField')),
        '1985',
      );
      await tester.pump();

      expect(draft!.hasAnswer, isTrue);
      expect(draft!.grade(), isTrue);
    },
  );

  testWidgets('leap-year date grades correctly', (tester) async {
    ExerciseDraft? draft;
    await pumpDateExercise(
      tester,
      item: _dateItem(answer: '2024-02-29'),
      onDraft: (d) => draft = d,
    );

    await tester.enterText(
      find.byKey(const Key('dateExerciseMonthField')),
      '02',
    );
    await tester.pump();
    await tester.enterText(find.byKey(const Key('dateExerciseDayField')), '29');
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('dateExerciseYearField')),
      '2024',
    );
    await tester.pump();

    expect(draft!.grade(), isTrue);
  });

  testWidgets('wrong date grades false', (tester) async {
    ExerciseDraft? draft;
    await pumpDateExercise(
      tester,
      item: _dateItem(answer: '1985-05-14'),
      onDraft: (d) => draft = d,
    );

    await tester.enterText(
      find.byKey(const Key('dateExerciseMonthField')),
      '01',
    );
    await tester.pump();
    await tester.enterText(find.byKey(const Key('dateExerciseDayField')), '01');
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('dateExerciseYearField')),
      '2000',
    );
    await tester.pump();

    expect(draft!.grade(), isFalse);
  });

  testWidgets(
    'auto-advance to next field and backspace-back (EN month first)',
    (tester) async {
      await pumpDateExercise(tester, item: _dateItem());

      await tester.enterText(
        find.byKey(const Key('dateExerciseMonthField')),
        '05',
      );
      await tester.pump();
      expect(focusedLabel(tester), 'dateExerciseDay');

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(focusedLabel(tester), 'dateExerciseMonth');
    },
  );

  testWidgets('auto-advance order is day-month-year for German locale', (
    tester,
  ) async {
    await pumpDateExercise(
      tester,
      item: _dateItem(),
      locale: const Locale('de'),
    );

    await tester.enterText(find.byKey(const Key('dateExerciseDayField')), '14');
    await tester.pump();
    expect(focusedLabel(tester), 'dateExerciseMonth');
  });

  testWidgets('hint reveal shows formatted date and sets hintUsed', (
    tester,
  ) async {
    ExerciseDraft? draft;
    final fakeSoundPlayer = _FakeSoundPlayer();
    await pumpDateExercise(
      tester,
      item: _dateItem(answer: '1985-05-14'),
      onDraft: (d) => draft = d,
      soundPlayer: fakeSoundPlayer,
    );

    expect(draft, isNull);
    await tester.tap(find.byKey(const Key('dateExerciseHintButton')));
    await tester.pump();

    expect(draft!.hintUsed, isTrue);
    expect(find.text('05/14/1985'), findsOneWidget);
    // Regression: #054 scope — reveal-hint only reuses FoxFeedback.success
    // for its haptic, not a graded answer, so it must never play the
    // correct-answer chime.
    expect(fakeSoundPlayer.playCorrectCallCount, 0);

    // Auto-hides after 2 seconds, but hintUsed stays true for this item.
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('dateExerciseHintButton')), findsOneWidget);
    expect(draft!.hintUsed, isTrue);
  });

  testWidgets('correctAnswerLabel is always locale-formatted, never raw ISO', (
    tester,
  ) async {
    ExerciseDraft? draftEn;
    await pumpDateExercise(
      tester,
      item: _dateItem(answer: '1985-05-14'),
      onDraft: (d) => draftEn = d,
    );
    await tester.enterText(
      find.byKey(const Key('dateExerciseMonthField')),
      '05',
    );
    await tester.pump();
    expect(draftEn!.correctAnswerLabel, '05/14/1985');
    expect(draftEn!.correctAnswerLabel, isNot(contains('1985-05-14')));

    ExerciseDraft? draftDe;
    await pumpDateExercise(
      tester,
      item: _dateItem(answer: '1985-05-14'),
      locale: const Locale('de'),
      onDraft: (d) => draftDe = d,
    );
    await tester.enterText(find.byKey(const Key('dateExerciseDayField')), '14');
    await tester.pump();
    expect(draftDe!.correctAnswerLabel, '14.05.1985');
  });
}
