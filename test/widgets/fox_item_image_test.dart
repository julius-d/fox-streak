// Widget tests for FoxItemImage (issue #014).
//
// Covers the 3 render paths (emoji/base64/url) plus url's loading and
// broken-image/error placeholder states. `url` requests are never let
// resolve over a real network: `flutter_test`'s binding already fakes every
// `HttpClient` to return 400 (so an `Image.network` widget can be pumped
// safely without touching the network), and the loading/error builders are
// instead invoked directly with synthetic arguments — the standard way to
// test an `Image` builder's wiring deterministically, since genuine
// download-progress chunk events depend on real response timing that a
// widget test can't control.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

/// A minimal valid 1x1 transparent PNG — small enough to inline, decodable
/// by `Image.memory` so the base64 happy-path test exercises real decoding,
/// not just "no exception was thrown".
final Uint8List kTinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+A8AAQUAAdafFaMAAAAASUVORK5CYII=',
);

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
  group('a11y floor (#015)', () {
    testWidgets('renders without exceptions under dark mode and a large '
        'text scale', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.dark(),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: const Scaffold(
            body: FoxItemImage(
              imageType: 'emoji',
              imageContent: '🐶',
              semanticLabel: 'Hund',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(FoxItemImage), findsOneWidget);
    });
  });

  group('emoji', () {
    testWidgets('renders the emoji as large inline text with the prompt as '
        'its semantic label', (WidgetTester tester) async {
      await pumpKit(
        tester,
        const FoxItemImage(
          imageType: 'emoji',
          imageContent: '🐶',
          semanticLabel: 'Hund',
        ),
      );
      expect(find.text('🐶'), findsOneWidget);
      expect(find.bySemanticsLabel('Hund'), findsOneWidget);
      expect(find.byKey(const Key('foxItemImagePlaceholder')), findsNothing);
    });

    testWidgets('clips an unexpectedly long pasted string instead of '
        'overflowing the fixed-size box (isValidImageContent only requires '
        'non-empty, not a single grapheme)', (WidgetTester tester) async {
      await pumpKit(
        tester,
        FoxItemImage(
          imageType: 'emoji',
          imageContent: '🐶' * 50,
          semanticLabel: 'Hund',
        ),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  group('base64', () {
    testWidgets('renders the decoded image via Image.memory', (
      WidgetTester tester,
    ) async {
      await pumpKit(
        tester,
        FoxItemImage(
          imageType: 'base64',
          imageContent: base64Encode(kTinyPng),
          semanticLabel: 'A sticker',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byKey(const Key('foxItemImagePlaceholder')), findsNothing);
      expect(find.bySemanticsLabel('A sticker'), findsOneWidget);
    });

    testWidgets('falls back to the placeholder on malformed base64', (
      WidgetTester tester,
    ) async {
      await pumpKit(
        tester,
        const FoxItemImage(
          imageType: 'base64',
          imageContent: 'not-base64!!',
          semanticLabel: 'A sticker',
        ),
      );
      expect(find.byKey(const Key('foxItemImagePlaceholder')), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('url', () {
    testWidgets('builds Image.network with the given URL + semantic label', (
      WidgetTester tester,
    ) async {
      await pumpKit(
        tester,
        const FoxItemImage(
          imageType: 'url',
          imageContent: 'https://example.com/i.png',
          semanticLabel: 'A sticker',
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as NetworkImage).url, 'https://example.com/i.png');
      expect(find.bySemanticsLabel('A sticker'), findsOneWidget);
    });

    testWidgets('loadingBuilder shows the loading placeholder while '
        'download progress is reported', (WidgetTester tester) async {
      await pumpKit(
        tester,
        const FoxItemImage(
          imageType: 'url',
          imageContent: 'https://example.com/i.png',
          semanticLabel: 'A sticker',
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      final built = image.loadingBuilder!(
        tester.element(find.byType(Image)),
        const SizedBox(),
        const ImageChunkEvent(cumulativeBytesLoaded: 1, expectedTotalBytes: 10),
      );
      await pumpKit(tester, built);
      expect(find.byKey(const Key('foxItemImageLoading')), findsOneWidget);
    });

    testWidgets('errorBuilder falls back to the placeholder (never crashes '
        'or hangs the lesson)', (WidgetTester tester) async {
      await pumpKit(
        tester,
        const FoxItemImage(
          imageType: 'url',
          imageContent: 'https://example.com/i.png',
          semanticLabel: 'A sticker',
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      final built = image.errorBuilder!(
        tester.element(find.byType(Image)),
        Exception('offline'),
        StackTrace.current,
      );
      await pumpKit(tester, built);
      expect(find.byKey(const Key('foxItemImagePlaceholder')), findsOneWidget);
    });
  });
}
