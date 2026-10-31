// Issue #014 — prompt-side item images render end-to-end.
//
// Drives the real app: creates a set, adds a choice item with an emoji
// image via the real item editor's image section, then asserts the emoji
// renders both as a Set detail thumbnail (next to the item row) and above
// the prompt on the real lesson exercise card — never just in isolation
// via a synthetic widget harness.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('emoji image saved via the item editor shows on the set detail '
      'thumbnail and on the lesson exercise card', (tester) async {
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
    await tester.tap(find.text('Emoji').last);
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('itemImageContentField')),
      '🐶',
    );
    await tester.ensureVisible(find.byKey(const Key('saveItemButton')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('saveItemButton')));
    await settle(tester);

    // Set detail: the emoji shows as the item row's thumbnail.
    expect(
      find.descendant(of: listTileWithText('Hund'), matching: find.text('🐶')),
      findsOneWidget,
    );

    // Lesson: the same emoji renders above the prompt on the real
    // exercise card.
    await tester.tap(find.byKey(const Key('startLessonFab')));
    await settle(tester);
    expect(find.text('🐶'), findsOneWidget);
  });
}
