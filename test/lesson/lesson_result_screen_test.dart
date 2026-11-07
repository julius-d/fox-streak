// Issue #114: the result screen offers only "Redo missed items" (primary,
// above) and "Home" (secondary) — or a lone primary "Home" on a perfect score.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/lesson/lesson_result.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

const _result = LessonResult(
  setId: 1,
  itemIds: [1, 2],
  outcomes: [],
  correctCount: 1,
  scorePct: 50,
);

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onRedoMissedItems,
  VoidCallback? onHome,
  TextScaler textScaler = TextScaler.noScaling,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? FoxStreakTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: LessonResultScreen(
            result: _result,
            l10n: AppLocalizations.of(context)!,
            pet: PetCatalog.defaultEntry,
            onHome: onHome ?? () {},
            onRedoMissedItems: onRedoMissedItems,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

bool _isPrimary(WidgetTester tester, String key) => find
    .descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton))
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('missed items: primary Redo missed items above secondary Home', (
    tester,
  ) async {
    var redone = 0;
    var home = 0;
    await _pump(
      tester,
      onRedoMissedItems: () => redone++,
      onHome: () => home++,
    );

    final redoTop = tester.getTopLeft(
      find.byKey(const Key('redoMissedItemsButton')),
    );
    final homeTop = tester.getTopLeft(find.byKey(const Key('homeButton')));
    expect(redoTop.dy, lessThan(homeTop.dy));
    expect(_isPrimary(tester, 'redoMissedItemsButton'), isTrue);
    expect(_isPrimary(tester, 'homeButton'), isFalse);
    expect(find.text('Redo missed items'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('redoMissedItemsButton')));
    await tester.tap(find.byKey(const Key('homeButton')));
    expect(redone, 1);
    expect(home, 1);
  });

  testWidgets('perfect score: a single primary Home button', (tester) async {
    await _pump(tester);

    expect(_isPrimary(tester, 'homeButton'), isTrue);
    expect(find.byKey(const Key('redoMissedItemsButton')), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('removed buttons never appear', (tester) async {
    await _pump(tester, onRedoMissedItems: () {});

    expect(find.byKey(const Key('setOverviewButton')), findsNothing);
    expect(find.byKey(const Key('redoWholeSetButton')), findsNothing);
    expect(find.text('Set overview'), findsNothing);
    expect(find.text('Redo whole set'), findsNothing);
  });

  testWidgets('dark mode + large font render without overflow', (tester) async {
    await _pump(
      tester,
      onRedoMissedItems: () {},
      theme: FoxStreakTheme.dark(),
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('homeButton')), findsOneWidget);
  });
}
