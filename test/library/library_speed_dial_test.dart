// Library "New set" speed-dial layout + motion (issue #133).
//
// Layout: simulates edge-to-edge Android (status bar + 3-button nav bar
// insets on the test view) with a large text scale, and a short landscape
// screen, and asserts no option ends up under the main FAB, the system UI
// or the app bar. Motion: staggered bouncy pop, smooth interrupts, no
// hidden-but-tappable options, reduced motion, haptics, semantics.
//
// Same bounded-pump rules as `library_screen_test.dart` (no
// `pumpAndSettle`, unmount with a duration).

import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/library/library_screen.dart';
import 'package:fox_streak_app/src/library/set_editor_screen.dart';
import 'package:fox_streak_app/src/library/speed_dial.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

import '../data/test_helpers.dart';
import '../widgets/edge_to_edge_view.dart';

const _mainFab = Key('newSetFab');
const _scrim = Key('newSetFabScrim');
const _optionsTopFirst = [
  Key('marketplaceFab'),
  Key('importSetFab'),
  Key('newSetMiniFab'),
];

Future<void> settle(WidgetTester tester, {int cap = 50}) async {
  for (var i = 0; i < cap; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) return;
  }
  fail('UI did not settle after $cap frames');
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

class _HapticsOff extends FoxHapticsEnabled {
  @override
  bool build() => false;
}

Future<void> _pumpLibrary(WidgetTester tester, {bool hapticsOn = true}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(FakeClock(kTestToday)),
        if (!hapticsOn) foxHapticsEnabledProvider.overrideWith(_HapticsOff.new),
      ],
      child: MaterialApp(
        theme: FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LibraryScreen(),
      ),
    ),
  );
  await settle(tester);
}

double _scaleOf(WidgetTester tester, Key option) => tester
    .widget<ScaleTransition>(
      find
          .ancestor(
            of: find.byKey(option),
            matching: find.byType(ScaleTransition),
          )
          .first,
    )
    .scale
    .value;

