// Theme + token tests (issue #015).
//
// Verifies the canonical theme builds for light/dark, carries the semantic
// extension, enforces the 48dp floor in button themes, and locks the bold
// heading/button type roles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

void main() {
  test('light theme is bright, seeded, and carries semantics', () {
    final ThemeData theme = FoxStreakTheme.light();
    expect(theme.brightness, Brightness.light);
    expect(theme.useMaterial3, isTrue);
    expect(theme.extension<FoxSemanticColors>(), FoxSemanticColors.light);
    expect(theme.colorScheme.primary, isNotNull);
  });

  test('dark theme is dark and carries dark semantics', () {
    final ThemeData theme = FoxStreakTheme.dark();
    expect(theme.brightness, Brightness.dark);
    expect(theme.extension<FoxSemanticColors>(), FoxSemanticColors.dark);
  });

  test('light and dark semantic tokens differ', () {
    expect(
      FoxSemanticColors.light.success,
      isNot(FoxSemanticColors.dark.success),
    );
    expect(
      FoxSemanticColors.light.goldInk,
      isNot(FoxSemanticColors.dark.goldInk),
    );
  });

  test('button themes enforce the 48dp floor', () {
    for (final ThemeData theme in <ThemeData>[
      FoxStreakTheme.light(),
      FoxStreakTheme.dark(),
    ]) {
      final ButtonStyle? filled = theme.filledButtonTheme.style;
      final ButtonStyle? outlined = theme.outlinedButtonTheme.style;
      final ButtonStyle? text = theme.textButtonTheme.style;
      for (final ButtonStyle? style in <ButtonStyle?>[filled, outlined, text]) {
        final Size? min = style?.minimumSize?.resolve(<WidgetState>{});
        expect(min, isNotNull);
        expect(min!.width, greaterThanOrEqualTo(48));
        expect(min.height, greaterThanOrEqualTo(48));
      }
      final ButtonStyle? icon = theme.iconButtonTheme.style;
      final Size? iconMin = icon?.minimumSize?.resolve(<WidgetState>{});
      expect(iconMin, isNotNull);
      expect(iconMin!.height, greaterThanOrEqualTo(48));
    }
  });

  test('headings and buttons are bold, body is regular', () {
    final TextTheme text = FoxStreakTheme.light().textTheme;
    expect(text.headlineSmall?.fontWeight, FontWeight.w800);
    expect(text.titleLarge?.fontWeight, FontWeight.w700);
    expect(text.labelLarge?.fontWeight, FontWeight.w700);
  });

  test('MVP uses the M3 default font (no bundled custom family)', () {
    final TextTheme ours = FoxStreakTheme.light().textTheme;
    final TextTheme base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: kFoxSeedColor),
      useMaterial3: true,
    ).textTheme;
    expect(ours.headlineSmall?.fontFamily, base.headlineSmall?.fontFamily);
    expect(ours.labelLarge?.fontFamily, base.labelLarge?.fontFamily);
    expect(ours.bodyMedium?.fontFamily, base.bodyMedium?.fontFamily);
  });

  testWidgets('kit resolves tokens under the wired theme', (
    WidgetTester tester,
  ) async {
    FoxSemanticColors? seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: FoxStreakTheme.light(),
        home: Builder(
          builder: (BuildContext context) {
            seen = foxSemantics(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, FoxSemanticColors.light);
  });
}
