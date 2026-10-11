// FoxStreak design language: tokens + Material 3 theme (issue #015).
//
// Single source of truth for colors, typography roles, spacing, and radius.
// Feature screens must reuse [FoxStreakTheme] and the widget kit in
// `lib/src/widgets/` — no ad-hoc styling (see AGENTS.md "Design language").
//
// Brand: Material 3, orange seed, system font for MVP (no bundled font
// asset; a rounded display font is a post-MVP follow-up). Duolingo north
// star: chunky rounded shapes, bright friendly colors, mascot-forward
// moments, celebratory feedback. M3 governs standard components; the chunky
// 3D press-feel lives only in the custom kit buttons.
//
// Contrast: every semantic pair below was checked against WCAG AA (4.5:1
// for text). Measured ratios (content on surface / on-color on container):
// light — success 5.87, error 6.54, info 6.39, flame 5.00, goldInk 6.45,
// gold pair 10.57; dark (on #141218) — success 10.92/8.77, error 10.95/7.72,
// info 8.90/6.33, flame 7.93/7.56, goldInk 11.41. Kit-level palette contrast
// is owned here; per-screen dark-mode / large-font verification is owned
// by #012.

import 'package:flutter/material.dart';

/// Orange seed color the whole language is built from.
///
/// Same hue family as the pre-#015 `Colors.orange` theme so the retrofit is
/// an evolution, not a restyle. The streak flame token is derived from this
/// seed (darkened/lightened for contrast) where possible.
const Color kFoxSeedColor = Colors.orange;

/// Spacing tokens (dp). Use these, never raw padding numbers.
abstract final class FoxSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Radius tokens (dp). Chunky rounded shapes per the Duolingo north star.
abstract final class FoxRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

/// Button metrics shared by the kit.
abstract final class FoxButtonMetrics {
  /// Minimum touch target (a11y floor; also the M3 minimum).
  static const double minSize = 48;

  /// Corner radius for chunky kit buttons.
  static const double radius = 16;

  /// Hard-shadow offset that gives the Duolingo-style 3D press feel.
  static const double shadowOffset = 4;
}

/// Semantic color tokens with light + dark values.
///
/// Access via `Theme.of(context).extension<FoxSemanticColors>()!` — kit
/// widgets reference these, never raw colors. Roles:
/// - [success]/[error]/[info]/[flame]: content color, safe for text and
///   icons on surfaces; `onX` is safe for text on an `X` background
///   (e.g. [FoxFeedbackBanner]).
/// - [gold]: vivid fill for XP progress/badges (never body text);
///   [onGold] is the text color on gold fills.
/// - [goldInk]: text/icon-safe gold for XP numbers on surfaces.
@immutable
class FoxSemanticColors extends ThemeExtension<FoxSemanticColors> {
  final Color success;
  final Color onSuccess;
  final Color error;
  final Color onError;
  final Color info;
  final Color onInfo;
  final Color flame;
  final Color onFlame;
  final Color gold;
  final Color onGold;
  final Color goldInk;

  const FoxSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.error,
    required this.onError,
    required this.info,
    required this.onInfo,
    required this.flame,
    required this.onFlame,
    required this.gold,
    required this.onGold,
    required this.goldInk,
  });

  /// Light values. Content colors are darkened so they pass AA on light
  /// surfaces; on-colors are white (gold keeps dark text on bright fill).
  static const FoxSemanticColors light = FoxSemanticColors(
    success: Color(0xFF157347),
    onSuccess: Color(0xFFFFFFFF),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    info: Color(0xFF0B57D0),
    onInfo: Color(0xFFFFFFFF),
    flame: Color(0xFFBE4B00),
    onFlame: Color(0xFFFFFFFF),
    gold: Color(0xFFFFC107),
    onGold: Color(0xFF231A00),
    goldInk: Color(0xFF7A5900),
  );

  /// Dark values. Content colors are lightened so they pass AA on dark
  /// surfaces; on-colors are dark ink for banner fills.
  static const FoxSemanticColors dark = FoxSemanticColors(
    success: Color(0xFF6BDD8A),
    onSuccess: Color(0xFF052E12),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    info: Color(0xFF8AB4FF),
    onInfo: Color(0xFF002B72),
    flame: Color(0xFFFF8A3D),
    onFlame: Color(0xFF2A1200),
    gold: Color(0xFFFFC107),
    onGold: Color(0xFF231A00),
    goldInk: Color(0xFFFFC107),
  );

  @override
  FoxSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? error,
    Color? onError,
    Color? info,
    Color? onInfo,
    Color? flame,
    Color? onFlame,
    Color? gold,
    Color? onGold,
    Color? goldInk,
  }) {
    return FoxSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      flame: flame ?? this.flame,
      onFlame: onFlame ?? this.onFlame,
      gold: gold ?? this.gold,
      onGold: onGold ?? this.onGold,
      goldInk: goldInk ?? this.goldInk,
    );
  }

  @override
  FoxSemanticColors lerp(ThemeExtension<FoxSemanticColors>? other, double t) {
    if (other is! FoxSemanticColors) return this;
    Color lerpColor(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return FoxSemanticColors(
      success: lerpColor(success, other.success),
      onSuccess: lerpColor(onSuccess, other.onSuccess),
      error: lerpColor(error, other.error),
      onError: lerpColor(onError, other.onError),
      info: lerpColor(info, other.info),
      onInfo: lerpColor(onInfo, other.onInfo),
      flame: lerpColor(flame, other.flame),
      onFlame: lerpColor(onFlame, other.onFlame),
      gold: lerpColor(gold, other.gold),
      onGold: lerpColor(onGold, other.onGold),
      goldInk: lerpColor(goldInk, other.goldInk),
    );
  }
}

