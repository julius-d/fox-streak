// Golden (screenshot-comparison) tests for the #015 widget kit (issue #019).
//
// Plain `flutter_test` (`matchesGoldenFile`) — no new dependency. Each
// in-scope kit widget is snapshotted once per `FoxStreakTheme.light()` /
// `.dark()` inside a minimal `MaterialApp` host, wrapped in a `RepaintBoundary`
// so the captured bounds stay stable regardless of surrounding layout.
//
// Baselines live under `goldens/` (generated via `flutter test
// --update-goldens`). Regenerate scoped to this directory when a kit
// widget's visuals intentionally change: see AGENTS.md.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

/// Pumps [child] under [theme] inside a fixed-size, keyed [RepaintBoundary]
/// and asserts it matches the baseline PNG named `goldens/$name.png`.
///
/// Pins `devicePixelRatio` so the captured pixel grid doesn't shift if a
/// future SDK changes the test harness's implicit default.
Future<void> _expectGolden(
  WidgetTester tester,
  String name,
  Widget child, {
  required ThemeData theme,
  Size surfaceSize = const Size(320, 160),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
  });
  const Key boundaryKey = Key('goldenBoundary');
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(key: boundaryKey, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byKey(boundaryKey),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  /// Named theme pairs every golden group snapshots against.
  final List<(String, ThemeData)> themes = <(String, ThemeData)>[
    ('light', FoxStreakTheme.light()),
    ('dark', FoxStreakTheme.dark()),
  ];

  group('buttons', () {
    for (final (String themeName, ThemeData theme) in themes) {
      testWidgets('primary button ($themeName)', (WidgetTester tester) async {
        await _expectGolden(
          tester,
          'fox_primary_button_$themeName',
          FoxPrimaryButton(label: 'Los', onPressed: () {}),
          theme: theme,
        );
      });

      testWidgets('secondary button ($themeName)', (WidgetTester tester) async {
        await _expectGolden(
          tester,
          'fox_secondary_button_$themeName',
          FoxSecondaryButton(label: 'Cancel', onPressed: () {}),
          theme: theme,
        );
      });

      testWidgets('check button neutral ($themeName)', (
        WidgetTester tester,
      ) async {
        await _expectGolden(
          tester,
          'fox_check_button_$themeName',
          FoxCheckButton(label: 'Check', onPressed: () {}),
          theme: theme,
          surfaceSize: const Size(320, 100),
        );
      });

      testWidgets('check button correct ($themeName)', (
        WidgetTester tester,
      ) async {
        await _expectGolden(
          tester,
          'fox_check_button_correct_$themeName',
          FoxCheckButton(label: 'Check', onPressed: () {}, correctState: true),
          theme: theme,
          surfaceSize: const Size(320, 100),
        );
      });

      testWidgets('check button incorrect ($themeName)', (
        WidgetTester tester,
      ) async {
        await _expectGolden(
          tester,
          'fox_check_button_incorrect_$themeName',
          FoxCheckButton(label: 'Check', onPressed: () {}, correctState: false),
          theme: theme,
          surfaceSize: const Size(320, 100),
        );
      });
    }
  });

  group('feedback banner', () {
    for (final (String themeName, ThemeData theme) in themes) {
      for (final (String variantName, Widget banner) in <(String, Widget)>[
        ('success', const FoxFeedbackBanner.success(message: 'Great job!')),
        ('error', const FoxFeedbackBanner.error(message: 'Try again')),
        ('info', const FoxFeedbackBanner.info(message: 'Heads up')),
        ('xp', const FoxFeedbackBanner.xp(message: '+10 XP')),
      ]) {
        testWidgets('$variantName banner ($themeName)', (
          WidgetTester tester,
        ) async {
          await _expectGolden(
            tester,
            'fox_feedback_banner_${variantName}_$themeName',
            Padding(
              padding: const EdgeInsets.all(FoxSpacing.md),
              child: banner,
            ),
            theme: theme,
          );
        });
      }
    }
  });

  group('progress bar', () {
    for (final (String themeName, ThemeData theme) in themes) {
      testWidgets('progress bar ($themeName)', (WidgetTester tester) async {
        await _expectGolden(
          tester,
          'fox_progress_bar_$themeName',
          const Padding(
            padding: EdgeInsets.all(FoxSpacing.md),
            child: FoxProgressBar(value: 0.6, semanticsLabel: 'Progress'),
          ),
          theme: theme,
          surfaceSize: const Size(320, 60),
        );
      });
    }
  });

  group('confirm dialog', () {
    for (final (String themeName, ThemeData theme) in themes) {
      testWidgets('confirm dialog ($themeName)', (WidgetTester tester) async {
        await _expectGolden(
          tester,
          'fox_confirm_dialog_$themeName',
          const FoxConfirmDialog(
            title: 'Delete set?',
            message: 'This cannot be undone.',
            confirmLabel: 'Delete',
            cancelLabel: 'Cancel',
          ),
          theme: theme,
          surfaceSize: const Size(360, 260),
        );
      });
    }
  });

  group('empty state', () {
    for (final (String themeName, ThemeData theme) in themes) {
      testWidgets('empty state ($themeName)', (WidgetTester tester) async {
        await _expectGolden(
          tester,
          'fox_empty_state_$themeName',
          FoxEmptyState(
            title: 'No sets yet',
            message: 'Create one to start learning.',
            ctaLabel: 'Try demo set',
            onCta: () {},
          ),
          theme: theme,
          surfaceSize: const Size(360, 420),
        );
      });
    }
  });

  group('mascot', () {
    for (final (String themeName, ThemeData theme) in themes) {
      for (final FoxMascotState state in FoxMascotState.values) {
        testWidgets('mascot ${state.name} ($themeName)', (
          WidgetTester tester,
        ) async {
          await _expectGolden(
            tester,
            'fox_mascot_${state.name}_$themeName',
            FoxMascot(state: state),
            theme: theme,
            surfaceSize: const Size(140, 140),
          );
        });
      }
    }
  });
}
