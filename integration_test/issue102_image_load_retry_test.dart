// Issue #102 — question image load failures auto-retry, then offer a
// manual retry instead of a permanent broken-image placeholder.
//
// Drives the real app: creates a set with a `url`-type item via the real
// item editor, starts the real lesson, then drives the real
// `FoxQuestionImage` / `FoxFullScreenImageViewer` through a failure cycle
// by invoking the real `Image`'s own `errorBuilder` closure directly — the
// same deterministic technique `fox_item_image_test.dart`/
// `fox_question_image_test.dart` use, since real network timing can't be
// driven from a test (an `https://example.com/...` URL, and separately a
// polling wait for the *real* background fetch to fail on its own, were
// both tried first and hung indefinitely — this sandboxed environment has
// no outbound internet access, and `IntegrationTestWidgetsFlutterBinding`
// isn't a `FakeAsync` zone, so there's no way to force real auto-retry
// timers to resolve quickly). The image URL below points at `127.0.0.1` on
// a port nothing listens on purely so the real (not manually driven)
// background fetch also fails fast if it ever races the manual one, rather
// than hanging on an unreachable host.
//
// NOT CURRENTLY RUNNABLE FROM AN AUTOMATED/HEADLESS AGENT SESSION: on this
// macOS dev machine, `flutter test integration_test/issue102_image_load_
// retry_test.dart -d macos` launches `Fox Streak.app` ("Failed to
// foreground app; open returned 1") but then stalls indefinitely — tried
// three times (real network, fake-but-real `HttpClient`, and pure manual
// `errorBuilder` invocation with no real network dependency at all — the
// last one is this file's final form) with no progress past the first
// pumped frame. The common factor across all three is the live macOS GUI
// window itself, not this test's logic — `-d chrome` isn't an option
// either ("Web devices are not supported for integration tests yet.").
// Should run fine on a real interactive dev-machine session (the thing an
// automated agent session lacks); re-verify there before trusting a "still
// hangs" report against a change here. Confirmed-passing coverage of the
// exact same production retry state machine lives in
// `test/widgets/fox_question_image_test.dart` instead (16 widget tests).
//
// Unlike the widget tests (which pass literal test strings), this spec
// resolves the failure-placeholder copy from the real `AppLocalizations`,
// proving the new `imageLoadFailedMessage`/`retryButtonLabel` wiring
// through `buildItemImage` → `FoxQuestionImage` is correct end-to-end.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

Future<void> _failCurrentImage(WidgetTester tester) async {
  final image = tester.widget<Image>(find.byType(Image));
  image.errorBuilder!(
    tester.element(find.byType(Image)),
    Exception('offline'),
    StackTrace.current,
  );
}

/// 3 total attempts (#102 Decisions) — fails twice (each followed by a
/// real-time wait past that attempt's auto-retry delay) then a 3rd time,
/// which exhausts automatic retries and shows the failure placeholder.
Future<void> _exhaustAutoRetries(WidgetTester tester) async {
  await _failCurrentImage(tester);
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await tester.pump();
  await _failCurrentImage(tester);
  await Future<void>.delayed(const Duration(milliseconds: 800));
  await tester.pump();
  await _failCurrentImage(tester);
  await tester.pump();
  await tester.pump();
}

/// Same convention as `fox_question_image_test.dart`'s helper: the retry
/// affordance is a real button with a visible text label (#102 acceptance:
/// "not just a bare icon"), the `Semantics(button: true, ...)` wrapper the
/// `kit_test.dart` suite checks for the other kit buttons.
void _expectAccessibleRetryButton(WidgetTester tester, String label) {
  expect(find.text(label), findsOneWidget);
  final ancestorSemantics = find
      .ancestor(of: find.text(label), matching: find.byType(Semantics))
      .evaluate()
      .map((element) => element.widget as Semantics);
  expect(
    ancestorSemantics.any((semantics) => semantics.properties.button == true),
    isTrue,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a url image that keeps failing shows a retry placeholder with the '
    'real l10n copy on the lesson card, retry dismisses it, and the '
    'full-screen viewer retries independently',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 11, 3, 9));

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
      await tester.enterText(find.byKey(const Key('itemPromptField')), 'Fuchs');
      await tester.enterText(find.byKey(const Key('itemAnswerField')), 'fox');
      await tester.tap(find.byKey(const Key('itemImageTypeField')));
      await settle(tester);
      await tester.tap(find.text('Image URL').last);
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('itemImageContentField')),
        'http://127.0.0.1:1/fox.png',
      );
      await tester.ensureVisible(find.byKey(const Key('saveItemButton')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('startLessonFab')));
      await settle(tester);

      // Inline question-card image: exhausts automatic retries, then shows
      // the real-l10n failure placeholder with a tappable retry button.
      await _exhaustAutoRetries(tester);
      expect(
        find.byKey(const Key('foxQuestionImageLoadFailed')),
        findsOneWidget,
      );
      expect(find.text("Couldn't load this image"), findsOneWidget);
      _expectAccessibleRetryButton(tester, 'Retry');
      // The rest of the question stays usable while the image is failed.
      expect(find.text('Fuchs'), findsOneWidget);
      expect(find.byKey(const Key('checkButton')), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.byKey(const Key('foxQuestionImageLoadFailed')), findsNothing);

      // Full-screen viewer: opened by tapping the (now re-trying) inline
      // image; it fetches — and fails/retries — independently of it.
      await tester.tap(find.byKey(const Key('foxQuestionImageTapTarget')));
      await settle(tester);
      expect(find.byKey(const Key('fullScreenImageView')), findsOneWidget);

      await _exhaustAutoRetries(tester);
      expect(
        find.byKey(const Key('fullScreenImageViewLoadFailed')),
        findsOneWidget,
      );
      expect(find.text("Couldn't load this image"), findsOneWidget);
      _expectAccessibleRetryButton(tester, 'Retry');

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(
        find.byKey(const Key('fullScreenImageViewLoadFailed')),
        findsNothing,
      );
    },
  );
}
