// Tests for the item-type icon/color map (issue #003; choice/freeText split
// from vocab by #026).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/library/item_type_icons.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

void main() {
  group('iconForItemType', () {
    test('choice and freeText share the translate icon', () {
      expect(iconForItemType('choice'), Icons.translate);
      expect(iconForItemType('freeText'), Icons.translate);
    });

    test('phone and date have their own icons', () {
      expect(iconForItemType('phone'), Icons.phone);
      expect(iconForItemType('date'), Icons.cake);
    });

    test('unknown type falls back to help_outline', () {
      expect(iconForItemType('vocab'), Icons.help_outline);
      expect(iconForItemType('grammar'), Icons.help_outline);
    });
  });

  group('colorForItemType', () {
    testWidgets('choice and freeText both get the info tint', (tester) async {
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

      final info = foxSemantics(capturedContext).info;
      expect(colorForItemType(capturedContext, 'choice'), info);
      expect(colorForItemType(capturedContext, 'freeText'), info);
    });

    testWidgets('phone, date, and unknown types get their own tints', (
      tester,
    ) async {
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

      final tokens = foxSemantics(capturedContext);
      expect(colorForItemType(capturedContext, 'phone'), tokens.success);
      expect(colorForItemType(capturedContext, 'date'), tokens.flame);
      expect(
        colorForItemType(capturedContext, 'grammar'),
        Theme.of(capturedContext).colorScheme.onSurfaceVariant,
      );
    });
  });
}
