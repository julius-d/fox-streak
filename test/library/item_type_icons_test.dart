// Tests for the item/category icon-color map (issue #003; choice/freeText
// split from vocab by #026; category-driven for choice/freeText by #045).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/library/item_type_icons.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

void main() {
  group('iconForItemType', () {
    test('choice and freeText defer to the set category (null -> vocab)', () {
      expect(iconForItemType('choice', null), Icons.translate);
      expect(iconForItemType('freeText', null), Icons.translate);
      expect(iconForItemType('choice', 'vocab'), Icons.translate);
      expect(iconForItemType('choice', 'math'), Icons.calculate);
      expect(iconForItemType('freeText', 'math'), Icons.calculate);
      expect(iconForItemType('choice', 'geography'), Icons.public);
      expect(iconForItemType('choice', 'general'), Icons.quiz);
    });

    test('phone and date ignore category entirely', () {
      expect(iconForItemType('phone', 'math'), Icons.phone);
      expect(iconForItemType('date', 'math'), Icons.cake);
      expect(iconForItemType('phone', null), Icons.phone);
      expect(iconForItemType('date', null), Icons.cake);
    });

    test('unknown type falls back to help_outline', () {
      expect(iconForItemType('vocab', null), Icons.help_outline);
      expect(iconForItemType('grammar', 'math'), Icons.help_outline);
    });
  });

  group('iconForSetCategory', () {
    test('maps each category, null treated as vocab', () {
      expect(iconForSetCategory(null), Icons.translate);
      expect(iconForSetCategory('vocab'), Icons.translate);
      expect(iconForSetCategory('math'), Icons.calculate);
      expect(iconForSetCategory('geography'), Icons.public);
      expect(iconForSetCategory('general'), Icons.quiz);
    });
  });

  group('colorForItemType / colorForSetCategory', () {
    Future<BuildContext> pumpContext(WidgetTester tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: FoxStreakTheme.light(),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return capturedContext;
    }

    testWidgets('choice and freeText defer to the category tint', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final tokens = foxSemantics(context);

      expect(colorForItemType(context, 'choice', null), tokens.info);
      expect(colorForItemType(context, 'freeText', 'vocab'), tokens.info);
      expect(colorForItemType(context, 'choice', 'math'), tokens.math);
      expect(
        colorForItemType(context, 'freeText', 'geography'),
        tokens.geography,
      );
      expect(
        colorForItemType(context, 'choice', 'general'),
        Theme.of(context).colorScheme.onSurfaceVariant,
      );
    });

    testWidgets('phone, date, and unknown types keep their own tints', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final tokens = foxSemantics(context);

      expect(colorForItemType(context, 'phone', 'math'), tokens.success);
      expect(colorForItemType(context, 'date', 'math'), tokens.flame);
      expect(
        colorForItemType(context, 'grammar', null),
        Theme.of(context).colorScheme.onSurfaceVariant,
      );
    });

    testWidgets('colorForSetCategory maps each category, null as vocab', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final tokens = foxSemantics(context);

      expect(colorForSetCategory(context, null), tokens.info);
      expect(colorForSetCategory(context, 'vocab'), tokens.info);
      expect(colorForSetCategory(context, 'math'), tokens.math);
      expect(colorForSetCategory(context, 'geography'), tokens.geography);
      expect(
        colorForSetCategory(context, 'general'),
        Theme.of(context).colorScheme.onSurfaceVariant,
      );
    });
  });
}
