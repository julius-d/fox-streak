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
  'iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAYAAAD/Rn+7AAAAMElEQVR4nO3OsQ0AAAjDsJ7P1+UKFIYM3p1O+lnogEGDdMCgQTpg0CAdMGiQDhi8ttSp4yqPxYvYAAAAAElFTkSuQmCC',
);

/// Literal test string for the tap-to-expand a11y hint (#094) — kit widgets
/// never resolve l10n themselves, so real callers pass an
/// `AppLocalizations`-resolved string; tests pass a plain literal.
const String kExpandHint = 'Opens a full-screen view';
const String kCloseLabel = 'Close image';

/// Literal test strings for the #102 load-failed placeholder — same
/// convention as [kExpandHint].
const String kLoadFailedMessage = "Couldn't load this image";
const String kRetryLabel = 'Retry';

/// A valid 20x40 (portrait) PNG, for the narrower-than-the-box layout (#113).
final Uint8List kPortraitPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABQAAAAoCAYAAAD+MdrbAAAAJ0lEQVR4nO3MoQEAAAgDoJ3v1/MIjQQq6aSfIhQKhUKhUCgUCoU3C7Te4yrqtI2QAAAAAElFTkSuQmCC',
);

/// Lets real image decoding finish (it runs outside the fake-async zone),
/// so the intrinsic size the caption layout depends on (#113) is known.
Future<void> settleImageDecode(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 600)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

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
          closeLabel: kCloseLabel,
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
          closeLabel: kCloseLabel,
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
          closeLabel: kCloseLabel,
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
          closeLabel: kCloseLabel,
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
          closeLabel: kCloseLabel,
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
      expect(text.textAlign, TextAlign.end);
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
          closeLabel: kCloseLabel,
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
          closeLabel: kCloseLabel,
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
          closeLabel: kCloseLabel,
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
          closeLabel: kCloseLabel,
          imageLoadFailedMessage: kLoadFailedMessage,
          retryButtonLabel: kRetryLabel,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('foxQuestionImageTapTarget')));
      await tester.pumpAndSettle();
      await settleImageDecode(tester);

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
          closeLabel: kCloseLabel,
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
          closeLabel: kCloseLabel,
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
          closeLabel: kCloseLabel,
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
            question: 'Question?',
            closeLabel: kCloseLabel,
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
            question: 'Question?',
            closeLabel: kCloseLabel,
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
            question: 'Question?',
            closeLabel: kCloseLabel,
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
          closeLabel: kCloseLabel,
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
            question: 'Question?',
            closeLabel: kCloseLabel,
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
                      question: 'Question?',
                      closeLabel: kCloseLabel,
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
      await settleImageDecode(tester);

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
            question: 'Question?',
            closeLabel: kCloseLabel,
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
                      question: 'Question?',
                      closeLabel: kCloseLabel,
                      imageType: 'base64',
                      imageContent: 'iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAYAAAD/Rn+7AAAAMElEQVR4nO3OsQ0AAAjDsJ7P1+UKFIYM3p1O+lnogEGDdMCgQTpg0CAdMGiQDhi8ttSp4yqPxYvYAAAAAElFTkSuQmCC',
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
            question: 'Question?',
            closeLabel: kCloseLabel,
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
          closeLabel: kCloseLabel,
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
          closeLabel: kCloseLabel,
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
            question: 'Question?',
            closeLabel: kCloseLabel,
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
          closeLabel: kCloseLabel,
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

  group('copyright caption and full-screen restyle (#113)', () {
    Widget viewer({
      String type = 'base64',
      String? content,
      String? copyright = '© Jane Doe',
    }) => FoxFullScreenImageViewer(
      imageType: type,
      imageContent: content ?? base64Encode(kPortraitPng),
      imageCopyright: copyright,
      question: 'What is shown here?',
      closeLabel: kCloseLabel,
      imageLoadFailedMessage: kLoadFailedMessage,
      retryButtonLabel: kRetryLabel,
    );

    Future<void> pumpViewer(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        MaterialApp(theme: FoxStreakTheme.light(), home: child),
      );
      await settleImageDecode(tester);
    }

    testWidgets('card: plain tiny muted caption, right-aligned to the '
        "rendered image's right edge and no wider than it", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: FoxQuestionImage(
                  imageType: 'base64',
                  imageContent: base64Encode(kPortraitPng),
                  semanticLabel: 'Sticker',
                  imageCopyright: '© Jane Doe with a rather long note',
                  expandHint: kExpandHint,
                  closeLabel: kCloseLabel,
                  imageLoadFailedMessage: kLoadFailedMessage,
                  retryButtonLabel: kRetryLabel,
                ),
              ),
            ),
          ),
        ),
      );
      await settleImageDecode(tester);

      final image = tester.getRect(find.byType(Image));
      final caption = tester.getRect(
        find.byKey(const Key('foxItemImageCaption')),
      );
      // Portrait 20x40 in a 300-wide box: narrower than the box.
      expect(image.width, lessThan(300));
      expect(caption.right, closeTo(image.right, 0.01));
      expect(caption.width, closeTo(image.width, 0.01));
      expect(caption.top, closeTo(image.bottom, 0.01 + FoxSpacing.xs));

      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('foxItemImageCaption')),
          matching: find.byType(Text),
        ),
      );
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.style!.fontSize, 11);
      expect(
        text.style!.color,
        FoxStreakTheme.light().colorScheme.onSurfaceVariant,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('foxItemImageCaption')),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });

    testWidgets('card: caption stays within bounds at a large text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.5)),
            child: app!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: FoxQuestionImage(
                imageType: 'base64',
                imageContent: base64Encode(kTinyPng),
                semanticLabel: 'Sticker',
                imageCopyright: 'A long credit line that needs to wrap ' * 3,
                expandHint: kExpandHint,
                closeLabel: kCloseLabel,
                imageLoadFailedMessage: kLoadFailedMessage,
                retryButtonLabel: kRetryLabel,
              ),
            ),
          ),
        ),
      );
      await settleImageDecode(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('full screen: black background, white close button and '
        'white question above the image', (tester) async {
      await pumpViewer(tester, viewer());

      expect(
        tester
            .widget<Scaffold>(find.byKey(const Key('fullScreenImageView')))
            .backgroundColor,
        Colors.black,
      );
      final close = find.byKey(const Key('fullScreenImageViewClose'));
      expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
      expect(find.byTooltip(kCloseLabel), findsOneWidget);
      expect(tester.widget<IconButton>(close).color, Colors.white);

      final question = find.byKey(const Key('fullScreenImageViewQuestion'));
      final text = tester.widget<Text>(question);
      expect(text.data, 'What is shown here?');
      expect(text.maxLines, 3);
      expect(text.style!.color, Colors.white);
      expect(
        tester.getTopLeft(question).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(close).dy),
      );
      expect(
        tester.getBottomLeft(question).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(Image)).dy),
      );
    });

    testWidgets('full screen: black in dark theme too', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: FoxStreakTheme.dark(), home: viewer()),
      );
      await settleImageDecode(tester);
      expect(
        tester
            .widget<Scaffold>(find.byKey(const Key('fullScreenImageView')))
            .backgroundColor,
        Colors.black,
      );
    });

    testWidgets('full screen: close button pops the route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).push<void>(MaterialPageRoute<void>(builder: (_) => viewer())),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fullScreenImageViewClose')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fullScreenImageView')), findsNothing);
    });

    for (final (String name, Uint8List png) in [
      ('portrait', kPortraitPng),
      ('landscape', kTinyPng),
    ]) {
      testWidgets('full screen: dimmed-white caption directly under a $name '
          'image, aligned to its real right edge', (tester) async {
        await pumpViewer(tester, viewer(content: base64Encode(png)));

        final image = tester.getRect(find.byType(Image));
        final caption = tester.getRect(
          find.byKey(const Key('foxItemImageCaption')),
        );
        expect(caption.right, closeTo(image.right, 0.01));
        expect(caption.width, closeTo(image.width, 0.01));
        expect(caption.top, closeTo(image.bottom, 0.01));
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('foxItemImageCaption')),
            matching: find.byType(Text),
          ),
        );
        expect(text.maxLines, 2);
        expect(text.style!.color, Colors.white.withValues(alpha: 0.7));
      });
    }

    testWidgets('full screen: no caption while loading, on the placeholder '
        'or without a copyright; question + close always shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          home: viewer(type: 'url', content: 'https://example.invalid/a.png'),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('fullScreenImageViewLoading')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('foxItemImageCaption')), findsNothing);
      expect(
        find.byKey(const Key('fullScreenImageViewQuestion')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('fullScreenImageViewClose')), findsOneWidget);

      // Automatic retries exhausted -> load-failed placeholder, still no
      // caption.
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(
        find.byKey(const Key('fullScreenImageViewLoadFailed')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('foxItemImageCaption')), findsNothing);

      await pumpViewer(tester, viewer(content: 'not-base64!!'));
      expect(
        find.byKey(const Key('fullScreenImageViewPlaceholder')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('foxItemImageCaption')), findsNothing);

      await pumpViewer(tester, viewer(copyright: null));
      expect(find.byType(Image), findsOneWidget);
      expect(find.byKey(const Key('foxItemImageCaption')), findsNothing);
    });
  });
}
