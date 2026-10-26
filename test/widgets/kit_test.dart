// Widget-kit tests (issue #015).
//
// Covers the kit contract: 48dp floors, wrapping (never clipped) labels,
// token-driven banners, clamped progress with semantics, confirm-dialog
// results, empty-state slots, pet states, celebration wrapper, and the
// haptics toggle default. Every pump runs under [FoxStreakTheme] so token
// resolution matches production wiring.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
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

/// Pumps [child] the same as [pumpKit], but with reduce motion on, so a
/// `FoxPet` inside [child] plays once and holds rather than looping
/// (issue #071) — needed wherever a pet-bearing widget is pumped.
Future<void> pumpKitReducedMotion(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: FoxStreakTheme.light(),
        darkTheme: FoxStreakTheme.dark(),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
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

  test('sound toggle defaults on (issue #053)', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(foxSoundEnabledProvider), isTrue);
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

  testWidgets(
    'animated progress bar renders its initial value immediately, with '
    'no animate-in from 0 (issue #066)',
    (WidgetTester tester) async {
      await pumpKit(
        tester,
        const FoxProgressBar(
          value: 0.4,
          animated: true,
          semanticsLabel: 'Lesson progress',
        ),
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.4, 1e-9),
      );
    },
  );

  testWidgets(
    'animated progress bar tweens a value change over ~300ms instead of '
    'jumping (issue #066)',
    (WidgetTester tester) async {
      await pumpKit(
        tester,
        const FoxProgressBar(
          value: 0.2,
          animated: true,
          semanticsLabel: 'Lesson progress',
        ),
      );
      await pumpKit(
        tester,
        const FoxProgressBar(
          value: 0.8,
          animated: true,
          semanticsLabel: 'Lesson progress',
        ),
      );

      // Mid-tween: strictly between the old and new value, not snapped.
      await tester.pump(const Duration(milliseconds: 150));
      final double midway = tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value!;
      expect(midway, greaterThan(0.2));
      expect(midway, lessThan(0.8));

      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.8, 1e-9),
      );
    },
  );

  testWidgets(
    'animated progress bar jumps instantly when disableAnimations is true '
    '(issue #066)',
    (WidgetTester tester) async {
      Future<void> pumpReducedMotion(double value) => tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: FoxStreakTheme.light(),
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: FoxProgressBar(
                value: value,
                animated: true,
                semanticsLabel: 'Lesson progress',
              ),
            ),
          ),
        ),
      );

      await pumpReducedMotion(0.2);
      await tester.pump();
      await pumpReducedMotion(0.8);
      await tester.pump();

      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.8, 1e-9),
      );
    },
  );

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

  testWidgets(
    'level progress bar with levelUpAnimateFrom fills to 100% then resets '
    "and fills to the new level's progress (issue #053)",
    (WidgetTester tester) async {
      await pumpKit(
        tester,
        const FoxLevelProgressBar(
          level: 2,
          progress: 0.2,
          levelLabel: 'Level 2',
          progressText: '20 / 300 XP to next level',
          semanticsLabel: 'Progress to next level',
          levelUpAnimateFrom: 0.9,
        ),
      );

      // The level-up path renders the dedicated animated widget; a plain
      // (non-level-up) render never does (regression guard).
      expect(find.byKey(const Key('levelUpProgressAnimation')), findsOneWidget);

      // Animation starts at the previous level's progress, not the new one.
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.9, 1e-9),
      );

      await tester.pumpAndSettle();

      // Settles on the new level's progress, same as a plain render would.
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.2, 1e-9),
      );
    },
  );

  testWidgets('level progress bar without levelUpAnimateFrom renders the plain '
      'instant fill (no animated-bar key)', (WidgetTester tester) async {
    await pumpKit(
      tester,
      const FoxLevelProgressBar(
        level: 2,
        progress: 0.2,
        levelLabel: 'Level 2',
        progressText: '20 / 300 XP to next level',
        semanticsLabel: 'Progress to next level',
      ),
    );

    expect(find.byKey(const Key('levelUpProgressAnimation')), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(0.2, 1e-9),
    );
  });

  testWidgets('goal ring shows the two label lines and announces '
      '(issue #012)', (WidgetTester tester) async {
    await pumpKit(
      tester,
      const FoxGoalRing(
        value: 0.7,
        primaryLabel: '14 XP',
        secondaryLabel: 'today',
        semanticsLabel: 'Daily goal progress',
        semanticsValue: '14 / 20 XP today',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('14 XP'), findsOneWidget);
    expect(find.text('today'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    final Semantics semantics = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(FoxGoalRing),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.label, 'Daily goal progress');
    expect(semantics.properties.value, '14 / 20 XP today');
  });

  testWidgets('goal ring label stays within the ring at default and large text '
      'scale (issue #037)', (WidgetTester tester) async {
    const double ringSize = 120;
    const double labelClearRadius = ringSize * 0.28;
    const double innerDiameter = labelClearRadius * 2;

    Future<void> pumpAtScale(double scale) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: FoxStreakTheme.light(),
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
              body: FoxGoalRing(
                value: 1.0,
                primaryLabel: '30 XP',
                secondaryLabel: 'today',
                semanticsLabel: 'Daily goal progress',
                semanticsValue: '30 / 30 XP today',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpAtScale(1.0);
    expect(tester.takeException(), isNull);
    expect(find.text('30 XP'), findsOneWidget);
    final Size defaultSize = tester.getSize(find.byType(FittedBox));
    expect(defaultSize.width, lessThanOrEqualTo(innerDiameter + 0.01));
    expect(defaultSize.height, lessThanOrEqualTo(innerDiameter + 0.01));

    await pumpAtScale(3.0);
    expect(tester.takeException(), isNull);
    expect(find.text('30 XP'), findsOneWidget);
    final Size scaledSize = tester.getSize(find.byType(FittedBox));
    expect(scaledSize.width, lessThanOrEqualTo(innerDiameter + 0.01));
    expect(scaledSize.height, lessThanOrEqualTo(innerDiameter + 0.01));
  });

  testWidgets('goal ring overflow past 100% animates in and never throws '
      '(issue #037)', (WidgetTester tester) async {
    await pumpKit(
      tester,
      const FoxGoalRing(
        value: 2.3,
        primaryLabel: '46 XP',
        secondaryLabel: 'today',
        semanticsLabel: 'Daily goal progress',
        semanticsValue: '46 / 20 XP today',
      ),
    );
    // Mid-animation: still ramping toward the target, no exception.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('46 XP'), findsOneWidget);
  });

  group('foxGoalRingLapGeometry (issue #037)', () {
    test('below one lap: partial outer sweep, no nested laps', () {
      final result = foxGoalRingLapGeometry(0.4);
      expect(result.outerSweep, closeTo(0.4, 1e-9));
      expect(result.nestedLaps, 0);
    });

    test('exactly one lap: outer ring full, no nested laps yet', () {
      final result = foxGoalRingLapGeometry(1.0);
      expect(result.outerSweep, closeTo(1.0, 1e-9));
      expect(result.nestedLaps, 0);
    });

    test('mid-second-lap: partial outer sweep, one nested lap', () {
      final result = foxGoalRingLapGeometry(1.4);
      expect(result.outerSweep, closeTo(0.4, 1e-9));
      expect(result.nestedLaps, 1);
    });

    test('exactly two laps: outer ring full, one nested lap', () {
      final result = foxGoalRingLapGeometry(2.0);
      expect(result.outerSweep, closeTo(1.0, 1e-9));
      expect(result.nestedLaps, 1);
    });

    test('negative values clamp to empty', () {
      final result = foxGoalRingLapGeometry(-1.0);
      expect(result.outerSweep, 0);
      expect(result.nestedLaps, 0);
    });
  });

  group('foxGoalRingVisibleNestedLaps (issue #037)', () {
    test('caps nested laps so they never reach the label clear radius', () {
      final int visible = foxGoalRingVisibleNestedLaps(
        nestedLapsWanted: 10,
        outerRadius: 56.5,
        strokeWidth: 7,
        lapGap: 3,
        labelClearRadius: 33.6,
      );
      // (56.5 - 33.6) / 10 ≈ 2.29 -> 2 nested laps fit.
      expect(visible, 2);
    });

    test('returns 0 when even one lap would cross the clear radius', () {
      final int visible = foxGoalRingVisibleNestedLaps(
        nestedLapsWanted: 5,
        outerRadius: 40,
        strokeWidth: 7,
        lapGap: 3,
        labelClearRadius: 35,
      );
      expect(visible, 0);
    });
  });

  testWidgets('streak badge shows flame, count, and the done check '
      '(issue #011)', (WidgetTester tester) async {
    await pumpKit(
      tester,
      const StreakBadge(
        streakCount: 7,
        todayDone: true,
        streakCountLabel: '7',
        todayDoneLabel: "Today's lesson counted",
        semanticsLabel: "7-day streak, today's lesson counted",
      ),
    );

    expect(find.text('7'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    final Semantics semantics = tester.widget<Semantics>(
      find.ancestor(of: find.text('7'), matching: find.byType(Semantics)).first,
    );
    expect(semantics.properties.label, "7-day streak, today's lesson counted");
  });

  testWidgets('streak badge hides the done check when today is not done '
      '(issue #011)', (WidgetTester tester) async {
    await pumpKit(
      tester,
      const StreakBadge(
        streakCount: 2,
        todayDone: false,
        streakCountLabel: '2',
        semanticsLabel: '2-day streak',
      ),
    );

    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
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
    await pumpKitReducedMotion(
      tester,
      FoxEmptyState(
        title: 'No sets yet',
        pet: PetCatalog.defaultEntry,
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

    await pumpKitReducedMotion(
      tester,
      FoxEmptyState(
        title: 'No sets yet',
        pet: PetCatalog.defaultEntry,
        isLoading: true,
        loadingLabel: 'Loading…',
        loadingKey: const Key('kitEmptyLoading'),
      ),
    );
    expect(find.byKey(const Key('kitEmptyLoading')), findsOneWidget);
    expect(find.byType(FoxPrimaryButton), findsNothing);
  });

  testWidgets('pet renders with a stable key + semantic label', (
    WidgetTester tester,
  ) async {
    await pumpKitReducedMotion(
      tester,
      FoxPet(pet: PetCatalog.defaultEntry, semanticLabel: 'Sleepy fox'),
    );
    expect(
      find.byKey(Key('foxPet-${PetCatalog.defaultEntry.id}')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Sleepy fox'), findsOneWidget);
  });

  testWidgets('reveal-hint button fires and can be disabled (issue #027)', (
    WidgetTester tester,
  ) async {
    bool revealed = false;
    await pumpKit(
      tester,
      FoxRevealHintButton(
        tooltip: 'Reveal hint',
        onPressed: () => revealed = true,
      ),
    );
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.byType(FoxRevealHintButton));
    expect(revealed, isTrue);

    await pumpKit(
      tester,
      const FoxRevealHintButton(tooltip: 'Reveal hint', onPressed: null),
    );
    final IconButton button = tester.widget(find.byType(IconButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('celebration wraps its child', (WidgetTester tester) async {
    await pumpKit(tester, const FoxCelebration(child: Text('+10 XP')));
    expect(find.text('+10 XP'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('+10 XP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
