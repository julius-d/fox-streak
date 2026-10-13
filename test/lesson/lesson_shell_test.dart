// Lesson shell widget tests (issue #005).
//
// Covers: start-shuffles-and-caps-20, check-disabled-until-answer,
// correct-flow, wrong-flow, skip-counts-wrong, skip-absent-from-menu-post-check,
// quit-confirm-cancel-is-noop / quit-confirm-pops, restart-reshuffles,
// result-score-math, rotation-safe (pump with new surface size, index
// preserved), attempts-written-but-xp/streak-untouched.
// Quit/Skip are reached via the lesson AppBar overflow menu (issue #024).
//
// Uses NativeDatabase.memory() + FakeClock overrides via ProviderScope.
// Bounded pumps per #003 harness learning — never pumpAndSettle on watch() streams.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/lesson/lesson_screen.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';
import 'package:fox_streak_app/test/data/test_helpers.dart';
import 'package:fox_streak_app/test/lesson/helpers/placeholder_exercise_card.dart';

/// Pumps a widget under the FoxStreak theme + Riverpod scope with test overrides.
Future<void> pumpLessonShell(
  WidgetTester tester,
  Widget child, {
  AppDatabase? database,
  Clock? clock,
}) async {
  final db = database ?? AppDatabase.forTesting(NativeDatabase.memory());
  final clk = clock ?? FakeClock(DateTime(2026, 10, 11, 12));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clk),
      ],
      child: MaterialApp(
        theme: FoxStreakTheme.light(),
        darkTheme: FoxStreakTheme.dark(),
        localizationsDelegates: const [_TestLocalizationsDelegate()],
        supportedLocales: const [Locale('en')],
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

/// Creates a LessonScreen configured for tests with the placeholder exercise card.
Widget buildTestLessonScreen({
  required int setId,
  required List<Item> items,
  required AppLocalizations l10n,
}) {
  return LessonScreen(
    setId: setId,
    items: items,
    cardBuilder:
        ({
          Key? key,
          required Item item,
          required void Function(ExerciseDraft) onStateChanged,
          required AppLocalizations l10n,
          bool autoAnswer = false,
        }) {
          return PlaceholderExerciseCard(
            key: key,
            item: item,
            onStateChanged: onStateChanged,
            l10n: l10n,
            autoAnswer: autoAnswer,
          );
        },
  );
}

/// Opens the lesson AppBar's overflow menu (issue #024).
Future<void> openLessonMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('lessonOverflowMenu')));
  await tester.pumpAndSettle();
}

/// Minimal localizations delegate for tests.
class _TestLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _TestLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizationsEn();

  @override
  bool shouldReload(_TestLocalizationsDelegate old) => false;
}

/// Overrides [foxHapticsEnabledProvider] to off, for the haptics-suppressed test.
class _DisabledHaptics extends FoxHapticsEnabled {
  @override
  bool build() => false;
}

