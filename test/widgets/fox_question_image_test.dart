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
}
