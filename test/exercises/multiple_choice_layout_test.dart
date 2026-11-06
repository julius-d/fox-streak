// Layout tests for the multiple-choice card with an image (issue #112).
//
// The card is pumped inside a stand-in for the lesson shell's card slot
// (app bar, lg padding, optional feedback banner, bottom button area) at
// concrete window sizes, then image / options geometry is asserted.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/exercises/multiple_choice_exercise.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

final _png = base64Encode(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAHnOcQAAAAABJRU5ErkJggg==',
  ),
);

Item _item({String? imageType = 'base64', String? imageContent}) => Item(
  id: 1,
  setId: 1,
  type: 'choice',
  prompt: 'Which country is this?',
  answer: 'Peru',
  promptLang: 'en',
  answerLang: 'en',
  choices: '["Chile","Bolivia","Brazil"]',
  hint: '',
  position: 0,
  imageType: imageType,
  imageContent: imageType == null ? null : (imageContent ?? _png),
);

/// Mimics `LessonScreen._buildLessonBody`: card slot + optional banner +
/// bottom button area.
class _Shell extends StatelessWidget {
  final Item item;
  final bool revealed;
  const _Shell({required this.item, this.revealed = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: FoxStreakTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(FoxSpacing.lg),
                  child: Builder(
                    builder: (context) => MultipleChoiceCard(
                      item: item,
                      onStateChanged: (_) {},
                      l10n: AppLocalizations.of(context)!,
                      revealed: revealed,
                    ),
                  ),
                ),
              ),
              if (revealed) const SizedBox(height: 72, child: Placeholder()),
              const SizedBox(height: 88),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Size size,
  Widget widget, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(widget);
  await tester.pump();
}

Rect _imageRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('foxQuestionImageTapTarget')));

Rect _optionRect(WidgetTester tester, int i) =>
    tester.getRect(find.byKey(Key('choiceOption$i')));

void main() {
  const phone = Size(360, 800);

  group('MultipleChoiceCard layout with image (#112)', () {
    testWidgets('360x800: image >= 240dp, top-aligned, all options visible', (
      tester,
    ) async {
      await _pump(tester, phone, _Shell(item: _item()));

      final image = _imageRect(tester);
      expect(image.height, greaterThanOrEqualTo(240));
      // Top-aligned: nothing between the card slot's top and the image.
      final slotTop =
          tester.getRect(find.byType(AppBar)).bottom + FoxSpacing.lg;
      expect(image.top, slotTop);
      // All four options lie within the card slot (above bottom buttons).
      final slotBottom = phone.height - 88 - FoxSpacing.lg;
      expect(_optionRect(tester, 3).bottom, lessThanOrEqualTo(slotBottom));
    });

    testWidgets('taller phone: image grows beyond 240dp', (tester) async {
      await _pump(tester, const Size(360, 1000), _Shell(item: _item()));
      expect(_imageRect(tester).height, greaterThan(240));
    });

    testWidgets('small phone 360x640: image stays 240dp, scrolls', (
      tester,
    ) async {
      await _pump(tester, const Size(360, 640), _Shell(item: _item()));
      expect(_imageRect(tester).height, 240);
      expect(find.byType(Scrollable), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('choiceOption3')),
        100,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('large font: image stays >= 240dp, nothing overflows', (
      tester,
    ) async {
      await _pump(tester, phone, _Shell(item: _item()), textScale: 2);
      expect(_imageRect(tester).height, greaterThanOrEqualTo(240));
      expect(tester.takeException(), isNull);
    });

    testWidgets('landscape: image beside prompt + options, no scrolling', (
      tester,
    ) async {
      await _pump(tester, const Size(900, 600), _Shell(item: _item()));

      final image = _imageRect(tester);
      final first = _optionRect(tester, 0);
      expect(image.right, lessThanOrEqualTo(first.left));
      expect(image.height, greaterThanOrEqualTo(240));
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, 0);
      const slotBottom = 600 - 88 - FoxSpacing.lg;
      expect(_optionRect(tester, 3).bottom, lessThanOrEqualTo(slotBottom));
    });

    testWidgets('options do not move when the result is revealed', (
      tester,
    ) async {
      await _pump(tester, phone, _Shell(item: _item()));
      final before = [for (var i = 0; i < 4; i++) _optionRect(tester, i)];
      final imageBefore = _imageRect(tester);

      await _pump(tester, phone, _Shell(item: _item(), revealed: true));
      await tester.pump(const Duration(milliseconds: 200));

      expect([for (var i = 0; i < 4; i++) _optionRect(tester, i)], before);
      expect(_imageRect(tester), imageBefore);
    });

    testWidgets('rotating after the reveal re-bases to the new layout', (
      tester,
    ) async {
      await _pump(tester, phone, _Shell(item: _item(), revealed: true));
      await _pump(
        tester,
        const Size(900, 600),
        _Shell(item: _item(), revealed: true),
      );
      expect(
        _imageRect(tester).right,
        lessThanOrEqualTo(_optionRect(tester, 0).left),
      );
    });

    testWidgets('options block is identical for different aspect ratios', (
      tester,
    ) async {
      // The image box has a fixed size (contain-fit), whatever the picture.
      await _pump(tester, phone, _Shell(item: _item()));
      final a = _optionRect(tester, 0);
      await _pump(tester, phone, _Shell(item: _item(imageContent: _png)));
      expect(_optionRect(tester, 0), a);
    });
  });

  group('MultipleChoiceCard layout without image (#112)', () {
    testWidgets('centered while it fits', (tester) async {
      await _pump(tester, phone, _Shell(item: _item(imageType: null)));
      final top = _optionRect(tester, 0).top;
      final slotTop =
          tester.getRect(find.byType(AppBar)).bottom + FoxSpacing.lg;
      expect(top - slotTop, greaterThan(100));
    });

    testWidgets('top-aligned when centering would need scrolling', (
      tester,
    ) async {
      await _pump(
        tester,
        const Size(360, 480),
        _Shell(item: _item(imageType: null)),
        textScale: 2,
      );
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      final slotTop =
          tester.getRect(find.byType(AppBar)).bottom + FoxSpacing.lg;
      expect(scrollable.position.pixels, 0);
      expect(
        tester.getRect(find.text('Which country is this?')).top,
        lessThan(slotTop + 120),
      );
    });
  });
}
