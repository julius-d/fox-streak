// Widget-kit tests (issue #015).
//
// Covers the kit contract: 48dp floors, wrapping (never clipped) labels,
// token-driven banners, clamped progress with semantics, confirm-dialog
// results, empty-state slots, mascot states, celebration wrapper, and the
// haptics toggle default. Every pump runs under [FoxStreakTheme] so token
// resolution matches production wiring.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

/// Pumps [child] under the canonical light theme (+ Riverpod scope).
Future<void> pumpKit(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: FoxStreakTheme.light(),
        darkTheme: FoxStreakTheme.dark(),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('haptics toggle defaults on', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(foxHapticsEnabledProvider), isTrue);
  });

  testWidgets('primary button keeps the 48dp floor and fires', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    await pumpKit(
      tester,
      FoxPrimaryButton(label: 'Los', onPressed: () => tapped = true),
    );
    final Size size = tester.getSize(find.byType(FoxPrimaryButton));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
    await tester.tap(find.byType(FoxPrimaryButton));
    expect(tapped, isTrue);
  });

  testWidgets('primary button shows a spinner while loading', (
    WidgetTester tester,
  ) async {
    await pumpKit(
      tester,
      const FoxPrimaryButton(label: 'Save', onPressed: null, isLoading: true),
    );
    // Null callback + loading: disabled, spinner visible, no crash.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long DE label wraps instead of clipping', (
    WidgetTester tester,
  ) async {
    await pumpKit(
      tester,
      const SizedBox(
        width: 220,
        child: FoxPrimaryButton(
          label: 'Demo-Set ausprobieren und Einträge verwalten',
          expanded: true,
          onPressed: null,
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('Demo-Set ausprobieren und Einträge verwalten'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('secondary and check buttons render and disable', (
    WidgetTester tester,
  ) async {
    await pumpKit(
      tester,
      const Column(
        children: <Widget>[
          FoxSecondaryButton(label: 'Cancel', onPressed: null),
          FoxCheckButton(label: 'Check', onPressed: null, correctState: true),
          FoxCheckButton(label: 'Check', onPressed: null, correctState: false),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Check'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('feedback banners show token colors per variant', (
    WidgetTester tester,
  ) async {
    await pumpKit(
      tester,
      const Column(
        children: <Widget>[
          FoxFeedbackBanner.success(message: 'Great job!'),
          FoxFeedbackBanner.error(message: 'Try again'),
          FoxFeedbackBanner.info(message: 'Heads up'),
          FoxFeedbackBanner.xp(message: '+10 XP'),
        ],
      ),
    );
    expect(find.text('Great job!'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Heads up'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
    final List<Container> containers = tester
        .widgetList<Container>(find.byType(Container))
        .toList();
    final Set<Color?> fills = <Color?>{
      for (final Container c in containers)
        (c.decoration as BoxDecoration?)?.color,
    };
    expect(fills.contains(FoxSemanticColors.light.success), isTrue);
    expect(fills.contains(FoxSemanticColors.light.error), isTrue);
    expect(fills.contains(FoxSemanticColors.light.info), isTrue);
    expect(fills.contains(FoxSemanticColors.light.gold), isTrue);
  });

  testWidgets('progress bar clamps and announces', (WidgetTester tester) async {
    await pumpKit(
      tester,
      const FoxProgressBar(value: 2, semanticsLabel: 'Lesson progress'),
    );
    final Semantics semantics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byType(LinearProgressIndicator),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.value, '100%');
    expect(semantics.properties.label, 'Lesson progress');
  });

  testWidgets('level progress bar shows level label, gold fill, and '
      'progress text (issue #010)', (WidgetTester tester) async {
    await pumpKit(
      tester,
      const FoxLevelProgressBar(
        level: 3,
        progress: 0.25,
        levelLabel: 'Level 3',
        progressText: '75 / 300 XP to next level',
        semanticsLabel: 'Progress to next level',
      ),
    );

    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text('75 / 300 XP to next level'), findsOneWidget);

    final Semantics semantics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byType(LinearProgressIndicator),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.label, 'Progress to next level');
    expect(semantics.properties.value, '75 / 300 XP to next level');

    final LinearProgressIndicator indicator = tester.widget(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, closeTo(0.25, 1e-9));
    expect(
      (indicator.valueColor as AlwaysStoppedAnimation<Color>).value,
      FoxSemanticColors.light.gold,
    );
  });

  testWidgets('confirm dialog resolves true on confirm', (
    WidgetTester tester,
  ) async {
    bool? result;
    await pumpKit(
      tester,
      Builder(
        builder: (BuildContext context) {
          return FoxPrimaryButton(
            label: 'Ask',
            onPressed: () async {
              result = await FoxConfirmDialog.show(
                context: context,
                title: 'Delete set?',
                message: 'Really?',
                confirmLabel: 'Delete',
                cancelLabel: 'Cancel',
                confirmKey: const Key('kitConfirm'),
                cancelKey: const Key('kitCancel'),
              );
            },
          );
        },
      ),
    );
    await tester.tap(find.text('Ask'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('kitConfirm')));
    await tester.pump();
    expect(result, isTrue);
  });

  testWidgets('confirm dialog resolves false on cancel', (
    WidgetTester tester,
  ) async {
    bool? result;
    await pumpKit(
      tester,
      Builder(
        builder: (BuildContext context) {
          return FoxPrimaryButton(
            label: 'Ask',
            onPressed: () async {
              result = await FoxConfirmDialog.show(
                context: context,
                title: 'Delete set?',
                message: 'Really?',
                confirmLabel: 'Delete',
                cancelLabel: 'Cancel',
                confirmKey: const Key('kitConfirm'),
                cancelKey: const Key('kitCancel'),
              );
            },
          );
        },
      ),
    );
    await tester.tap(find.text('Ask'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('kitCancel')));
    await tester.pump();
    expect(result, isFalse);
  });

  testWidgets('empty state shows CTA, loading, and error slots', (
    WidgetTester tester,
  ) async {
    bool cta = false;
    await pumpKit(
      tester,
      FoxEmptyState(
        title: 'No sets yet',
        message: 'Create one.',
        ctaLabel: 'Try demo set',
        onCta: () => cta = true,
        errorMessage: 'Boom',
        titleKey: const Key('kitEmptyTitle'),
        ctaKey: const Key('kitEmptyCta'),
        errorKey: const Key('kitEmptyError'),
      ),
    );
    expect(find.byKey(const Key('kitEmptyTitle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('kitEmptyCta')));
    expect(cta, isTrue);
    expect(find.text('Boom'), findsOneWidget);

    await pumpKit(
      tester,
      const FoxEmptyState(
        title: 'No sets yet',
        isLoading: true,
        loadingLabel: 'Loading…',
        loadingKey: Key('kitEmptyLoading'),
      ),
    );
    expect(find.byKey(const Key('kitEmptyLoading')), findsOneWidget);
    expect(find.byType(FoxPrimaryButton), findsNothing);
  });

  testWidgets('mascot states render with stable keys', (
    WidgetTester tester,
  ) async {
    await pumpKit(
      tester,
      const Column(
        children: <Widget>[
          FoxMascot(state: FoxMascotState.empty, semanticLabel: 'Sleepy fox'),
          FoxMascot(state: FoxMascotState.lit),
          FoxMascot(state: FoxMascotState.onFire),
        ],
      ),
    );
    expect(find.byKey(const Key('foxMascot-empty')), findsOneWidget);
    expect(find.byKey(const Key('foxMascot-lit')), findsOneWidget);
    expect(find.byKey(const Key('foxMascot-onFire')), findsOneWidget);
    expect(find.bySemanticsLabel('Sleepy fox'), findsOneWidget);
  });

  testWidgets('celebration wraps its child', (WidgetTester tester) async {
    await pumpKit(tester, const FoxCelebration(child: Text('+10 XP')));
    expect(find.text('+10 XP'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('+10 XP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
