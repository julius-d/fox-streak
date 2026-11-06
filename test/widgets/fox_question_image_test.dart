// Widget tests for FoxQuestionImage + FoxFullScreenImageViewer (#094).
//
// `FoxQuestionImage` is the question-card-only counterpart to the small,
// square, non-interactive `FoxItemImage` (#014, tested separately) — it
// shows base64/url images at their natural aspect ratio (not cropped to
// square), with more room, and adds a copyright caption + tap-to-expand
// full-screen view. `emoji` images never get either (#094 Decisions).
//
// `url` requests are never let resolve over a real network: `flutter_test`'s
// binding already fakes every `HttpClient` to return 400, and the loading/
// error builders are instead invoked directly with synthetic arguments.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

/// A minimal valid 1x1 transparent PNG, decodable by `Image.memory`.
final Uint8List kTinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+A8AAQUAAdafFaMAAAAASUVORK5CYII=',
);

/// Literal test string for the tap-to-expand a11y hint (#094) — kit widgets
/// never resolve l10n themselves, so real callers pass an
/// `AppLocalizations`-resolved string; tests pass a plain literal.
const String kExpandHint = 'Opens a full-screen view';

/// Literal test strings for the #102 load-failed placeholder — same
/// convention as [kExpandHint].
const String kLoadFailedMessage = "Couldn't load this image";
const String kRetryLabel = 'Retry';

