// Library set-card mastery indicator (issue #134): what it shows, how it is
// announced, and the motion played when the card comes back on top with a
// changed value (fill, crown pops + haptic tick, 100% shimmer, New morph).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/set_mastery.dart';
import 'package:fox_streak_app/src/library/set_mastery_indicator.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

SetMastery crowns(int mastered, int total) =>
    SetMastery(itemCount: total, masteredCount: mastered, practiced: true);

SetMastery fresh(int total) =>
    SetMastery(itemCount: total, masteredCount: 0, practiced: false);

class _HapticsOff extends FoxHapticsEnabled {
  @override
  bool build() => false;
}

/// Hosts one indicator for set 1 whose mastery follows [mastery]; [lesson]
/// covers it with another route, like a lesson started from the Library.
class _Harness {
  final ValueNotifier<SetMastery> mastery;
  final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
  final List<String?> haptics = [];

  _Harness(SetMastery initial) : mastery = ValueNotifier(initial);

  Future<void> pump(
    WidgetTester tester, {
    bool reduceMotion = false,
    bool hapticsEnabled = true,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String?);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (!hapticsEnabled)
            foxHapticsEnabledProvider.overrideWith(_HapticsOff.new),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: FoxStreakTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<SetMastery>(
                valueListenable: mastery,
                builder: (context, value, _) =>
                    SetMasteryIndicator(setId: 1, mastery: value),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Covers the indicator, changes its mastery to [after] meanwhile, then
  /// pops back so the card is on top again (the motion starts).
  Future<void> lesson(WidgetTester tester, SetMastery after) async {
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    mastery.value = after;
    await tester.pump();
    navigator.currentState!.pop();
    await tester.pump();
  }
}

double crownFill(WidgetTester tester) =>
    tester.widget<FoxMasteryCrowns>(find.byType(FoxMasteryCrowns)).fill;

void main() {
  testWidgets('crowns show the mastered share x 5 and are announced as one '
      'percent phrase', (tester) async {
    final semantics = tester.ensureSemantics();
    await _Harness(crowns(9, 20)).pump(tester);

    expect(crownFill(tester), 2.25);
    expect(find.byType(FoxNewBadge), findsNothing);
    expect(find.bySemanticsLabel('45% mastered'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a never answered set shows the New badge, announced as '
      '"New, not practiced yet"', (tester) async {
    final semantics = tester.ensureSemantics();
    await _Harness(fresh(3)).pump(tester);

    expect(find.byType(FoxNewBadge), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.byType(FoxMasteryCrowns), findsNothing);
    expect(find.bySemanticsLabel('New, not practiced yet'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a set without items shows nothing', (tester) async {
    await _Harness(SetMastery.empty).pump(tester);

    expect(find.byType(FoxMasteryCrowns), findsNothing);
    expect(find.byType(FoxNewBadge), findsNothing);
  });

  testWidgets('after a lesson raised mastery, the crowns fill from the old '
      'to the new value and each newly full crown pops with a haptic tick', (
    tester,
  ) async {
    final harness = _Harness(crowns(1, 10));
    await harness.pump(tester);
    expect(crownFill(tester), 0.5);

    await harness.lesson(tester, crowns(5, 10));
    expect(crownFill(tester), 0.5);

    await tester.pump(const Duration(milliseconds: 150));
    final midway = crownFill(tester);
    expect(midway, greaterThan(0.5));
    expect(midway, lessThan(2.5));

    await tester.pumpAndSettle();
    expect(crownFill(tester), 2.5);
    expect(harness.haptics, hasLength(2));
    expect(find.byKey(const Key('masteryShimmer')), findsNothing);
  });

  testWidgets('the card does not animate while it is covered', (tester) async {
    final harness = _Harness(crowns(1, 10));
    await harness.pump(tester);
    harness.navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();

    harness.mastery.value = crowns(4, 10);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FoxMasteryCrowns>(
            find.byType(FoxMasteryCrowns, skipOffstage: false),
          )
          .fill,
      0.5,
    );
    expect(harness.haptics, isEmpty);
  });

  testWidgets('haptic ticks respect the in-app haptics toggle', (tester) async {
    final harness = _Harness(crowns(1, 5));
    await harness.pump(tester, hapticsEnabled: false);

    await harness.lesson(tester, crowns(4, 5));
    await tester.pumpAndSettle();

    expect(crownFill(tester), 4);
    expect(harness.haptics, isEmpty);
  });

  testWidgets('reaching 100% plays one gold shimmer; viewing it again '
      'does not', (tester) async {
    final harness = _Harness(crowns(4, 5));
    await harness.pump(tester);

    await harness.lesson(tester, crowns(5, 5));
    var sawShimmer = false;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      sawShimmer |= find
          .byKey(const Key('masteryShimmer'))
          .evaluate()
          .isNotEmpty;
    }
    await tester.pumpAndSettle();
    expect(sawShimmer, isTrue);
    expect(crownFill(tester), 5);
    expect(find.byKey(const Key('masteryShimmer')), findsNothing);

    // Plain revisit at 100%: nothing plays.
    await harness.lesson(tester, crowns(5, 5));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('masteryShimmer')), findsNothing);
    }
  });

  testWidgets('reaching 100% again after a drop shimmers again', (
    tester,
  ) async {
    final harness = _Harness(crowns(5, 5));
    await harness.pump(tester);
    await harness.lesson(tester, crowns(3, 5));
    await tester.pumpAndSettle();

    await harness.lesson(tester, crowns(5, 5));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const Key('masteryShimmer')), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('leaving New shrinks the badge away and fades the crowns in', (
    tester,
  ) async {
    final harness = _Harness(fresh(4));
    await harness.pump(tester);

    await harness.lesson(tester, crowns(1, 4));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FoxNewBadge), findsOneWidget);
    expect(find.byType(FoxMasteryCrowns), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(FoxNewBadge), findsNothing);
    expect(crownFill(tester), 1.25);
    expect(harness.haptics, hasLength(1));
  });

  testWidgets('a drop in mastery shows the lower value right away', (
    tester,
  ) async {
    final harness = _Harness(crowns(4, 5));
    await harness.pump(tester);

    await harness.lesson(tester, crowns(2, 5));
    expect(crownFill(tester), 2);
    await tester.pumpAndSettle();
    expect(crownFill(tester), 2);
    expect(harness.haptics, isEmpty);
  });

  testWidgets('with reduce motion the final state shows instantly', (
    tester,
  ) async {
    final harness = _Harness(fresh(5));
    await harness.pump(tester, reduceMotion: true);

    await harness.lesson(tester, crowns(5, 5));
    expect(find.byType(FoxNewBadge), findsNothing);
    expect(crownFill(tester), 5);
    expect(find.byKey(const Key('masteryShimmer')), findsNothing);
    expect(harness.haptics, isEmpty);
  });

  testWidgets('the first time a card shows a set, nothing animates', (
    tester,
  ) async {
    final harness = _Harness(crowns(5, 5));
    await harness.pump(tester);

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(crownFill(tester), 5);
      expect(find.byKey(const Key('masteryShimmer')), findsNothing);
    }
    expect(harness.haptics, isEmpty);
  });
}
