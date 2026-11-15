// Issue #134 — mastery crowns on Library set cards, in the real app.
//
// A set with one of its two items mastered shows 2.5 crowns, a never
// practiced set the "New" badge, and no card shows its item count. Playing a
// lesson that masters the second item, going Home from the result screen and
// browsing the sets again fills the crowns from 2.5 to 5 with the 100% gold
// shimmer; the untouched set stays New.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a lesson that masters the last item fills the crowns to 5 '
      'with a shimmer; an unpracticed set stays New', (tester) async {
    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 11, 15, 9));
    final sets = SetsRepository(db, clock);
    final stats = StatsRepository(db, clock);

    final capitals = await sets.createSet(
      title: 'Capitals',
      createdBy: 'Tester',
    );
    final itemIds = [
      for (final country in ['France', 'Paris-land'])
        await sets.addItem(
          setId: capitals,
          type: 'freeText',
          prompt: 'Capital of $country',
          answer: 'Paris',
        ),
    ];
    // First item mastered, second answered correctly once.
    for (final id in [itemIds[0], itemIds[0], itemIds[1]]) {
      await stats.recordAttempt(itemId: id, ok: true);
    }
    final colors = await sets.createSet(title: 'Colors', createdBy: 'Tester');
    await sets.addItem(
      setId: colors,
      type: 'freeText',
      prompt: 'rot',
      answer: 'red',
    );

    Finder inCard(int setId, Finder matching) => find.descendant(
      of: find.byKey(Key('setTile-$setId')),
      matching: matching,
    );
    double capitalsFill() => tester
        .widget<FoxMasteryCrowns>(
          inCard(capitals, find.byType(FoxMasteryCrowns)),
        )
        .fill;

    await pumpFoxStreakApp(tester, db: db, clock: clock);
    await skipOnboardingAndOpenLibrary(tester);

    expect(capitalsFill(), 2.5);
    expect(inCard(colors, find.byType(FoxNewBadge)), findsOneWidget);
    expect(find.textContaining('items'), findsNothing);

    await tester.tap(playSetButton('Capitals'));
    await settle(tester);
    for (var i = 0; i < itemIds.length; i++) {
      await tester.enterText(
        find.byKey(const Key('freeTextAnswerField')),
        'Paris',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
      await settle(tester);
      await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
      await settle(tester);
    }
    await dismissCompletionScreens(tester);
    await tester.tap(find.byKey(const Key('homeButton')));
    await settle(tester);

    await tester.tap(find.byKey(const Key('homeBrowseSetsButton')));
    final fills = <double>[];
    var sawShimmer = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (inCard(capitals, find.byType(FoxMasteryCrowns)).evaluate().isEmpty) {
        continue;
      }
      fills.add(capitalsFill());
      sawShimmer |= find
          .byKey(const Key('masteryShimmer'))
          .evaluate()
          .isNotEmpty;
    }
    await settle(tester);

    expect(fills.first, lessThan(5));
    expect(fills.any((fill) => fill > 2.5 && fill < 5), isTrue);
    expect(sawShimmer, isTrue);
    expect(capitalsFill(), 5);
    expect(inCard(colors, find.byType(FoxNewBadge)), findsOneWidget);
  });
}