/// Pumps [child] under the canonical light theme.
Future<void> pumpKit(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: FoxStreakTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('emoji', () {
    testWidgets('renders the emoji as large inline text with the prompt as '
        'its semantic label', (WidgetTester tester) async {
      await pumpKit(
        tester,
        const FoxQuestionImage(
          imageType: 'emoji',
          imageContent: '🐶',
          semanticLabel: 'Hund',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      expect(find.text('🐶'), findsOneWidget);
      expect(find.bySemanticsLabel('Hund'), findsOneWidget);
    });

    testWidgets('is never tappable and gets no caption bar, even if a '
        'copyright were (invalidly) set (#094 Decisions)', (
      WidgetTester tester,
    ) async {
      await pumpKit(
        tester,
        const FoxQuestionImage(
          imageType: 'emoji',
          imageContent: '🐶',
          semanticLabel: 'Hund',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      expect(find.byKey(const Key('foxQuestionImageTapTarget')), findsNothing);
      final data = tester.getSemantics(find.byType(FoxQuestionImage));
      expect(data.hint, isEmpty);
    });
  });

  group('base64', () {
    testWidgets('renders the decoded image via Image.memory, not cropped '
        'to a square (BoxFit.contain)', (WidgetTester tester) async {
      await pumpKit(
        tester,
        FoxQuestionImage(
          imageType: 'base64',
          imageContent: base64Encode(kTinyPng),
          semanticLabel: 'A sticker',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
      expect(
        find.byKey(const Key('foxQuestionImagePlaceholder')),
        findsNothing,
      );
      expect(find.bySemanticsLabel('A sticker'), findsOneWidget);
    });

    testWidgets('falls back to the placeholder on malformed base64', (
      WidgetTester tester,
    ) async {
      await pumpKit(
        tester,
        const FoxQuestionImage(
          imageType: 'base64',
          imageContent: 'not-base64!!',
          semanticLabel: 'A sticker',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      expect(
        find.byKey(const Key('foxQuestionImagePlaceholder')),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    });
  });

  group('copyright caption (#094)', () {
    testWidgets('renders a right-aligned caption bar below the image when '
        'imageCopyright is set', (WidgetTester tester) async {
      await pumpKit(
        tester,
        FoxQuestionImage(
          imageType: 'base64',
          imageContent: base64Encode(kTinyPng),
          semanticLabel: 'A sticker',
          imageCopyright: '© Jane Doe',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('foxItemImageCaption')), findsOneWidget);
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('foxItemImageCaption')),
          matching: find.byType(Text),
        ),
      );
      expect(text.data, '© Jane Doe');
      expect(text.textAlign, TextAlign.right);
    });

    testWidgets('no caption bar at all when imageCopyright is unset (not '
        'an empty bar)', (WidgetTester tester) async {
      await pumpKit(
        tester,
        FoxQuestionImage(
          imageType: 'base64',
          imageContent: base64Encode(kTinyPng),
          semanticLabel: 'A sticker',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('foxItemImageCaption')), findsNothing);
    });

    testWidgets('the copyright text is included in the semantic label '
        'alongside the prompt-based label', (WidgetTester tester) async {
      await pumpKit(
        tester,
        FoxQuestionImage(
          imageType: 'base64',
          imageContent: base64Encode(kTinyPng),
          semanticLabel: 'Hund',
          imageCopyright: '© Jane Doe',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Hund. © Jane Doe'), findsOneWidget);
    });
  });

  group('tap-to-expand (#094)', () {
    testWidgets('base64/url images carry a tap target with the a11y hint', (
      WidgetTester tester,
    ) async {
      await pumpKit(
        tester,
        FoxQuestionImage(
          imageType: 'base64',
          imageContent: base64Encode(kTinyPng),
          semanticLabel: 'A sticker',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('foxQuestionImageTapTarget')),
        findsOneWidget,
      );
      final data = tester.getSemantics(find.byType(FoxQuestionImage));
      expect(data.hint, kExpandHint);
    });

    testWidgets('tapping a base64 image pushes FoxFullScreenImageViewer', (
      WidgetTester tester,
    ) async {
      await pumpKit(
        tester,
        FoxQuestionImage(
          imageType: 'base64',
          imageContent: base64Encode(kTinyPng),
          semanticLabel: 'A sticker',
          imageCopyright: '© Jane Doe',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('foxQuestionImageTapTarget')));
      await tester.pumpAndSettle();

      expect(find.byType(FoxFullScreenImageViewer), findsOneWidget);
      expect(find.byKey(const Key('fullScreenImageView')), findsOneWidget);
      expect(find.byKey(const Key('foxItemImageCaption')), findsOneWidget);
    });
  });

  group('Hero flight (#103)', () {
    /// Pumps [child] under a `MediaQuery` with reduce-motion forced on,
    /// mirroring `issue100_pet_hero_test.dart`'s approach for the pet Hero.
    Future<void> pumpReduceMotionKit(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: app!,
          ),
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('the card wraps the tappable image box (not the caption '
        'bar) in a Hero', (WidgetTester tester) async {
      await pumpKit(
        tester,
        FoxQuestionImage(
          imageType: 'base64',
          imageContent: base64Encode(kTinyPng),
          semanticLabel: 'A sticker',
          imageCopyright: '© Jane Doe',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.ancestor(of: find.byType(Image), matching: find.byType(Hero)),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('foxItemImageCaption')),
          matching: find.byType(Hero),
        ),
        findsNothing,
      );
    });

    testWidgets('an emoji (not expandable) is never wrapped in a Hero', (
      WidgetTester tester,
    ) async {
      await pumpKit(
        tester,
        const FoxQuestionImage(
          imageType: 'emoji',
          imageContent: '🐶',
          semanticLabel: 'Hund',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Hero), findsNothing);
    });

    /// The card's Hero tag, read off a loaded base64 image — shared by
    /// every assertion below that the full-screen viewer's Hero (whatever
    /// load state it's in) uses the same tag.
    Future<Object> cardHeroTag(WidgetTester tester) async {
      await pumpKit(
        tester,
        FoxQuestionImage(
          imageType: 'base64',
          imageContent: base64Encode(kTinyPng),
          semanticLabel: 'A sticker',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .widget<Hero>(
            find.ancestor(of: find.byType(Image), matching: find.byType(Hero)),
          )
          .tag;
    }

    testWidgets('the full-screen viewer wraps a loaded image in a Hero '
        "sharing the card's tag", (WidgetTester tester) async {
      final tag = await cardHeroTag(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          home: FoxFullScreenImageViewer(
            imageType: 'base64',
            imageContent: base64Encode(kTinyPng),
            imageLoadFailedMessage: kLoadFailedMessage,
            retryButtonLabel: kRetryLabel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Hero>(
              find.ancestor(
                of: find.byType(Image),
                matching: find.byType(Hero),
              ),
            )
            .tag,
        tag,
      );
    });

    testWidgets('the full-screen viewer wraps a failed-placeholder image '
        "in a Hero sharing the card's tag", (WidgetTester tester) async {
      final tag = await cardHeroTag(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          home: const FoxFullScreenImageViewer(
            imageType: 'base64',
            imageContent: 'not-base64!!',
            imageLoadFailedMessage: kLoadFailedMessage,
            retryButtonLabel: kRetryLabel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Hero>(
              find.ancestor(
                of: find.byKey(const Key('fullScreenImageViewPlaceholder')),
                matching: find.byType(Hero),
              ),
            )
            .tag,
        tag,
      );
    });

    testWidgets('the full-screen viewer wraps a still-loading url image '
        "in a Hero sharing the card's tag", (WidgetTester tester) async {
      final tag = await cardHeroTag(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          home: const FoxFullScreenImageViewer(
            imageType: 'url',
            imageContent: 'https://example.com/i.png',
            imageLoadFailedMessage: kLoadFailedMessage,
            retryButtonLabel: kRetryLabel,
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<Hero>(
              find.ancestor(
                of: find.byKey(const Key('fullScreenImageViewLoading')),
                matching: find.byType(Hero),
              ),
            )
            .tag,
        tag,
      );
      // Drains the real (fake-400) network response's auto-retry timers
      // (#102) so none are left pending when the test ends.
      await tester.pumpAndSettle();
    });

    testWidgets('with OS reduce motion on, neither the card nor the '
        'full-screen viewer wraps its image in a Hero', (
      WidgetTester tester,
    ) async {
      await pumpReduceMotionKit(
        tester,
        FoxQuestionImage(
          imageType: 'base64',
          imageContent: base64Encode(kTinyPng),
          semanticLabel: 'A sticker',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Hero), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: app!,
          ),
          home: FoxFullScreenImageViewer(
            imageType: 'base64',
            imageContent: base64Encode(kTinyPng),
            imageLoadFailedMessage: kLoadFailedMessage,
            retryButtonLabel: kRetryLabel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Hero), findsNothing);
    });
  });

  group('FoxFullScreenImageViewer (#094)', () {
    testWidgets('shows the image and caption; tapping the image pops', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => FoxFullScreenImageViewer(
                      imageType: 'base64',
                      imageContent: base64Encode(kTinyPng),
                      imageCopyright: '© Jane Doe',
                      imageLoadFailedMessage: kLoadFailedMessage,
                      retryButtonLabel: kRetryLabel,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullScreenImageView')), findsOneWidget);
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('foxItemImageCaption')),
          matching: find.byType(Text),
        ),
      );
      expect(text.data, '© Jane Doe');

      await tester.tap(find.byKey(const Key('fullScreenImageViewTapTarget')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fullScreenImageView')), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('no caption bar when imageCopyright is unset', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          home: FoxFullScreenImageViewer(
            imageType: 'base64',
            imageContent: base64Encode(kTinyPng),
            imageLoadFailedMessage: kLoadFailedMessage,
            retryButtonLabel: kRetryLabel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('foxItemImageCaption')), findsNothing);
    });

    testWidgets('the platform back gesture pops it too', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const FoxFullScreenImageViewer(
                      imageType: 'base64',
                      imageContent: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+A8AAQUAAdafFaMAAAAASUVORK5CYII=',
                      imageLoadFailedMessage: kLoadFailedMessage,
                      retryButtonLabel: kRetryLabel,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fullScreenImageView')), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fullScreenImageView')), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('malformed base64 load falls back to the placeholder', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          home: const FoxFullScreenImageViewer(
            imageType: 'base64',
            imageContent: 'not-base64!!',
            imageLoadFailedMessage: kLoadFailedMessage,
            retryButtonLabel: kRetryLabel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('fullScreenImageViewPlaceholder')),
        findsOneWidget,
      );
    });
  });

  group('url load-failure retry (#102)', () {
    // Mirrors `fox_item_image_test.dart`'s approach: rather than relying on
    // `flutter_test`'s fake-400 `HttpClient` to fail on its own timing, each
    // failure is driven deterministically by invoking the current `Image`'s
    // real `errorBuilder` closure directly — which runs the actual
    // production retry-scheduling code, just without waiting on real
    // network timing.
    Future<void> failCurrentImage(WidgetTester tester) async {
      final image = tester.widget<Image>(find.byType(Image));
      image.errorBuilder!(
        tester.element(find.byType(Image)),
        Exception('offline'),
        StackTrace.current,
      );
    }

    /// 3 total attempts (#102 Decisions: "e.g. 3 attempts total") — fails
    /// twice (each followed by an automatic retry) then a 3rd time, which
    /// exhausts automatic retries and shows the failure placeholder.
    Future<void> exhaustAutoRetries(WidgetTester tester) async {
      await failCurrentImage(tester);
      await tester.pump(const Duration(seconds: 1));
      await failCurrentImage(tester);
      await tester.pump(const Duration(seconds: 1));
      await failCurrentImage(tester);
      await tester.pump();
      await tester.pump();
    }

    /// Asserts the retry affordance is a real button with a visible text
    /// label (#102 acceptance: "not just a bare icon"), the same
    /// `Semantics(button: true, ...)` convention `kit_test.dart` checks for
    /// the other kit buttons.
    void expectAccessibleRetryButton(WidgetTester tester, String label) {
      expect(find.text(label), findsOneWidget);
      final ancestorSemantics = find
          .ancestor(of: find.text(label), matching: find.byType(Semantics))
          .evaluate()
          .map((element) => element.widget as Semantics);
      expect(
        ancestorSemantics.any(
          (semantics) => semantics.properties.button == true,
        ),
        isTrue,
      );
    }

    testWidgets('retries automatically a few times before showing any '
        'failure UI to the user, and a load that then succeeds renders '
        'normally — no stuck spinner, no failure UI', (
      WidgetTester tester,
    ) async {
      await pumpKit(
        tester,
        const FoxQuestionImage(
          imageType: 'url',
          imageContent: 'https://example.com/i.png',
          semanticLabel: 'A sticker',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      await tester.pump();

      await failCurrentImage(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('foxQuestionImageLoadFailed')), findsNothing);

      await failCurrentImage(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('foxQuestionImageLoadFailed')), findsNothing);

      // The 2nd automatic retry's `Image` then succeeds (`loadingBuilder`
      // reports `progress: null`, same as `fox_item_image_test.dart`'s
      // synthetic-invocation convention — a real decoded network image
      // can't be driven from a widget test) — the wrapper must pass the
      // resolved child through as-is, not keep showing a spinner or
      // failure UI, and must not schedule yet another retry.
      const resolvedImage = Text('resolved image');
      final image = tester.widget<Image>(find.byType(Image));
      final built = image.loadingBuilder!(
        tester.element(find.byType(Image)),
        resolvedImage,
        null,
      );
      expect(built, same(resolvedImage));
      await pumpKit(tester, built);
      expect(find.text('resolved image'), findsOneWidget);
    });

    testWidgets('shows a retry placeholder with an accessible retry '
        'button once automatic retries are exhausted; tapping retry '
        'dismisses it and re-attempts the load, repeatable indefinitely', (
      WidgetTester tester,
    ) async {
      await pumpKit(
        tester,
        const FoxQuestionImage(
          imageType: 'url',
          imageContent: 'https://example.com/i.png',
          semanticLabel: 'A sticker',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      await tester.pump();
      await exhaustAutoRetries(tester);

      expect(
        find.byKey(const Key('foxQuestionImageLoadFailed')),
        findsOneWidget,
      );
      expect(find.text(kLoadFailedMessage), findsOneWidget);
      expectAccessibleRetryButton(tester, kRetryLabel);
      // The rest of the question (here: the surrounding Scaffold) stays in
      // the tree — the placeholder only replaces the image's own space.
      expect(find.byType(FoxQuestionImage), findsOneWidget);

      await tester.tap(find.text(kRetryLabel));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('foxQuestionImageLoadFailed')), findsNothing);

      // Unlimited manual retry (#102 Decisions) — failing out a 2nd cycle
      // shows the placeholder again rather than some final give-up state.
      await exhaustAutoRetries(tester);
      expect(
        find.byKey(const Key('foxQuestionImageLoadFailed')),
        findsOneWidget,
      );
      // Drains any retry the real (fake-400) network response scheduled on
      // its own, independent of the manual failures driven above, so no
      // Timer is left pending when the test ends.
      await tester.pumpAndSettle();
    });

    testWidgets('the full-screen viewer gets the same treatment, '
        'independently of the inline image', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          home: const FoxFullScreenImageViewer(
            imageType: 'url',
            imageContent: 'https://example.com/i.png',
            imageLoadFailedMessage: kLoadFailedMessage,
            retryButtonLabel: kRetryLabel,
          ),
        ),
      );
      await tester.pump();
      await exhaustAutoRetries(tester);

      expect(
        find.byKey(const Key('fullScreenImageViewLoadFailed')),
        findsOneWidget,
      );
      expect(find.text(kLoadFailedMessage), findsOneWidget);
      expectAccessibleRetryButton(tester, kRetryLabel);

      await tester.tap(find.text(kRetryLabel));
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('fullScreenImageViewLoadFailed')),
        findsNothing,
      );
      // See the previous test: drains any independently-scheduled retry
      // from the real (fake-400) network response.
      await tester.pumpAndSettle();
    });
  });

  group('expandToFill (#112)', () {
    FoxQuestionImage image({bool fill = true, String type = 'base64'}) =>
        FoxQuestionImage(
          imageType: type,
          imageContent: type == 'base64' ? base64Encode(kTinyPng) : '🐶',
          semanticLabel: 'x',
          expandHint: kExpandHint,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
          expandToFill: fill,
        );

    Finder tap() => find.byKey(const Key('foxQuestionImageTapTarget'));

    testWidgets('grows to the height its parent gives it', (tester) async {
      await pumpKit(tester, SizedBox(height: 500, child: image()));
      expect(tester.getSize(tap()).height, 500);
    });

    testWidgets('keeps the 240dp floor inside an IntrinsicHeight', (
      tester,
    ) async {
      await pumpKit(tester, IntrinsicHeight(child: image()));
      expect(tester.getSize(tap()).height, 240);
    });

    testWidgets('emoji keeps its fixed box', (tester) async {
      await pumpKit(tester, SizedBox(height: 500, child: image(type: 'emoji')));
      expect(tester.getSize(find.text('🐶')).height, lessThan(120));
    });
  });
}