/// Typography roles (no custom `fontFamily` for MVP — M3 defaults).
///
/// Locked roles: headings are bold (`headlineSmall`, `titleLarge`,
/// `titleMedium` at w700–w800), buttons are bold (`labelLarge` w700), body
/// stays regular. Screens use `Theme.of(context).textTheme` roles directly.
TextTheme _foxTextTheme(TextTheme base) {
  return base.copyWith(
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );
}

ButtonStyle _foxFilledButtonStyle() {
  return FilledButton.styleFrom(
    minimumSize: const Size(FoxButtonMetrics.minSize, FoxButtonMetrics.minSize),
    padding: const EdgeInsets.symmetric(
      horizontal: FoxSpacing.xl,
      vertical: FoxSpacing.md,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(FoxButtonMetrics.radius)),
    ),
  );
}

ButtonStyle _foxOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    minimumSize: const Size(FoxButtonMetrics.minSize, FoxButtonMetrics.minSize),
    padding: const EdgeInsets.symmetric(
      horizontal: FoxSpacing.xl,
      vertical: FoxSpacing.md,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(FoxButtonMetrics.radius)),
    ),
  );
}

ButtonStyle _foxTextButtonStyle() {
  return TextButton.styleFrom(
    minimumSize: const Size(FoxButtonMetrics.minSize, FoxButtonMetrics.minSize),
  );
}

/// Canonical FoxStreak theme. Wire as
/// `MaterialApp(theme: FoxStreakTheme.light(), darkTheme: FoxStreakTheme.dark())`.
abstract final class FoxStreakTheme {
  static ThemeData light() {
    return _build(
      scheme: ColorScheme.fromSeed(seedColor: kFoxSeedColor),
      semantics: FoxSemanticColors.light,
    );
  }

  static ThemeData dark() {
    return _build(
      scheme: ColorScheme.fromSeed(
        seedColor: kFoxSeedColor,
        brightness: Brightness.dark,
      ),
      semantics: FoxSemanticColors.dark,
    );
  }

  /// Shared construction so light/dark differ only by [scheme] + [semantics].
  ///
  /// Any structural change (button floors, radii, type roles) applies to both
  /// modes; the parity test in `test/theme/` guards this.
  static ThemeData _build({
    required ColorScheme scheme,
    required FoxSemanticColors semantics,
  }) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: <ThemeExtension<dynamic>>[semantics],
      textTheme: _foxTextTheme(
        ThemeData(colorScheme: scheme, useMaterial3: true).textTheme,
      ),
      filledButtonTheme: FilledButtonThemeData(style: _foxFilledButtonStyle()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _foxOutlinedButtonStyle(),
      ),
      textButtonTheme: TextButtonThemeData(style: _foxTextButtonStyle()),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            FoxButtonMetrics.minSize,
            FoxButtonMetrics.minSize,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(FoxRadius.lg)),
        ),
        margin: EdgeInsets.symmetric(
          horizontal: FoxSpacing.lg,
          vertical: FoxSpacing.sm,
        ),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(FoxRadius.xl)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(FoxRadius.md)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(FoxRadius.md)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Reads semantic tokens for the current theme.
///
/// Convenience so kit widgets (and only kit widgets) resolve tokens in one
/// call. Feature screens must not invent colors around this helper.
FoxSemanticColors foxSemantics(BuildContext context) {
  return Theme.of(context).extension<FoxSemanticColors>()!;
}