/// Scrim opacity — linear in the menu's controller value.
double _menuValue(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byKey(_scrim),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

/// Asserts every option is above the main FAB with a gap, the options
/// don't overlap each other, and nothing sits under the bottom inset.
void _expectClearLayout(WidgetTester tester, {required double bottomInset}) {
  final screen = viewSize(tester);
  final main = tester.getRect(find.byKey(_mainFab));
  expect(main.bottom, lessThanOrEqualTo(screen.height - bottomInset));
  Rect? above;
  for (final key in _optionsTopFirst) {
    final rect = tester.getRect(find.byKey(key));
    expect(
      rect.bottom,
      lessThanOrEqualTo(main.top - FoxSpacing.sm),
      reason: '$key overlaps the main FAB',
    );
    expect(rect.left, greaterThanOrEqualTo(0), reason: '$key off-screen');
    if (above != null) {
      expect(rect.top, greaterThanOrEqualTo(above.bottom), reason: '$key');
    }
    above = rect;
  }
}

void main() {
  group('timing', () {
    test(
      'three options open in ~300ms, each popping for 200ms, 50ms apart',
      () {
        expect(speedDialOpenDuration(3), const Duration(milliseconds: 300));
        expect(speedDialCloseDuration, const Duration(milliseconds: 200));
        final slices = [for (var i = 0; i < 3; i++) speedDialOptionSlice(i, 3)];
        expect(slices[0].begin, 0);
        expect(slices[0].end, closeTo(2 / 3, 1e-9));
        expect(slices[1].begin, closeTo(1 / 6, 1e-9));
        expect(slices[1].end, closeTo(5 / 6, 1e-9));
        expect(slices[2].begin, closeTo(1 / 3, 1e-9));
        expect(slices[2].end, 1);
      },
    );

    test('a single option pops over the whole duration', () {
      expect(speedDialOpenDuration(1), speedDialOptionDuration);
      final slice = speedDialOptionSlice(0, 1);
      expect((slice.begin, slice.end), (0.0, 1.0));
    });
  });

  group('layout', () {
    testWidgets(
      'edge-to-edge phone with a 48dp nav bar and 2x text: every option sits '
      'fully above the main FAB, and the lowest one ("New set") is tappable',
      (tester) async {
        simulateEdgeToEdgeView(tester, top: 52, textScale: 2);
        await _pumpLibrary(tester);

        await tester.tap(find.byKey(_mainFab));
        await settle(tester);
        _expectClearLayout(tester, bottomInset: kNavBarInset);

        await tester.tap(find.byKey(const Key('newSetMiniFab')));
        await settle(tester);
        expect(find.byKey(const Key('titleField')), findsOneWidget);
        await unmount(tester);
      },
    );

    for (final inset in [0.0, 24.0, 48.0, 96.0]) {
      testWidgets(
        'bottom inset ${inset}dp: options keep the same gap above the main FAB',
        (tester) async {
          simulateEdgeToEdgeView(tester, bottom: inset);
          await _pumpLibrary(tester);
          await tester.tap(find.byKey(_mainFab));
          await settle(tester);

          _expectClearLayout(tester, bottomInset: inset);
          final gap =
              tester.getRect(find.byKey(_mainFab)).top -
              tester.getRect(find.byKey(const Key('newSetMiniFab'))).bottom;
          expect(gap, FoxSpacing.lg);
          await unmount(tester);
        },
      );
    }

    testWidgets(
      'short landscape screen + 2x text: no option under the app bar or the '
      'main FAB; each is reachable by scrolling and tappable',
      (tester) async {
        simulateEdgeToEdgeView(
          tester,
          size: kPhoneLandscape,
          bottom: 24,
          textScale: 2,
        );
        await _pumpLibrary(tester);
        await tester.tap(find.byKey(_mainFab));
        await settle(tester);

        final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
        final viewport = tester.getRect(
          find.byKey(const Key('speedDialOptions')),
        );
        final main = tester.getRect(find.byKey(_mainFab));
        expect(viewport.top, greaterThanOrEqualTo(appBarBottom));
        expect(viewport.bottom, lessThanOrEqualTo(main.top));

        for (final key in _optionsTopFirst.reversed) {
          await tester.ensureVisible(find.byKey(key));
          await settle(tester);
          final rect = tester.getRect(find.byKey(key));
          expect(rect.top, greaterThanOrEqualTo(viewport.top), reason: '$key');
          expect(
            rect.bottom,
            lessThanOrEqualTo(viewport.bottom),
            reason: '$key',
          );
        }

        // Topmost option, scrolled into view, still works.
        await tester.tap(find.byKey(const Key('marketplaceFab')));
        await settle(tester);
        expect(
          find.byKey(const Key('marketplaceSourcesScreen')),
          findsOneWidget,
        );
        await unmount(tester);
      },
    );

    testWidgets(
      'opening clears a visible snack bar, which would lift the FAB slot '
      'past the short-screen height cap',
      (tester) async {
        await _pumpLibrary(tester);
        ScaffoldMessenger.of(tester.element(find.byType(LibraryScreen)))
            .showSnackBar(const SnackBar(content: Text('Import failed')));
        await settle(tester);
        expect(find.byType(SnackBar), findsOneWidget);

        await tester.tap(find.byKey(_mainFab));
        await settle(tester);
        expect(find.byType(SnackBar), findsNothing);
        _expectClearLayout(tester, bottomInset: 0);
        await unmount(tester);
      },
    );

    testWidgets(
      'collapsed main FAB matches a plain extended "+ New set" FAB, also '
      'after an open/close round trip; open, it is a round 56dp button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: FoxStreakTheme.light(),
            home: Scaffold(
              appBar: AppBar(title: const Text('Library')),
              floatingActionButton: FloatingActionButton.extended(
                key: _mainFab,
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('New set'),
              ),
            ),
          ),
        );
        final reference = tester.getRect(find.byKey(_mainFab));

        await _pumpLibrary(tester);
        expect(tester.getRect(find.byKey(_mainFab)), reference);

        await tester.tap(find.byKey(_mainFab));
        await settle(tester);
        expect(tester.getSize(find.byKey(_mainFab)), const Size(56, 56));
        final icon = tester.widget<Transform>(
          find
              .ancestor(
                of: find.byIcon(Icons.add),
                matching: find.byType(Transform),
              )
              .first,
        );
        expect(
          icon.transform.getRotation().entry(1, 0),
          closeTo(math.sin(math.pi / 4), 1e-6),
        );

        await tester.tap(find.byKey(_mainFab));
        await settle(tester);
        expect(tester.getRect(find.byKey(_mainFab)), reference);
        await unmount(tester);
      },
    );
  });

  group('motion', () {
    testWidgets(
      'opening pops the options bottom → top with an overshoot while the '
      'scrim fades in, done after 300ms',
      (tester) async {
        await _pumpLibrary(tester);
        await tester.tap(find.byKey(_mainFab));
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 100));
        final newSet = _scaleOf(tester, const Key('newSetMiniFab'));
        final import = _scaleOf(tester, const Key('importSetFab'));
        final marketplace = _scaleOf(tester, const Key('marketplaceFab'));
        expect(newSet, greaterThan(import));
        expect(import, greaterThan(marketplace));
        expect(_menuValue(tester), closeTo(1 / 3, 0.05));

        var peak = newSet;
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          peak = math.max(peak, _scaleOf(tester, const Key('newSetMiniFab')));
        }
        expect(peak, greaterThan(1.0), reason: 'bouncy overshoot');

        await tester.pump(const Duration(milliseconds: 100));
        expect(_menuValue(tester), 1);
        for (final key in _optionsTopFirst) {
          expect(_scaleOf(tester, key), 1, reason: '$key');
        }
        await unmount(tester);
      },
    );

    testWidgets(
      'closing via × reverses in 200ms, top → bottom, then unmounts the '
      'options and the scrim',
      (tester) async {
        await _pumpLibrary(tester);
        await tester.tap(find.byKey(_mainFab));
        await settle(tester);

        await tester.tap(find.byKey(_mainFab));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          _scaleOf(tester, const Key('marketplaceFab')),
          lessThan(_scaleOf(tester, const Key('newSetMiniFab'))),
        );
        await tester.pump(const Duration(milliseconds: 110));
        expect(find.byKey(_scrim), findsNothing);
        for (final key in _optionsTopFirst) {
          expect(find.byKey(key), findsNothing, reason: '$key');
        }
        await unmount(tester);
      },
    );

    testWidgets('scrim tap and system back close with the same animation', (
      tester,
    ) async {
      await _pumpLibrary(tester);
      for (final close in <Future<void> Function()>[
        () => tester.tap(find.byKey(_scrim)),
        () async => tester.binding.handlePopRoute(),
      ]) {
        await tester.tap(find.byKey(_mainFab));
        await settle(tester);
        await close();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(_menuValue(tester), inExclusiveRange(0, 1));
        await settle(tester);
        expect(find.byKey(_scrim), findsNothing);
      }
      // Back closed the menu, not the Library.
      expect(find.byType(LibraryScreen), findsOneWidget);
      await unmount(tester);
    });

    testWidgets(
      'closing mid-open reverses from the current position, and shrinking '
      'options are not tappable',
      (tester) async {
        await _pumpLibrary(tester);
        await tester.tap(find.byKey(_mainFab));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final before = _menuValue(tester);
        final newSetRect = tester.getRect(
          find.byKey(const Key('newSetMiniFab')),
        );

        await tester.tap(find.byKey(_mainFab));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        final after = _menuValue(tester);
        expect(after, lessThan(before));
        expect(after, greaterThan(before - 0.15), reason: 'no jump');

        await tester.tapAt(newSetRect.center);
        await settle(tester);
        expect(find.byKey(const Key('titleField')), findsNothing);
        expect(find.byKey(_scrim), findsNothing);
        await unmount(tester);
      },
    );

    testWidgets('rapid toggling always ends fully open or fully closed', (
      tester,
    ) async {
      await _pumpLibrary(tester);
      for (var taps = 1; taps <= 6; taps++) {
        await tester.tap(find.byKey(_mainFab));
        await tester.pump(const Duration(milliseconds: 30));
        if (taps.isOdd) {
          await settle(tester);
          expect(_menuValue(tester), 1);
          await tester.tap(find.byKey(_mainFab));
          await tester.pump(const Duration(milliseconds: 30));
          await tester.tap(find.byKey(_mainFab));
          await settle(tester);
          expect(_menuValue(tester), 1, reason: 'reopened while closing');
        } else {
          await settle(tester);
          expect(find.byKey(_scrim), findsNothing);
        }
      }
      await unmount(tester);
    });

    testWidgets(
      'picking an option navigates immediately, without waiting for the '
      'close animation',
      (tester) async {
        await _pumpLibrary(tester);
        await tester.tap(find.byKey(_mainFab));
        await settle(tester);

        await tester.tap(find.byKey(const Key('newSetMiniFab')));
        // The pushed route's first frame is offstage (Hero measuring), so
        // two frames: the editor is up while the menu is still closing.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(SetEditorScreen), findsOneWidget);
        expect(_menuValue(tester), greaterThan(0.5), reason: 'still closing');
        await settle(tester);
        await unmount(tester);
      },
    );

    testWidgets(
      'reduced motion: opens and closes within a single frame, layout still '
      'clear of the nav bar',
      (tester) async {
        simulateEdgeToEdgeView(tester, textScale: 2, disableAnimations: true);
        await _pumpLibrary(tester);

        await tester.tap(find.byKey(_mainFab));
        await tester.pump();
        expect(_menuValue(tester), 1);
        for (final key in _optionsTopFirst) {
          expect(_scaleOf(tester, key), 1, reason: '$key');
        }
        _expectClearLayout(tester, bottomInset: kNavBarInset);

        await tester.tap(find.byKey(_mainFab));
        await tester.pump();
        expect(find.byKey(_scrim), findsNothing);
        await unmount(tester);
      },
    );
  });

  group('haptics', () {
    Future<List<String>> recordHaptics(WidgetTester tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String);
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
      return calls;
    }

    testWidgets('one light tick on open, none on close', (tester) async {
      final calls = await recordHaptics(tester);
      await _pumpLibrary(tester);
      await tester.tap(find.byKey(_mainFab));
      await settle(tester);
      expect(calls, ['HapticFeedbackType.lightImpact']);

      await tester.tap(find.byKey(_scrim));
      await settle(tester);
      expect(calls, hasLength(1));
      await unmount(tester);
    });

    testWidgets('no tick when the in-app haptics toggle is off', (
      tester,
    ) async {
      final calls = await recordHaptics(tester);
      await _pumpLibrary(tester, hapticsOn: false);
      await tester.tap(find.byKey(_mainFab));
      await settle(tester);
      expect(calls, isEmpty);
      await unmount(tester);
    });
  });

  testWidgets(
    'screen readers reach the options only once fully shown, never the '
    'library behind the scrim, and the main FAB reads as "Close"',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpLibrary(tester);
      expect(find.semantics.byLabel('Try demo set'), findsOneWidget);

      await tester.tap(find.byKey(_mainFab));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.semantics.byLabel('Marketplace'), findsNothing);
      expect(find.semantics.byLabel('Try demo set'), findsNothing);

      await settle(tester);
      expect(find.semantics.byLabel('Marketplace'), findsOneWidget);
      expect(find.semantics.byLabel('Import'), findsOneWidget);
      // Only the option — the main FAB's shrunk label is excluded.
      expect(find.semantics.byLabel('New set'), findsOneWidget);
      expect(
        find.semantics.byPredicate((node) => node.tooltip == 'Close'),
        findsOne,
      );
      expect(find.semantics.byLabel('Try demo set'), findsNothing);
      semantics.dispose();
      await unmount(tester);
    },
  );
}