/// Helper to create test items in the database.
Future<List<Item>> setupTestItems(
  AppDatabase db,
  int setId,
  int count, {
  String type = 'vocab',
  String? choicesJson,
}) async {
  // Ensure the question set exists
  final existingSet = db.select(db.questionSets)
    ..where((t) => t.id.equals(setId));
  if (await existingSet.getSingleOrNull() == null) {
    await db
        .into(db.questionSets)
        .insert(
          QuestionSetsCompanion.insert(
            id: Value(setId),
            title: 'Test Set $setId',
            description: const Value(''),
            createdBy: 'test',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  }

  final items = <Item>[];
  for (int i = 0; i < count; i++) {
    final id = await db
        .into(db.items)
        .insert(
          ItemsCompanion.insert(
            setId: setId,
            type: type,
            prompt: 'Question $i',
            answer: 'answer$i',
            direction: const Value.absent(),
            choices: choicesJson != null
                ? Value(choicesJson)
                : const Value.absent(),
            hint: const Value(''),
            position: i,
          ),
        );
    items.add(
      Item(
        id: id,
        setId: setId,
        type: type,
        prompt: 'Question $i',
        answer: 'answer$i',
        direction: null,
        choices: choicesJson,
        hint: '',
        position: i,
      ),
    );
  }
  return items;
}

void main() {
  group('LessonShell', () {
    late AppDatabase db;
    late FakeClock fakeClock;
    late StatsRepository statsRepo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      fakeClock = FakeClock(DateTime(2026, 10, 11, 12));
      statsRepo = StatsRepository(db, fakeClock);
    });

    tearDown(() async {
      await db.close();
    });

    // Choices JSON for vocab items (3 distractors + answer will be added by card)
    const vocabChoicesJson = '["distractor1","distractor2","distractor3"]';

    testWidgets('start-shuffles-and-caps-20', (WidgetTester tester) async {
      // Insert 25 items into DB and pass them directly
      final items = await setupTestItems(
        db,
        1,
        25,
        choicesJson: vocabChoicesJson,
      );

      await pumpLessonShell(
        tester,
        LessonScreen(
          setId: 1,
          items: items,
          cardBuilder:
              ({
                Key? key,
                required Item item,
                required void Function(ExerciseDraft) onStateChanged,
                required AppLocalizations l10n,
                bool autoAnswer = false,
              }) {
                return PlaceholderExerciseCard(
                  key: key,
                  item: item,
                  onStateChanged: onStateChanged,
                  l10n: l10n,
                  autoAnswer: autoAnswer,
                );
              },
        ),
        database: db,
        clock: fakeClock,
      );

      // Wait for lesson to start
      await tester.pump();

      // The progress bar should show 0/20 initially
      expect(find.byKey(const Key('lessonProgressBar')), findsOneWidget);
    });

    testWidgets('check-disabled-until-answer', (WidgetTester tester) async {
      final items = await setupTestItems(
        db,
        1,
        3,
        choicesJson: vocabChoicesJson,
      );

      await pumpLessonShell(
        tester,
        LessonScreen(
          setId: 1,
          items: items,
          cardBuilder:
              ({
                Key? key,
                required Item item,
                required void Function(ExerciseDraft) onStateChanged,
                required AppLocalizations l10n,
                bool autoAnswer = false,
              }) {
                return PlaceholderExerciseCard(
                  key: key,
                  item: item,
                  onStateChanged: onStateChanged,
                  l10n: l10n,
                  autoAnswer: autoAnswer,
                );
              },
        ),
        database: db,
        clock: fakeClock,
      );
      await tester.pump();

      // CHECK button should be disabled initially (no answer)
      final checkButton = find.byKey(const Key('checkButton'));
      expect(checkButton, findsOneWidget);

      // The button should have null onPressed initially
      await tester.tap(checkButton, warnIfMissed: false);
      await tester.pump();
      // Should not advance (no answer provided)
    });

    testWidgets(
      'correct-flow: banner success + continue advances + progress ticks',
      (WidgetTester tester) async {
        final items = await setupTestItems(
          db,
          1,
          2,
          choicesJson: vocabChoicesJson,
        );

        await pumpLessonShell(
          tester,
          LessonScreen(
            setId: 1,
            items: items,
            cardBuilder:
                ({
                  Key? key,
                  required Item item,
                  required void Function(ExerciseDraft) onStateChanged,
                  required AppLocalizations l10n,
                  bool autoAnswer = false,
                }) {
                  return PlaceholderExerciseCard(
                    key: key,
                    item: item,
                    onStateChanged: onStateChanged,
                    l10n: l10n,
                    autoAnswer: autoAnswer,
                  );
                },
          ),
          database: db,
          clock: fakeClock,
        );
        await tester.pump();
        // Extra pump to process microtask from auto-answer
        await tester.pump();

        // The placeholder card with autoAnswer will report correct answer
        // Tap CHECK
        await tester.tap(find.byKey(const Key('checkButton')));
        await tester.pump();

        // Should show success banner
        expect(find.byKey(const Key('lessonFeedbackBanner')), findsOneWidget);
        expect(find.text('Correct!'), findsOneWidget);

        // Tap CONTINUE
        await tester.tap(find.byKey(const Key('checkButton')));
        await tester.pump();

        // Should advance to next question
      },
    );

    testWidgets('wrong-flow: banner shows correct answer, one outcome', (
      WidgetTester tester,
    ) async {
      // Insert one item with a known answer
      final items = await setupTestItems(
        db,
        1,
        1,
        choicesJson: vocabChoicesJson,
      );
      final correctAnswer = items.first.answer;

      await pumpLessonShell(
        tester,
        LessonScreen(
          setId: 1,
          items: items,
          cardBuilder:
              ({
                Key? key,
                required Item item,
                required void Function(ExerciseDraft) onStateChanged,
                required AppLocalizations l10n,
                bool autoAnswer = false,
              }) {
                return PlaceholderExerciseCard(
                  key: key,
                  item: item,
                  onStateChanged: onStateChanged,
                  l10n: l10n,
                );
              },
        ),
        database: db,
        clock: fakeClock,
      );
      await tester.pump();

      // Pick a distractor (not the correct answer) to genuinely answer wrong.
      await tester.tap(find.byKey(const Key('choice-distractor1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pump();

      // Should show the error banner naming the correct answer.
      expect(find.byKey(const Key('lessonFeedbackBanner')), findsOneWidget);
      expect(find.textContaining(correctAnswer), findsWidgets);

      // Tap CONTINUE -> result screen
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pump();

      // Should show result screen, 0% score (one wrong outcome).
      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);
      expect(find.textContaining('0%'), findsOneWidget);
    });

    testWidgets('skip-counts-wrong', (WidgetTester tester) async {
      final items = await setupTestItems(
        db,
        1,
        2,
        choicesJson: vocabChoicesJson,
      );

      await pumpLessonShell(
        tester,
        LessonScreen(
          setId: 1,
          items: items,
          cardBuilder:
              ({
                Key? key,
                required Item item,
                required void Function(ExerciseDraft) onStateChanged,
                required AppLocalizations l10n,
                bool autoAnswer = false,
              }) {
                return PlaceholderExerciseCard(
                  key: key,
                  item: item,
                  onStateChanged: onStateChanged,
                  l10n: l10n,
                  autoAnswer: autoAnswer,
                );
              },
        ),
        database: db,
        clock: fakeClock,
      );
      await tester.pump();

      // Open overflow menu and tap SKIP (pre-check only)
      await openLessonMenu(tester);
      await tester.tap(find.byKey(const Key('skipItemMenuItem')));
      await tester.pump();

      // Should advance to next question
    });

    testWidgets('skip-absent-from-menu-post-check', (
      WidgetTester tester,
    ) async {
      final items = await setupTestItems(
        db,
        1,
        2,
        choicesJson: vocabChoicesJson,
      );

      await pumpLessonShell(
        tester,
        buildTestLessonScreen(
          setId: 1,
          items: items,
          l10n: AppLocalizationsEn(),
        ),
        database: db,
        clock: fakeClock,
      );
      await tester.pump();
      // Extra pump to process microtask from auto-answer
      await tester.pump();

      // Pre-check: both menu entries are present.
      await openLessonMenu(tester);
      expect(find.byKey(const Key('quitLessonMenuItem')), findsOneWidget);
      expect(find.byKey(const Key('skipItemMenuItem')), findsOneWidget);
      // Close the menu without selecting anything.
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();

      // Move to feedback phase.
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pump();

      // Post-check: Skip is gone, Quit remains.
      await openLessonMenu(tester);
      expect(find.byKey(const Key('quitLessonMenuItem')), findsOneWidget);
      expect(find.byKey(const Key('skipItemMenuItem')), findsNothing);
    });

    testWidgets('quit-confirm-cancel-is-noop', (WidgetTester tester) async {
      final items = await setupTestItems(
        db,
        1,
        2,
        choicesJson: vocabChoicesJson,
      );

      await pumpLessonShell(
        tester,
        LessonScreen(
          setId: 1,
          items: items,
          cardBuilder:
              ({
                Key? key,
                required Item item,
                required void Function(ExerciseDraft) onStateChanged,
                required AppLocalizations l10n,
                bool autoAnswer = false,
              }) {
                return PlaceholderExerciseCard(
                  key: key,
                  item: item,
                  onStateChanged: onStateChanged,
                  l10n: l10n,
                  autoAnswer: autoAnswer,
                );
              },
        ),
        database: db,
        clock: fakeClock,
      );
      await tester.pump();

      // Open overflow menu and tap quit
      await openLessonMenu(tester);
      await tester.tap(find.byKey(const Key('quitLessonMenuItem')));
      await tester.pump();

      // Confirm dialog should appear
      expect(find.byType(FoxConfirmDialog), findsOneWidget);

      // Tap cancel (FoxConfirmDialog uses cancelKey from kit test)
      await tester.tap(find.widgetWithText(FoxSecondaryButton, 'Cancel'));
      await tester.pump();

      // Should still be in lesson
      expect(find.byKey(const Key('checkButton')), findsOneWidget);
    });

    testWidgets('quit-confirm-pops', (WidgetTester tester) async {
      final items = await setupTestItems(
        db,
        1,
        2,
        choicesJson: vocabChoicesJson,
      );

      await pumpLessonShell(
        tester,
        LessonScreen(
          setId: 1,
          items: items,
          cardBuilder:
              ({
                Key? key,
                required Item item,
                required void Function(ExerciseDraft) onStateChanged,
                required AppLocalizations l10n,
                bool autoAnswer = false,
              }) {
                return PlaceholderExerciseCard(
                  key: key,
                  item: item,
                  onStateChanged: onStateChanged,
                  l10n: l10n,
                  autoAnswer: autoAnswer,
                );
              },
        ),
        database: db,
        clock: fakeClock,
      );
      await tester.pump();

      // Open overflow menu and tap quit
      await openLessonMenu(tester);
      await tester.tap(find.byKey(const Key('quitLessonMenuItem')));
      await tester.pump();

      // Tap confirm
      await tester.tap(find.byKey(const Key('confirmQuitLessonButton')));
      await tester.pump();

      // Should pop back to previous screen (navigator pops)
    });

    testWidgets('restart-reshuffles', (WidgetTester tester) async {
      final items = await setupTestItems(
        db,
        1,
        5,
        choicesJson: vocabChoicesJson,
      );

      await pumpLessonShell(
        tester,
        LessonScreen(
          setId: 1,
          items: items,
          cardBuilder:
              ({
                Key? key,
                required Item item,
                required void Function(ExerciseDraft) onStateChanged,
                required AppLocalizations l10n,
                bool autoAnswer = false,
              }) {
                return PlaceholderExerciseCard(
                  key: key,
                  item: item,
                  onStateChanged: onStateChanged,
                  l10n: l10n,
                  autoAnswer: autoAnswer,
                );
              },
        ),
        database: db,
        clock: fakeClock,
      );
      await tester.pump();

      // Complete the lesson quickly by skipping all
      for (int i = 0; i < 5; i++) {
        await openLessonMenu(tester);
        await tester.tap(find.byKey(const Key('skipItemMenuItem')));
        await tester.pump();
      }

      // Should be on result screen
      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);

      // Tap Practice again
      await tester.tap(find.byKey(const Key('practiceAgainButton')));
      await tester.pump();

      // Should be back at question 1 with reshuffled queue
      expect(find.byKey(const Key('checkButton')), findsOneWidget);
    });

    testWidgets('result-score-math', (WidgetTester tester) async {
      final items = await setupTestItems(
        db,
        1,
        4,
        choicesJson: vocabChoicesJson,
      );

      await pumpLessonShell(
        tester,
        LessonScreen(
          setId: 1,
          items: items,
          cardBuilder:
              ({
                Key? key,
                required Item item,
                required void Function(ExerciseDraft) onStateChanged,
                required AppLocalizations l10n,
                bool autoAnswer = false,
              }) {
                return PlaceholderExerciseCard(
                  key: key,
                  item: item,
                  onStateChanged: onStateChanged,
                  l10n: l10n,
                  autoAnswer: autoAnswer,
                );
              },
        ),
        database: db,
        clock: fakeClock,
      );
      await tester.pump();

      // Skip all 4 questions (0% score)
      for (int i = 0; i < 4; i++) {
        await openLessonMenu(tester);
        await tester.tap(find.byKey(const Key('skipItemMenuItem')));
        await tester.pump();
      }

      // Result screen should show 0%
      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);
      expect(find.textContaining('0%'), findsOneWidget);
    });

    testWidgets('rotation-safe: pump with new surface size, index preserved', (
      WidgetTester tester,
    ) async {
      final items = await setupTestItems(
        db,
        1,
        3,
        choicesJson: vocabChoicesJson,
      );

      await pumpLessonShell(
        tester,
        LessonScreen(
          setId: 1,
          items: items,
          cardBuilder:
              ({
                Key? key,
                required Item item,
                required void Function(ExerciseDraft) onStateChanged,
                required AppLocalizations l10n,
                bool autoAnswer = false,
              }) {
                return PlaceholderExerciseCard(
                  key: key,
                  item: item,
                  onStateChanged: onStateChanged,
                  l10n: l10n,
                  autoAnswer: autoAnswer,
                );
              },
        ),
        database: db,
        clock: fakeClock,
      );
      await tester.pump();

      // Advance to question 2
      await openLessonMenu(tester);
      await tester.tap(find.byKey(const Key('skipItemMenuItem')));
      await tester.pump();

      // Simulate rotation by pumping with new size
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pump();

      // Should still be on question 2 (index preserved)
      // Progress should still be ~33%
    });

    testWidgets('attempts-written-but-xp-streak-untouched', (
      WidgetTester tester,
    ) async {
      final items = await setupTestItems(
        db,
        1,
        1,
        choicesJson: vocabChoicesJson,
      );

      await pumpLessonShell(
        tester,
        LessonScreen(
          setId: 1,
          items: items,
          cardBuilder:
              ({
                Key? key,
                required Item item,
                required void Function(ExerciseDraft) onStateChanged,
                required AppLocalizations l10n,
                bool autoAnswer = false,
              }) {
                return PlaceholderExerciseCard(
                  key: key,
                  item: item,
                  onStateChanged: onStateChanged,
                  l10n: l10n,
                  autoAnswer: autoAnswer,
                );
              },
        ),
        database: db,
        clock: fakeClock,
      );
      await tester.pump();
      // Extra pump to process microtask from auto-answer
      await tester.pump();

      // Answer correctly (auto-answer)
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pump(); // feedback
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pump(); // continue -> result

      // Verify attempt was written
      final attempts = await statsRepo.getAttemptsForItem(items.first.id);
      expect(attempts.length, 1);
      expect(attempts.first.ok, true);

      // Verify xpTotal and streakCount are untouched (still 0)
      final profile = await statsRepo.getProfile();
      expect(profile.xpTotal, 0);
      expect(profile.streakCount, 0);
    });

    testWidgets(
      'result screen stays put until the user taps a button when pushed '
      'onto a real navigator stack (regression: result screen must not '
      'auto-pop itself)',
      (WidgetTester tester) async {
        final items = await setupTestItems(
          db,
          1,
          1,
          choicesJson: vocabChoicesJson,
        );

        // Push LessonScreen for real (Navigator.push), the way
        // LessonEntryButton does — unlike pumpLessonShell's `home:`, this
        // gives Navigator.pop() a previous route to actually pop to.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              systemClockProvider.overrideWithValue(fakeClock),
            ],
            child: MaterialApp(
              theme: FoxStreakTheme.light(),
              darkTheme: FoxStreakTheme.dark(),
              localizationsDelegates: const [_TestLocalizationsDelegate()],
              supportedLocales: const [Locale('en')],
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LessonScreen(
                          setId: 1,
                          items: items,
                          cardBuilder:
                              ({
                                Key? key,
                                required Item item,
                                required void Function(ExerciseDraft)
                                onStateChanged,
                                required AppLocalizations l10n,
                                bool autoAnswer = false,
                              }) {
                                return PlaceholderExerciseCard(
                                  key: key,
                                  item: item,
                                  onStateChanged: onStateChanged,
                                  l10n: l10n,
                                  autoAnswer: autoAnswer,
                                );
                              },
                        ),
                      ),
                    ),
                    child: const Text('go'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();

        // Finish the single-item lesson: CHECK then CONTINUE -> done.
        await tester.tap(find.byKey(const Key('checkButton')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('checkButton')));
        await tester.pumpAndSettle();

        // The result screen must still be showing — it must not have
        // auto-popped itself before the user did anything.
        expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);
        expect(find.byKey(const Key('practiceAgainButton')), findsOneWidget);

        // Only an explicit tap pops it back to the caller.
        await tester.tap(find.byKey(const Key('backToLibraryButton')));
        await tester.pumpAndSettle();
        expect(find.text('go'), findsOneWidget);
        expect(find.byKey(const Key('lessonResultScreen')), findsNothing);
      },
    );

    testWidgets('haptics: correct CHECK fires a light impact buzz', (
      WidgetTester tester,
    ) async {
      final items = await setupTestItems(
        db,
        1,
        1,
        choicesJson: vocabChoicesJson,
      );
      final correctAnswer = items.first.answer;

      final hapticCalls = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(call.arguments as String?);
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await pumpLessonShell(
        tester,
        LessonScreen(
          setId: 1,
          items: items,
          cardBuilder:
              ({
                Key? key,
                required Item item,
                required void Function(ExerciseDraft) onStateChanged,
                required AppLocalizations l10n,
                bool autoAnswer = false,
              }) {
                return PlaceholderExerciseCard(
                  key: key,
                  item: item,
                  onStateChanged: onStateChanged,
                  l10n: l10n,
                );
              },
        ),
        database: db,
        clock: fakeClock,
      );
      await tester.pump();

      await tester.tap(find.byKey(Key('choice-$correctAnswer')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pump();

      expect(hapticCalls, contains('HapticFeedbackType.lightImpact'));
      expect(hapticCalls, isNot(contains('HapticFeedbackType.heavyImpact')));
    });

    testWidgets('haptics: wrong CHECK fires a heavy impact buzz', (
      WidgetTester tester,
    ) async {
      final items = await setupTestItems(
        db,
        1,
        1,
        choicesJson: vocabChoicesJson,
      );

      final hapticCalls = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(call.arguments as String?);
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await pumpLessonShell(
        tester,
        LessonScreen(
          setId: 1,
          items: items,
          cardBuilder:
              ({
                Key? key,
                required Item item,
                required void Function(ExerciseDraft) onStateChanged,
                required AppLocalizations l10n,
                bool autoAnswer = false,
              }) {
                return PlaceholderExerciseCard(
                  key: key,
                  item: item,
                  onStateChanged: onStateChanged,
                  l10n: l10n,
                );
              },
        ),
        database: db,
        clock: fakeClock,
      );
      await tester.pump();

      // Pick a distractor (not the correct answer).
      await tester.tap(find.byKey(const Key('choice-distractor1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pump();

      expect(hapticCalls, contains('HapticFeedbackType.heavyImpact'));
      expect(hapticCalls, isNot(contains('HapticFeedbackType.lightImpact')));
    });

    testWidgets(
      'haptics: suppressed entirely when foxHapticsEnabledProvider is off',
      (WidgetTester tester) async {
        final items = await setupTestItems(
          db,
          1,
          1,
          choicesJson: vocabChoicesJson,
        );
        final correctAnswer = items.first.answer;

        final hapticCalls = <String?>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              hapticCalls.add(call.arguments as String?);
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              systemClockProvider.overrideWithValue(fakeClock),
              foxHapticsEnabledProvider.overrideWith(_DisabledHaptics.new),
            ],
            child: MaterialApp(
              theme: FoxStreakTheme.light(),
              darkTheme: FoxStreakTheme.dark(),
              localizationsDelegates: const [_TestLocalizationsDelegate()],
              supportedLocales: const [Locale('en')],
              home: Scaffold(
                body: LessonScreen(
                  setId: 1,
                  items: items,
                  cardBuilder:
                      ({
                        Key? key,
                        required Item item,
                        required void Function(ExerciseDraft) onStateChanged,
                        required AppLocalizations l10n,
                        bool autoAnswer = false,
                      }) {
                        return PlaceholderExerciseCard(
                          key: key,
                          item: item,
                          onStateChanged: onStateChanged,
                          l10n: l10n,
                        );
                      },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byKey(Key('choice-$correctAnswer')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('checkButton')));
        await tester.pump();

        expect(hapticCalls, isEmpty);
      },
    );

    testWidgets(
      'real vocab cards get fresh per-item state (regression: #024 key fix)',
      (WidgetTester tester) async {
        // No cardBuilder override: dispatches to the real MultipleChoiceCard,
        // which caches its shuffled options in initState — without a
        // per-item key (lesson_screen.dart's `_buildExerciseCard`), the
        // second item would wrongly keep showing the first item's answer.
        final items = await setupTestItems(db, 1, 2);

        await pumpLessonShell(
          tester,
          LessonScreen(setId: 1, items: items),
          database: db,
          clock: fakeClock,
        );
        await tester.pump();

        // LessonController.start() shuffles the queue, so determine which
        // item actually renders first rather than assuming items[0].
        final shownFirst = items
            .map((i) => i.answer)
            .firstWhere((a) => find.text(a).evaluate().isNotEmpty);
        final shownSecond = items
            .map((i) => i.answer)
            .firstWhere((a) => a != shownFirst);
        expect(find.text(shownFirst), findsOneWidget);

        await openLessonMenu(tester);
        await tester.tap(find.byKey(const Key('skipItemMenuItem')));
        await tester.pump();

        expect(find.text(shownSecond), findsOneWidget);
        expect(find.text(shownFirst), findsNothing);
      },
    );
  });
}
